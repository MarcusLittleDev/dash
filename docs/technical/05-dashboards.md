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

