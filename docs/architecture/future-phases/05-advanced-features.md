# Advanced Features Roadmap

**Status**: 📋 Future Implementation (Phase 3+)
**Prerequisites**: Core platform stable, customer feedback validated

## Overview

This document outlines advanced features that leverage Phoenix/Elixir's unique strengths. These features are not needed for MVP but represent the product's long-term competitive advantages.

---

## 1. Configurable Drag-and-Drop Dashboards

**Target Phase**: Phase 3
**Technology**: Gridstack.js + LiveView Hooks

### Why Gridstack.js

Gridstack is the industry standard for dashboard grid layouts. It handles:
- Drag-and-drop widget positioning
- Resize with "magnetic" snapping
- Mobile responsiveness
- Collision detection

### Integration Pattern

```javascript
// assets/js/hooks/gridstack.js
export const GridstackHook = {
  mounted() {
    this.grid = GridStack.init({
      column: 12,
      cellHeight: 80,
      animate: true,
      float: true
    });

    // When user drags/resizes, push to LiveView
    this.grid.on('change', (event, items) => {
      const layout = items.map(item => ({
        id: item.id,
        x: item.x, y: item.y,
        w: item.w, h: item.h
      }));
      this.pushEvent("layout_changed", { layout });
    });

    // When server pushes layout (collaboration), update grid
    this.handleEvent("sync_layout", ({ layout }) => {
      this.grid.load(layout);
    });
  }
};
```

```elixir
# lib/dash_web/live/dashboard_live.ex
def handle_event("layout_changed", %{"layout" => layout}, socket) do
  # Save to database
  Dashboard.update_layout(socket.assigns.dashboard, layout)

  # Broadcast to other viewers (collaboration)
  Phoenix.PubSub.broadcast(
    Dash.PubSub,
    "dashboard:#{socket.assigns.dashboard.id}",
    {:layout_updated, layout}
  )

  {:noreply, socket}
end

def handle_info({:layout_updated, layout}, socket) do
  {:noreply, push_event(socket, "sync_layout", %{layout: layout})}
end
```

### Why This Works Better in Phoenix

| Aspect | Standard Stack (React/Node) | Phoenix/LiveView |
|--------|----------------------------|------------------|
| State Sync | Client-first, complex conflict resolution | Server-authoritative, single source of truth |
| Collaboration | Needs separate WebSocket infrastructure | Built into LiveView + PubSub |
| Latency | Client → API → DB → WebSocket broadcast | Client → LiveView → PubSub (single hop) |

### Implementation Notes

- **Phase 2**: Start with fixed grid layout (CSS Grid, no drag)
- **Phase 3**: Add Gridstack when "user-configurable layouts" is prioritized
- Store layout as JSONB in `dashboards.layout` column (already in schema)

---

## 2. Widget Customization & Logic

**Target Phase**: Phase 3 (simple), Phase 4+ (advanced)
**Technology**: JSONLogic → Wasmex (WebAssembly)

### Phase 3: JSONLogic for Simple Rules

Before building a full code execution environment, use JSONLogic for conditional formatting and simple transformations.

```elixir
# Example: Conditional formatting rule
%{
  "condition" => %{
    ">" => [%{"var" => "value"}, 100]
  },
  "then" => %{"background" => "red", "color" => "white"},
  "else" => %{"background" => "green"}
}

# Evaluation using json_logic library
defmodule Dash.Widgets.ConditionalFormat do
  def apply(data, rules) do
    JsonLogic.apply(rules["condition"], data)
    |> case do
      true -> rules["then"]
      false -> rules["else"]
    end
  end
end
```

**Use cases covered**:
- "Turn red if value > 50"
- "Show warning icon if status = 'error'"
- "Format as currency if type = 'money'"

### Phase 4+: Wasmex for Custom Code

For advanced users who need real code execution:

```elixir
defmodule Dash.Widgets.WasmRunner do
  @moduledoc """
  Runs user-provided WebAssembly in a sandboxed environment.
  User code cannot access filesystem, network, or env vars.
  """

  def execute(wasm_binary, input_data) do
    {:ok, store} = Wasmex.Store.new()
    {:ok, module} = Wasmex.Module.compile(store, wasm_binary)
    {:ok, instance} = Wasmex.Instance.new(store, module, %{})

    # Call the user's transform function
    Wasmex.Instance.call_function(instance, "transform", [input_data])
  end
end
```

**Why Wasmex**:
- **Sandboxed**: User code cannot crash the server or access secrets
- **Fast**: Near-native performance via Rust runtime
- **Polyglot**: Users can write in Rust, Go, AssemblyScript, etc.

**The Widget Store concept**: Registry of `.wasm` files that users can install on their dashboards.

### BEAM Advantage: Fault Isolation

Each widget runs in its own Elixir process. If one widget's Wasm code crashes or loops:
- Only that process dies
- Supervisor restarts it immediately
- Other widgets and dashboards are unaffected
- BEAM's preemptive scheduler prevents CPU monopolization

In Node.js, a bad widget would freeze the entire event loop.

---

## 3. Real-time Collaboration

**Target Phase**: Phase 2 (basic), Phase 3+ (advanced)
**Technology**: Phoenix Presence → Locking → Y.js (if needed)

### Phase 2: Presence (Who's Viewing)

Phoenix Presence provides "who's online" for free:

```elixir
# lib/dash_web/live/dashboard_live.ex
def mount(_params, _session, socket) do
  if connected?(socket) do
    DashWeb.Presence.track(self(), "dashboard:#{dashboard.id}", socket.assigns.current_user.id, %{
      name: socket.assigns.current_user.email,
      joined_at: DateTime.utc_now()
    })
  end

  presences = DashWeb.Presence.list("dashboard:#{dashboard.id}")
  {:ok, assign(socket, presences: presences)}
end

def handle_info(%{event: "presence_diff", payload: diff}, socket) do
  presences = DashWeb.Presence.list("dashboard:#{socket.assigns.dashboard.id}")
  {:noreply, assign(socket, presences: presences)}
end
```

**Result**: Show avatars of users currently viewing the dashboard.

### Phase 3: Widget Locking

Simple locking prevents edit conflicts without CRDTs:

```elixir
defmodule Dash.Collaboration.WidgetLock do
  use GenServer

  def acquire_lock(widget_id, user_id) do
    GenServer.call(__MODULE__, {:acquire, widget_id, user_id})
  end

  def release_lock(widget_id, user_id) do
    GenServer.cast(__MODULE__, {:release, widget_id, user_id})
  end

  def handle_call({:acquire, widget_id, user_id}, _from, locks) do
    case Map.get(locks, widget_id) do
      nil ->
        {:reply, :ok, Map.put(locks, widget_id, user_id)}
      ^user_id ->
        {:reply, :ok, locks}
      other_user ->
        {:reply, {:error, :locked_by, other_user}, locks}
    end
  end
end
```

**UX**: "User A is editing this widget" indicator, others see read-only.

### Phase 4+: Y.js CRDTs (If Needed)

Only add Y.js if customers explicitly need Google Docs-style simultaneous editing:

```elixir
# Using y_crdt Elixir bindings
defmodule Dash.Collaboration.CRDT do
  def merge_layouts(local_layout, remote_layout) do
    # CRDTs mathematically guarantee convergence
    # Both users end up with same final state
    YCrdt.Doc.merge(local_layout, remote_layout)
  end
end
```

**When to add CRDTs**:
- Multiple users need to edit the same widget simultaneously
- Offline editing with later sync is required
- Customer explicitly requests "Google Docs for dashboards"

**When NOT to add CRDTs**:
- View-only collaboration (Presence is sufficient)
- Single editor at a time (Locking is sufficient)
- Most dashboard use cases

---

## 4. AI-Powered Insights

**Target Phase**: Phase 3+
**Technology**: Bumblebee + Nx (local LLMs)

### The "Ask My Pipeline" Feature

```elixir
defmodule Dash.AI.Analyst do
  @moduledoc """
  Runs local LLM to answer questions about pipeline data.
  Data never leaves the server - key privacy differentiator.
  """

  def analyze(pipeline_id, question) do
    # 1. Gather context from Silver layer
    context = gather_pipeline_context(pipeline_id)

    # 2. Build prompt
    prompt = """
    You are a data analyst. Given this pipeline data:
    #{Jason.encode!(context)}

    Answer this question: #{question}

    Be concise and reference specific data points.
    """

    # 3. Run local model (no external API call)
    {:ok, response} = Bumblebee.Text.generation(
      model: {:hf, "meta-llama/Llama-3-8B"},
      prompt: prompt,
      max_new_tokens: 200
    )

    response
  end

  defp gather_pipeline_context(pipeline_id) do
    %{
      recent_data: get_recent_records(pipeline_id, limit: 100),
      statistics: calculate_stats(pipeline_id),
      anomalies: detect_anomalies(pipeline_id)
    }
  end
end
```

### Example Interaction

```
User: "Why did orders drop on Tuesday?"

System internally:
1. Queries Silver layer → finds -40% drop on Tuesday
2. Checks Bronze layer → finds 3-hour gap in webhook data
3. Correlates with pipeline health metrics

AI Response: "Orders dropped 40% on Tuesday. This correlates with
a 3-hour gap in webhook data from your Shopify pipeline between
2pm-5pm EST (12 webhooks expected, 0 received). Likely cause:
upstream API outage or webhook delivery failure."
```

### Why Local LLMs Matter

| Aspect | External API (OpenAI) | Local Model (Bumblebee) |
|--------|----------------------|------------------------|
| Privacy | Data leaves your server | Data never leaves RAM |
| Latency | Network RTT + queue time | In-memory inference |
| Cost | Per-token charges | Fixed infrastructure cost |
| Compliance | Hard for HIPAA/SOC2 | Air-gapped, auditable |

### Implementation Notes

- Start with **small, fast models**: Llama 3 8B, Mistral 7B
- First use case: **anomaly explanation**, not general chat
- Offer as **premium/enterprise feature** (GPU cost justification)
- Fly.io has GPU nodes available for Bumblebee workloads

---

## 5. Reliability Infrastructure (Phase 3+)

### Horde: Distributed Process Management

Replace `DynamicSupervisor` with `Horde.DynamicSupervisor` for automatic process migration when nodes fail.

```elixir
# If ingestor node crashes, Horde restarts BufferServers on healthy node
defmodule Dash.Pipelines.DistributedSupervisor do
  use Horde.DynamicSupervisor

  def start_link(init_arg) do
    Horde.DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_) do
    Horde.DynamicSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
```

**When to adopt**: When you have 2+ ingestor nodes and need "at-least-once" guarantees for stateful GenServers.

### Vector: Data Plane Offloading

Offload Bronze layer writes from BEAM to a Rust sidecar:

```
Elixir BufferServer → Local Socket → Vector → R2/S3
```

**Benefits**:
- If R2 is slow, Vector buffers to disk (BEAM doesn't hang)
- Rust performance for high-throughput I/O
- Built-in retries and backpressure

**When to adopt**: When Bronze layer writes become a bottleneck (>10k events/sec).

### OpenTelemetry: Distributed Tracing

Add tracing across web → ingestor → storage:

```elixir
# mix.exs
{:opentelemetry_phoenix, "~> 1.0"},
{:opentelemetry_ash, "~> 1.0"},
{:opentelemetry_ecto, "~> 1.0"}

# Traces a webhook from receipt to storage
# Trace ID: abc-123
#   Phoenix Receive: 2ms
#   Buffer Wait: 4800ms  ← "Ah! Buffer was waiting for batch"
#   Ash Persist: 15ms
```

**When to adopt**: Phase 2+ for debugging distributed systems.

---

## Summary: Phased Adoption

| Feature | Phase 2 | Phase 3 | Phase 4+ |
|---------|---------|---------|----------|
| **Dashboards** | Fixed layouts | Gridstack drag-and-drop | Templates & marketplace |
| **Widget Logic** | Static display | JSONLogic conditionals | Wasmex custom code |
| **Collaboration** | Presence (who's viewing) | Widget locking | Y.js CRDTs (if needed) |
| **AI Insights** | — | Anomaly detection | "Ask my Pipeline" |
| **Reliability** | Oban for resilience | OpenTelemetry tracing | Horde + Vector |

---

## The Phoenix/BEAM Advantage

These features aren't bolted-on afterthoughts—they leverage Phoenix's core strengths:

1. **Collaboration**: Phoenix Presence + PubSub handle real-time sync that would require Redis + Socket.io elsewhere
2. **Widget Isolation**: BEAM's process model + preemptive scheduling means one bad widget can't freeze others
3. **AI Privacy**: Bumblebee runs in-process, data never serializes to external API
4. **Scalability**: Phoenix Channels multiplex chat + data over single WebSocket

> "By choosing Elixir, you aren't just 'enabling' these features; you are building them on the platform that was invented to solve exactly these concurrency problems."

---

## Related Documentation

- [01-distributed-architecture.md](01-distributed-architecture.md) - Multi-node clustering
- [02-buffered-ingestion.md](02-buffered-ingestion.md) - High-throughput data ingestion
- [03-advanced-timescaledb.md](03-advanced-timescaledb.md) - Time-series optimization
- [../technical/05-dashboards.md](../../technical/05-dashboards.md) - Current dashboard implementation
