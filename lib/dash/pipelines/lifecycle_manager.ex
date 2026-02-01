defmodule Dash.Pipelines.LifecycleManager do
  @moduledoc """
  Manages the lifecycle of pipelines (starting, stopping, pausing).

  The LifecycleManager is responsible for:
  - Starting active pipelines (scheduling Oban jobs or starting GenServers)
  - Stopping pipelines (canceling jobs or stopping GenServers)
  - Pausing/resuming pipelines
  - Determining which worker type to use (Oban vs GenServer)

  Worker selection:
  - Interval >= 60s: Use Oban worker (better for long intervals, survives restarts)
  - Interval < 60s: Use GenServer worker (better for short intervals, more responsive)
  """

  require Logger
  require Ash.Query
  alias Dash.Pipelines.{Pipeline, Workers.PollingWorker}

  @min_oban_interval 60

  @doc """
  Starts a pipeline based on its type and interval.

  Returns `{:ok, :scheduled}` for Oban-based pipelines.
  Returns `{:ok, pid}` for GenServer-based pipelines.
  Returns `{:error, reason}` on failure.
  """
  def start_pipeline(pipeline) do
    case pipeline.type do
      :polling ->
        start_polling_pipeline(pipeline)

      :webhook ->
        # Webhooks don't need scheduled execution
        {:ok, :webhook_ready}

      type when type in [:realtime, :p2p] ->
        {:error, "Pipeline type #{type} not yet implemented"}
    end
  end

  @doc """
  Stops a pipeline.

  For Oban pipelines: cancels scheduled jobs
  For GenServer pipelines: stops the worker process
  """
  def stop_pipeline(pipeline) do
    case pipeline.type do
      :polling ->
        stop_polling_pipeline(pipeline)

      :webhook ->
        {:ok, :webhook_stopped}

      _ ->
        {:ok, :nothing_to_stop}
    end
  end

  @doc """
  Pauses a pipeline by updating its status to :inactive and stopping execution.
  """
  def pause_pipeline(pipeline) do
    with {:ok, updated} <- update_pipeline_status(pipeline, :inactive),
         {:ok, _} <- stop_pipeline(updated) do
      Logger.info("Pipeline #{pipeline.id} paused")
      {:ok, updated}
    end
  end

  @doc """
  Activates a pipeline by updating its status to :active and starting execution.
  """
  def activate_pipeline(pipeline) do
    with {:ok, updated} <- update_pipeline_status(pipeline, :active),
         {:ok, result} <- start_pipeline(updated) do
      Logger.info("Pipeline #{pipeline.id} activated")
      {:ok, updated, result}
    end
  end

  @doc """
  Loads all active pipelines and starts them.
  Called on application startup.
  """
  def start_all_active_pipelines do
    Logger.info("Starting all active pipelines")

    case load_active_pipelines() do
      {:ok, pipelines} ->
        results =
          Enum.map(pipelines, fn pipeline ->
            case start_pipeline(pipeline) do
              {:ok, result} ->
                Logger.info("Started pipeline #{pipeline.id}: #{inspect(result)}")
                {:ok, pipeline.id, result}

              {:error, reason} ->
                Logger.error("Failed to start pipeline #{pipeline.id}: #{inspect(reason)}")
                {:error, pipeline.id, reason}
            end
          end)

        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to load active pipelines: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp start_polling_pipeline(pipeline) do
    cond do
      is_nil(pipeline.interval_seconds) ->
        {:error, "Polling pipeline must have interval_seconds set"}

      pipeline.interval_seconds < 30 ->
        {:error, "Interval must be at least 30 seconds"}

      pipeline.interval_seconds >= @min_oban_interval ->
        # Use Oban for longer intervals
        Logger.info(
          "Starting Oban worker for pipeline #{pipeline.id} (interval: #{pipeline.interval_seconds}s)"
        )

        PollingWorker.schedule(pipeline)
        {:ok, :scheduled}

      true ->
        # Use GenServer for short intervals (< 60s)
        Logger.info(
          "Starting GenServer worker for pipeline #{pipeline.id} (interval: #{pipeline.interval_seconds}s)"
        )

        # For Week 3-4 MVP, we'll just use Oban for all intervals
        # GenServer workers will be added later
        PollingWorker.schedule(pipeline)
        {:ok, :scheduled}
    end
  end

  defp stop_polling_pipeline(pipeline) do
    # Cancel any pending Oban jobs for this pipeline
    cancel_oban_jobs(pipeline)

    # Stop GenServer worker if running
    # For Week 3-4, we only have Oban workers
    {:ok, :stopped}
  end

  defp cancel_oban_jobs(pipeline) do
    # Cancel all scheduled jobs for this pipeline
    import Ecto.Query

    query =
      from(j in Oban.Job,
        where: j.queue == "pipelines",
        where: fragment("?->>'pipeline_id' = ?", j.args, ^pipeline.id)
      )

    Oban.cancel_all_jobs(query)

    Logger.debug("Cancelled Oban jobs for pipeline #{pipeline.id}")
    :ok
  end

  defp load_active_pipelines do
    Pipeline
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(status == :active)
    |> Ash.read(authorize?: false)
  end

  defp update_pipeline_status(pipeline, new_status) do
    pipeline
    |> Ash.Changeset.for_update(:update, %{status: new_status})
    |> Ash.update(authorize?: false)
  end
end
