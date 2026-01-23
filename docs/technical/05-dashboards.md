## Dashboard & Widget System

### LiveView Dashboard

```elixir
# lib/dash_web/live/dashboard_live.ex
defmodule DashWeb.DashboardLive do
  use DashWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    # Load dashboard with all associations
    dashboard = Ash.get!(Dash.Dashboards.Dashboard, :get_by_slug,
      %{slug: slug},
      load: [:widgets, :pipelines, :team],
      actor: get_actor(session)
    )
    
    # Subscribe to pipeline updates if connected
    if connected?(socket) do
      Enum.each(dashboard.pipelines, fn pipeline ->
        Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline.id}")
      end)
    end
    
    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:widgets, dashboard.widgets)
      |> assign(:is_public, dashboard.is_public)
      |> load_widget_data()
    
    {:ok, socket}
  end

  @impl true
  def handle_info({:new_data, pipeline_id, data}, socket) do
    # Update widgets that use this pipeline
    socket = update_widgets_for_pipeline(socket, pipeline_id, data)
    {:noreply, socket}
  end

  defp load_widget_data(socket) do
    widget_data =
      Enum.map(socket.assigns.widgets, fn widget ->
        data = fetch_widget_data(widget)
        {widget.id, data}
      end)
      |> Map.new()
    
    assign(socket, :widget_data, widget_data)
  end

  defp fetch_widget_data(widget) do
    pipeline_id = get_in(widget.data_query, ["pipeline_id"])
    
    # Try cache first (last 100 records)
    case Dash.Data.CacheManager.get_recent_data(pipeline_id) do
      data when length(data) > 0 ->
        # Have cached data, use it
        prepare_for_widget(data, widget)
      
      [] ->
        # No cache, query database
        from_time = DateTime.add(DateTime.utc_now(), -1, :hour)
        data = Dash.Data.PipelineData.query_for_widget(pipeline_id,
          from: from_time,
          limit: 100
        )
        prepare_for_widget(data, widget)
    end
  end

  defp prepare_for_widget(data, widget) do
    Dash.Dashboards.WidgetDataTransformer.prepare_for_widget(data, widget)
  end
end
```

### Widget Components

```elixir
# lib/dash_web/components/widgets.ex
defmodule DashWeb.Components.Widgets do
  use Phoenix.Component
  
  def widget(assigns) do
    ~H"""
    <div class="widget" data-widget-id={@widget.id}>
      <div class="widget-header">
        <h3><%= @widget.config["title"] || "Untitled Widget" %></h3>
      </div>
      <div class="widget-body">
        <%= render_widget_content(assigns) %>
      </div>
    </div>
    """
  end

  defp render_widget_content(%{widget: %{type: "line_chart"}} = assigns) do
    ~H"""
    <canvas
      id={"chart-#{@widget.id}"}
      phx-hook="Chart"
      phx-update="ignore"
      data-chart-config={Jason.encode!(@chart_config)}
    >
    </canvas>
    """
  end

  defp render_widget_content(%{widget: %{type: "table"}} = assigns) do
    ~H"""
    <table class="data-table">
      <thead>
        <tr>
          <%= for field <- @widget.config["fields"] do %>
            <th><%= field %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @data do %>
          <tr>
            <%= for field <- @widget.config["fields"] do %>
              <td><%= get_in(row, ["data", field]) %></td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp render_widget_content(%{widget: %{type: "stat_card"}} = assigns) do
    ~H"""
    <div class="stat-card">
      <div class="stat-value"><%= @value %></div>
      <div class="stat-label"><%= @widget.config["label"] %></div>
    </div>
    """
  end
end
```

### Chart.js Hook

```javascript
// assets/js/hooks/chart.js
import Chart from 'chart.js/auto';

export const ChartHook = {
  mounted() {
    const ctx = this.el.getContext('2d');
    const config = JSON.parse(this.el.dataset.chartConfig);
    
    this.chart = new Chart(ctx, config);
    
    // Listen for updates from LiveView
    this.handleEvent("update-chart", ({data, labels}) => {
      this.chart.data.labels = labels;
      this.chart.data.datasets[0].data = data;
      this.chart.update('none'); // No animation for smooth updates
    });
  },
  
  updated() {
    const config = JSON.parse(this.el.dataset.chartConfig);
    this.chart.data = config.data;
    this.chart.options = config.options;
    this.chart.update();
  },
  
  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};
```

---

## External Real-time Access

For customers who want to display Dash pipeline data in their own applications, there are multiple approaches:

### Phase 1: Webhook Sinks (Recommended for MVP)

**Status**: Included in MVP

Customers configure a webhook sink on their pipeline. When new data arrives, Dash sends HTTP POST to their endpoint.

**Implementation**:
```elixir
# Already in 04-pipelines.md - Sink Adapters
defmodule Dash.Pipelines.Adapters.Sinks.Webhook do
  def send(config, data) do
    HTTPoison.post(
      config["url"],
      Jason.encode!(data),
      [{"Content-Type", "application/json"}]
    )
  end
end
```

**Customer's system** receives webhook and broadcasts to their frontend:
```javascript
// Customer's backend receives Dash webhook
// Then broadcasts via their own SSE/WebSocket

// Customer's frontend:
const eventSource = new EventSource('/api/pipeline-events');
eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  updateUI(data);
};
```

**Advantages**:
- ✅ Customer controls their infrastructure
- ✅ No CORS or authentication complexity
- ✅ Works with any tech stack
- ✅ Can be monetized (webhook delivery charges)

---

### Phase 2: Server-Sent Events (SSE) API

**Status**: Future enhancement (Phase 2+)

Direct browser subscription to Dash pipeline events via SSE.

**Implementation**:
```elixir
# lib/dash_web/controllers/pipeline_events_controller.ex
defmodule DashWeb.PipelineEventsController do
  use DashWeb, :controller

  def stream(conn, %{"pipeline_id" => pipeline_id, "token" => token}) do
    with {:ok, pipeline} <- verify_pipeline_token(pipeline_id, token),
         :ok <- authorize_access(conn, pipeline) do

      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)
      |> stream_events(pipeline_id)
    end
  end

  defp stream_events(conn, pipeline_id) do
    Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline_id}")

    receive do
      {:new_data, data} ->
        chunk(conn, "data: #{Jason.encode!(data)}\n\n")
        stream_events(conn, pipeline_id)
    after
      30_000 ->
        chunk(conn, ":keepalive\n\n")
        stream_events(conn, pipeline_id)
    end
  end
end
```

**Customer's JavaScript**:
```javascript
const eventSource = new EventSource(
  'https://dash.app/api/pipelines/abc-123/stream?token=secret_token'
);

eventSource.onmessage = (event) => {
  const pipelineData = JSON.parse(event.data);
  updateDashboard(pipelineData);
};

eventSource.onerror = (error) => {
  console.error('SSE connection error:', error);
  // Auto-reconnects by default
};
```

**Advantages**:
- ✅ Native browser API (EventSource)
- ✅ Automatic reconnection
- ✅ Simple for customers
- ✅ One-way communication (server → client)

**Considerations**:
- Requires CORS configuration
- Token-based authentication (in query string)
- Keeps connections open (monitor resource usage)

**Security**:
```elixir
# Generate pipeline-specific access token
attribute :public_stream_token, :string do
  default &Ash.UUID.generate/0
  writable? false
  public? true
end

# Rate limiting
case Hammer.check_rate("pipeline_stream:#{pipeline_id}", 60_000, 1000) do
  {:allow, _count} -> :ok
  {:deny, _limit} -> {:error, :rate_limit_exceeded}
end

# CORS configuration
config :cors_plug,
  origin: ["https://customer-domain.com"],
  max_age: 86400,
  methods: ["GET"]
```

---

### Phase 3: GraphQL Subscriptions (Enterprise)

**Status**: Future enhancement (Phase 3+)

Modern GraphQL-based real-time API when Ash GraphQL is enabled.

**Implementation**:
```elixir
# Absinthe GraphQL subscription
subscription do
  field :pipeline_events, :pipeline_event do
    arg :pipeline_id, non_null(:id)
    arg :token, non_null(:string)

    config fn args, _context ->
      {:ok, topic: "pipeline:#{args.pipeline_id}"}
    end

    trigger :new_pipeline_data,
      topic: fn data -> "pipeline:#{data.pipeline_id}" end
  end
end
```

**Customer's JavaScript**:
```javascript
import { GraphQLWsLink } from '@apollo/client/link/subscriptions';
import { createClient } from 'graphql-ws';

const client = createClient({
  url: 'wss://dash.app/api/graphql',
  connectionParams: { token: 'secret_pipeline_token' }
});

client.subscribe({
  query: `
    subscription {
      pipelineEvents(pipelineId: "abc-123", token: "secret") {
        timestamp
        data
        metrics
      }
    }
  `
}, {
  next: (data) => updateDashboard(data),
  error: (err) => console.error(err)
});
```

**Advantages**:
- ✅ Industry standard (GraphQL)
- ✅ Type-safe queries
- ✅ Can combine with regular queries
- ✅ Enterprise-friendly

---

### Comparison Matrix

| Feature | Webhooks (Phase 1) | SSE (Phase 2) | GraphQL (Phase 3) |
|---------|-------------------|---------------|-------------------|
| **Browser Direct** | ❌ No | ✅ Yes | ✅ Yes |
| **Real-time** | ~seconds delay | ✅ Instant | ✅ Instant |
| **Complexity** | Low | Medium | High |
| **Customer Setup** | Backend required | Frontend only | Frontend only |
| **Bidirectional** | ❌ No | ❌ No | ✅ Yes |
| **Reconnection** | Manual | ✅ Automatic | ✅ Automatic |
| **Auth Method** | HMAC signature | Token in URL | Token in header |
| **CORS Required** | ❌ No | ✅ Yes | ✅ Yes |
| **Open Connections** | None | Medium | Medium |

### Recommendation

**Phase 1 (MVP)**: Webhook sinks only - covers 95% of use cases, simple, reliable

**Phase 2 (Growth)**: Add SSE when customers specifically request direct browser access

**Phase 3 (Enterprise)**: GraphQL subscriptions for enterprise customers who need advanced features

---

