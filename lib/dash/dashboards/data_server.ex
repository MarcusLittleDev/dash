defmodule Dash.Dashboards.DataServer do
  @moduledoc """
  ETS-backed cache for widget data.

  The DataServer maintains an in-memory cache of recent pipeline data for each widget,
  enabling fast reads for dashboard rendering without hitting the database.

  Data is automatically pushed to the cache when pipelines execute, and widgets
  receive updates via PubSub subscriptions.
  """

  use GenServer
  require Logger

  @table_name :dashboard_widget_data
  @max_rows_per_widget 1000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get cached data for a widget.

  Options:
    - `:limit` - Maximum number of records to return (default: 100)
  """
  def get_data(widget_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    case :ets.lookup(@table_name, widget_id) do
      [{^widget_id, data}] -> Enum.take(data, limit)
      [] -> []
    end
  end

  @doc """
  Push new data to a widget's cache.

  New records are prepended to existing data, maintaining chronological order
  (newest first). The cache is automatically trimmed to prevent unbounded growth.
  """
  def push_data(widget_id, new_records) when is_list(new_records) do
    GenServer.cast(__MODULE__, {:push_data, widget_id, new_records})
  end

  @doc """
  Clear all cached data for a widget.
  """
  def clear_data(widget_id) do
    GenServer.cast(__MODULE__, {:clear_data, widget_id})
  end

  @doc """
  Clear all cached data for all widgets belonging to a pipeline.
  """
  def clear_pipeline_data(pipeline_id) do
    GenServer.cast(__MODULE__, {:clear_pipeline_data, pipeline_id})
  end

  @doc """
  Get the count of cached records for a widget.
  """
  def get_count(widget_id) do
    case :ets.lookup(@table_name, widget_id) do
      [{^widget_id, data}] -> length(data)
      [] -> 0
    end
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:named_table, :public, :set])
    Logger.info("DataServer started with ETS table: #{@table_name}")
    {:ok, %{table: table}}
  end

  @impl true
  def handle_cast({:push_data, widget_id, new_records}, state) do
    existing =
      case :ets.lookup(@table_name, widget_id) do
        [{^widget_id, data}] -> data
        [] -> []
      end

    # Prepend new records and trim to max size
    updated = Enum.take(new_records ++ existing, @max_rows_per_widget)
    :ets.insert(@table_name, {widget_id, updated})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:clear_data, widget_id}, state) do
    :ets.delete(@table_name, widget_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:clear_pipeline_data, pipeline_id}, state) do
    # Find all widgets for this pipeline and clear their data
    require Ash.Query

    widgets =
      Dash.Dashboards.Widget
      |> Ash.Query.for_read(:for_pipeline, %{pipeline_id: pipeline_id})
      |> Ash.read!(authorize?: false)

    Enum.each(widgets, fn widget ->
      :ets.delete(@table_name, widget.id)
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("DataServer received unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
end
