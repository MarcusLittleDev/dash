# Pipeline System Implementation

This document covers the implementation details for Dash's pipeline system. For storage architecture (Bronze/Silver layers, replay engine), see [03-database.md](03-database.md).

## Overview

Pipelines are the core data ingestion mechanism in Dash. They:
- Fetch data from external sources (HTTP APIs, webhooks, other pipelines)
- Transform data via configurable mappings
- Persist to TimescaleDB (optional) and Bronze layer (always)
- Broadcast real-time updates to dashboards via PubSub
- Send data to configured sinks (webhooks, APIs, etc.)

## Pipeline Execution Models

Dash supports two execution models for pipelines:

1. **Long-running GenServer Workers** - For pipelines that need to maintain state or have very short polling intervals
2. **Oban Scheduled Jobs** - For pipelines with longer polling intervals (>1 minute)

## Pipeline Worker Architecture (GenServer)

```elixir
# lib/dash/pipelines/supervisor.ex
defmodule Dash.Pipelines.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_pipeline(pipeline) do
    spec = {Dash.Pipelines.Worker, pipeline}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_pipeline(pipeline_id) do
    case Registry.lookup(Dash.Registry, {:pipeline, pipeline_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end

# lib/dash/pipelines/worker.ex
defmodule Dash.Pipelines.Worker do
  use GenServer
  require Logger

  def start_link(pipeline) do
    GenServer.start_link(__MODULE__, pipeline,
      name: {:via, Registry, {Dash.Registry, {:pipeline, pipeline.id}}}
    )
  end

  def init(pipeline) do
    # Subscribe to pipeline configuration changes
    Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline.id}:config")

    # Schedule initial run if polling
    if pipeline.type == :polling && pipeline.status == :active do
      schedule_poll(0)  # Run immediately
    end

    {:ok, %{pipeline: pipeline, last_run: nil}}
  end

  def handle_info(:poll, state) do
    pipeline = state.pipeline

    # Fetch data from source
    case fetch_data(pipeline) do
      {:ok, raw_data} ->
        # Process the data
        process_data(pipeline, raw_data)

        # Schedule next poll
        schedule_poll(pipeline.interval_seconds * 1000)

        {:noreply, %{state | last_run: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("Pipeline #{pipeline.id} fetch failed: #{inspect(reason)}")

        # Mark pipeline as errored
        Ash.update!(pipeline, :mark_error, %{error_message: inspect(reason)})

        # Retry after backoff
        schedule_poll(60_000)  # 1 minute

        {:noreply, state}
    end
  end

  # Handle configuration updates
  def handle_info({:config_updated, updated_pipeline}, state) do
    {:noreply, %{state | pipeline: updated_pipeline}}
  end

  defp fetch_data(pipeline) do
    adapter = get_source_adapter(pipeline.source_type)
    adapter.fetch(pipeline.source_config)
  end

  defp process_data(pipeline, raw_data) do
    # Load data mapping if exists
    pipeline = Ash.load!(pipeline, :data_mapping)

    # Transform data
    transformed = Dash.Pipelines.DataMapper.transform(raw_data, pipeline.data_mapping)

    # Persist if configured
    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(
        pipeline.id,
        pipeline.team_id,
        transformed
      )
    end

    # Update cache
    Dash.Data.CacheManager.update_recent_data(pipeline.id, transformed)

    # Send to sinks
    send_to_sinks(pipeline, transformed)

    # Broadcast to dashboards
    Phoenix.PubSub.broadcast(
      Dash.PubSub,
      "pipeline:#{pipeline.id}",
      {:new_data, transformed}
    )
  end

  defp send_to_sinks(pipeline, data) do
    pipeline = Ash.load!(pipeline, :sinks)

    Enum.each(pipeline.sinks, fn sink ->
      Task.Supervisor.start_child(Dash.TaskSupervisor, fn ->
        adapter = get_sink_adapter(sink.sink_type)
        adapter.send(sink.sink_config, data)
      end)
    end)
  end

  defp schedule_poll(milliseconds) do
    Process.send_after(self(), :poll, milliseconds)
  end

  defp get_source_adapter("http_api"), do: Dash.Pipelines.Adapters.Sources.HttpApi
  defp get_source_adapter("graphql"), do: Dash.Pipelines.Adapters.Sources.GraphQL
  # ... more adapters

  defp get_sink_adapter("http_api"), do: Dash.Pipelines.Adapters.Sinks.HttpApi
  defp get_sink_adapter("webhook"), do: Dash.Pipelines.Adapters.Sinks.Webhook
  # ... more adapters
end
```

### Scheduled Pipelines (Oban)

```elixir
# lib/dash/pipelines/workers/polling_worker.ex
defmodule Dash.Pipelines.Workers.PollingWorker do
  use Oban.Worker,
    queue: :pipelines,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"pipeline_id" => pipeline_id}}) do
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id,
      load: [:sinks, :data_mapping]
    )

    # Fetch from source
    {:ok, raw_data} = fetch_from_source(pipeline)

    # Transform
    transformed = Dash.Pipelines.DataMapper.transform(raw_data, pipeline.data_mapping)

    # Persist
    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(pipeline.id, pipeline.team_id, transformed)
    end

    # Update cache & broadcast
    Dash.Data.CacheManager.update_recent_data(pipeline.id, transformed)
    Phoenix.PubSub.broadcast(Dash.PubSub, "pipeline:#{pipeline.id}", {:new_data, transformed})

    # Send to sinks
    Enum.each(pipeline.sinks, &send_to_sink(&1, transformed))

    :ok
  end

  defp fetch_from_source(pipeline) do
    # Implementation
  end

  defp send_to_sink(sink, data) do
    # Implementation
  end
end

# Schedule a pipeline
def schedule_pipeline(pipeline) do
  %{pipeline_id: pipeline.id}
  |> PollingWorker.new(schedule_in: {pipeline.interval_seconds, :second})
  |> Oban.insert()
end
```

### Webhook Receiver

```elixir
# lib/dash_web/controllers/pipeline_webhook_controller.ex
defmodule DashWeb.PipelineWebhookController do
  use DashWeb, :controller

  plug :verify_webhook_signature when action in [:receive]
  plug :rate_limit when action in [:receive]

  def receive(conn, %{"pipeline_id" => pipeline_id} = params) do
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id,
      load: [:sinks, :data_mapping]
    )

    # Verify pipeline is active and realtime type
    if pipeline.status == :active && pipeline.type == :realtime do
      # Parse webhook data
      data = parse_webhook_payload(params)

      # Process asynchronously
      Task.Supervisor.start_child(Dash.TaskSupervisor, fn ->
        process_webhook_data(pipeline, data)
      end)

      json(conn, %{status: "received", pipeline_id: pipeline_id})
    else
      conn
      |> put_status(400)
      |> json(%{error: "Pipeline not configured for webhooks"})
    end
  end

  defp verify_webhook_signature(conn, _opts) do
    signature = get_req_header(conn, "x-webhook-signature") |> List.first()
    pipeline_id = conn.path_params["pipeline_id"]

    # Get pipeline webhook secret
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id)
    secret = get_in(pipeline.source_config, ["webhook_secret"])

    # Read body
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    # Verify signature
    expected = :crypto.mac(:hmac, :sha256, secret, body)
                |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(signature || "", expected) do
      conn |> assign(:verified, true)
    else
      conn
      |> put_status(401)
      |> json(%{error: "Invalid signature"})
      |> halt()
    end
  end

  defp rate_limit(conn, _opts) do
    pipeline_id = conn.path_params["pipeline_id"]

    case Hammer.check_rate("webhook:#{pipeline_id}", 60_000, 100) do
      {:allow, _count} -> conn
      {:deny, _limit} ->
        conn
        |> put_status(429)
        |> json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  defp process_webhook_data(pipeline, data) do
    # Same processing as polling worker
    transformed = Dash.Pipelines.DataMapper.transform(data, pipeline.data_mapping)

    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(pipeline.id, pipeline.team_id, [transformed])
    end

    Dash.Data.CacheManager.update_recent_data(pipeline.id, [transformed])
    Phoenix.PubSub.broadcast(Dash.PubSub, "pipeline:#{pipeline.id}", {:new_data, [transformed]})
  end
end
```

### Source Adapters

```elixir
# lib/dash/pipelines/adapters/sources/http_api.ex
defmodule Dash.Pipelines.Adapters.Sources.HttpApi do
  @behaviour Dash.Pipelines.Adapters.SourceBehaviour

  @impl true
  def fetch(config) do
    url = config["url"]
    method = String.to_atom(config["method"] || "get")
    headers = build_headers(config)
    body = config["body"] || ""

    case HTTPoison.request(method, url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp build_headers(config) do
    base_headers = [{"Content-Type", "application/json"}]

    case config["auth_type"] do
      "bearer" ->
        [{"Authorization", "Bearer #{config["token"]}"} | base_headers]

      "api_key" ->
        [{config["api_key_header"], config["api_key"]} | base_headers]

      _ ->
        base_headers
    end
  end
end

# Behaviour definition
# lib/dash/pipelines/adapters/source_behaviour.ex
defmodule Dash.Pipelines.Adapters.SourceBehaviour do
  @callback fetch(config :: map()) :: {:ok, data :: term()} | {:error, reason :: term()}
end
```

---

