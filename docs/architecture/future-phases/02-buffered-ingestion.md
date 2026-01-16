# Buffered Ingestion System

**Status**: 📋 Future Implementation (Phase 3 - Month 7+)
**Prerequisites**: High ingestion volume (>100 events/sec), database write contention observed

## Overview

The Buffered Ingestion Pattern prevents "write amplification" and database locking during traffic spikes by batching writes. This design trades immediate consistency for throughput and stability.

⚠️ **DO NOT implement during Phase 1-2**. Use simple Oban workers with direct `Ash.create!` calls for the MVP.

---

## Problem Statement

### Without Buffering (Phase 1-2 MVP)
```elixir
# Simple Oban worker - one write per webhook
defmodule Dash.Workers.WebhookReceiver do
  def perform(%{args: %{"payload" => data, "pipeline_id" => id}}) do
    # Direct database write
    Ash.create!(Dash.Pipelines.Event, %{
      pipeline_id: id,
      payload: data
    })
  end
end
```

**Issues at Scale**:
- 1000 webhooks/sec = 1000 database transactions/sec
- PostgreSQL lock contention on `pipeline_events` table
- Index update overhead for each insert
- Connection pool exhaustion

### With Buffering (Phase 3+)
```elixir
# BufferServer collects events in memory
GenServer.cast(buffer_server, {:buffer, event})
# ... waits ...
# Flushes 1000 events in single batch write
Ash.bulk_create!(events, batch_size: 1000)
```

**Benefits**:
- 1000 webhooks/sec → ~10 database transactions/sec
- Reduced lock contention (90%+ reduction)
- Bulk index updates (faster)
- Stable connection pool usage

---

## Architecture

### Component: `Dash.Ingestion.BufferServer`

**Type**: GenServer (Partitioned via PartitionSupervisor)

**Sharding Strategy**: One process per active pipeline

**Lifecycle**:
- Started dynamically when pipeline receives first event
- Remains alive while events are flowing
- Hibernates after 5 minutes of inactivity
- Terminated after 1 hour of inactivity

---

## Implementation

### BufferServer Module

```elixir
defmodule Dash.Ingestion.BufferServer do
  use GenServer
  require Logger

  @max_buffer_size 1_000
  @max_buffer_age_ms 1_000

  # Client API

  def start_link(pipeline_id) do
    GenServer.start_link(__MODULE__, pipeline_id,
      name: {:via, PartitionSupervisor, {__MODULE__, pipeline_id}}
    )
  end

  def buffer_event(pipeline_id, payload) do
    GenServer.cast(
      {:via, PartitionSupervisor, {__MODULE__, pipeline_id}},
      {:buffer, payload}
    )
  end

  # Server Callbacks

  @impl true
  def init(pipeline_id) do
    state = %{
      pipeline_id: pipeline_id,
      buffer: [],
      oldest_event_at: nil,
      stats: %{buffered: 0, flushed: 0}
    }

    # Schedule periodic flush check
    schedule_flush_check()

    {:ok, state}
  end

  @impl true
  def handle_cast({:buffer, payload}, state) do
    now = System.monotonic_time(:millisecond)

    new_buffer = [
      %{
        pipeline_id: state.pipeline_id,
        payload: payload,
        ingested_at: DateTime.utc_now()
      }
      | state.buffer
    ]

    new_state = %{
      state
      | buffer: new_buffer,
        oldest_event_at: state.oldest_event_at || now,
        stats: %{state.stats | buffered: state.stats.buffered + 1}
    }

    # Flush if buffer is full
    if length(new_buffer) >= @max_buffer_size do
      {:noreply, flush_buffer(new_state)}
    else
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_info(:flush_check, state) do
    schedule_flush_check()

    # Flush if oldest event is too old
    if should_flush_by_age?(state) do
      {:noreply, flush_buffer(state)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:hibernate, state) do
    {:noreply, state, :hibernate}
  end

  # Private Functions

  defp should_flush_by_age?(%{oldest_event_at: nil}), do: false

  defp should_flush_by_age?(%{oldest_event_at: oldest}) do
    now = System.monotonic_time(:millisecond)
    (now - oldest) >= @max_buffer_age_ms
  end

  defp flush_buffer(%{buffer: []} = state), do: state

  defp flush_buffer(state) do
    events = Enum.reverse(state.buffer)
    count = length(events)

    Logger.info(
      "Flushing #{count} events for pipeline #{state.pipeline_id}"
    )

    # Bulk insert using Ash
    case Ash.bulk_create(events, Dash.Pipelines.Event, :create,
           return_errors?: true,
           batch_size: 1000,
           sorted?: true
         ) do
      %{records: records} ->
        Logger.debug("Successfully inserted #{length(records)} events")

        # Broadcast update to dashboards
        Phoenix.PubSub.broadcast(
          Dash.PubSub,
          "pipeline:#{state.pipeline_id}",
          {:data_updated, %{count: count, last_event: List.first(records)}}
        )

        %{
          state
          | buffer: [],
            oldest_event_at: nil,
            stats: %{state.stats | flushed: state.stats.flushed + count}
        }

      {:error, reason} ->
        Logger.error("Bulk insert failed: #{inspect(reason)}")
        # Keep buffer, retry on next flush
        state
    end
  end

  defp schedule_flush_check do
    Process.send_after(self(), :flush_check, 100)
  end
end
```

---

## Supervision Tree

```elixir
defmodule Dash.Ingestion.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {PartitionSupervisor,
       child_spec: Dash.Ingestion.BufferServer,
       name: Dash.Ingestion.BufferPartitions,
       partitions: 10}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

Add to application supervisor:
```elixir
# lib/dash/application.ex
children = [
  # ...
  Dash.Ingestion.Supervisor,  # Add after Oban
  # ...
]
```

---

## Backpressure Mechanism

### Queue Depth Monitoring

```elixir
defmodule Dash.Ingestion.Backpressure do
  @max_queue_length 5_000

  def check_backpressure(pipeline_id) do
    case GenServer.whereis({:via, PartitionSupervisor, {BufferServer, pipeline_id}}) do
      nil ->
        :ok

      pid ->
        {:message_queue_len, queue_len} = Process.info(pid, :message_queue_len)

        if queue_len > @max_queue_length do
          {:error, :too_many_requests}
        else
          :ok
        end
    end
  end
end
```

### Webhook Endpoint with Backpressure

```elixir
defmodule DashWeb.WebhookController do
  use DashWeb, :controller

  def receive_webhook(conn, %{"pipeline_id" => id, "data" => data}) do
    case Dash.Ingestion.Backpressure.check_backpressure(id) do
      :ok ->
        Dash.Ingestion.BufferServer.buffer_event(id, data)
        json(conn, %{status: "accepted"})

      {:error, :too_many_requests} ->
        conn
        |> put_status(429)
        |> json(%{error: "Too many requests, please slow down"})
    end
  end
end
```

---

## Shard Isolation

### Why Partition?

Without partitioning, a single high-volume pipeline could monopolize resources:
- One pipeline sending 10,000 events/sec
- Single BufferServer process CPU-bound
- Other pipelines starved

### Solution: Consistent Hashing

```elixir
defmodule Dash.Ingestion.Partitioner do
  @partitions 10

  def partition_for_pipeline(pipeline_id) do
    # Deterministic partition based on pipeline ID
    :erlang.phash2(pipeline_id, @partitions)
  end

  def buffer_server_name(pipeline_id) do
    partition = partition_for_pipeline(pipeline_id)
    {:via, PartitionSupervisor, {BufferServer, pipeline_id, partition}}
  end
end
```

**Result**:
- 10 partitions = 10 separate BufferServer processes
- Each can saturate one CPU core independently
- High-volume pipeline isolated to its partition
- Other pipelines unaffected

---

## Monitoring & Observability

### Telemetry Events

```elixir
# In flush_buffer/1
:telemetry.execute(
  [:dash, :ingestion, :flush],
  %{
    count: count,
    duration: flush_duration_ms
  },
  %{
    pipeline_id: state.pipeline_id,
    partition: partition_number(self())
  }
)
```

### Metrics Dashboard

Track in LiveDashboard or external monitoring:
- `ingestion.buffer_size` (gauge) - Current events in buffer
- `ingestion.flush_count` (counter) - Total flushes performed
- `ingestion.flush_duration` (histogram) - Time to flush in ms
- `ingestion.backpressure_rejections` (counter) - 429 responses sent

---

## Performance Characteristics

### Throughput Comparison

| Scenario | Without Buffering | With Buffering |
|----------|------------------|----------------|
| 100 events/sec | ✅ 100 writes/sec | ✅ ~1 write/sec |
| 1,000 events/sec | ⚠️ 1,000 writes/sec | ✅ ~10 writes/sec |
| 10,000 events/sec | ❌ Database overwhelmed | ✅ ~100 writes/sec |

### Latency Trade-offs

| Metric | Without Buffering | With Buffering |
|--------|------------------|----------------|
| Write latency | <10ms (immediate) | 0-1000ms (buffered) |
| Dashboard update | Immediate | 0-1000ms delay |
| Database load | High, spiky | Low, smooth |

**Acceptable for**: Analytics dashboards (eventual consistency OK)
**Not acceptable for**: Transactional systems (strong consistency required)

---

## Migration from Simple Oban Workers

### Phase 1-2: Direct Writes (Current)
```elixir
# Webhook controller
Oban.insert!(Dash.Workers.ProcessWebhook.new(%{
  pipeline_id: pipeline_id,
  payload: data
}))

# Worker
defmodule Dash.Workers.ProcessWebhook do
  use Oban.Worker

  def perform(%{args: %{"pipeline_id" => id, "payload" => data}}) do
    Ash.create!(Dash.Pipelines.Event, %{pipeline_id: id, payload: data})
  end
end
```

### Phase 3: Buffered Writes (Future)
```elixir
# Webhook controller
Dash.Ingestion.BufferServer.buffer_event(pipeline_id, data)
# No Oban worker needed!
```

### Migration Steps

1. Deploy BufferServer code (inactive)
2. Add feature flag: `config :dash, :use_buffered_ingestion, false`
3. Enable for 1 test pipeline
4. Monitor metrics (latency, throughput, errors)
5. Gradually roll out to more pipelines
6. Remove old Oban worker once 100% migrated

---

## When to Implement

### Signals You Need Buffering

✅ Implement if you observe:
- Database CPU consistently > 60% from writes
- Lock contention on `pipeline_events` table
- Connection pool frequently exhausted
- Write latency increasing with traffic

❌ Don't implement if:
- Handling < 100 events/second
- Database CPU < 40%
- No user complaints about performance
- Still in MVP phase

---

## References

- [GenServer Backpressure](https://hexdocs.pm/elixir/GenServer.html#module-receiving-regular-messages)
- [Ash Bulk Actions](https://hexdocs.pm/ash/bulk-actions.html)
- [PartitionSupervisor](https://hexdocs.pm/elixir/PartitionSupervisor.html)
- [Telemetry Events](https://hexdocs.pm/telemetry/readme.html)

---

**Implementation Timeline**: Phase 3 (Month 7-8)
**Estimated Effort**: 1-2 weeks
**Risk Level**: Low-Medium (well-understood pattern)
**Dependencies**: High traffic volume, observed database contention
