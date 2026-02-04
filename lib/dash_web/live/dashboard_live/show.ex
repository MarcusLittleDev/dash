defmodule DashWeb.DashboardLive.Show do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Dashboards.{Dashboard, PubSub, DataServer}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    dashboard = load_dashboard(id, socket.assigns.current_user)

    if connected?(socket) do
      # Subscribe to dashboard events
      PubSub.subscribe_dashboard(dashboard.id)

      # Subscribe to each widget and pipeline
      Enum.each(dashboard.widgets, fn widget ->
        PubSub.subscribe_widget(widget.id)
        PubSub.subscribe_pipeline(widget.pipeline_id)
      end)
    end

    # Load initial data for each widget
    widget_data =
      dashboard.widgets
      |> Enum.map(fn widget ->
        {widget.id, DataServer.get_data(widget.id, limit: get_limit(widget))}
      end)
      |> Map.new()

    socket =
      socket
      |> assign(:page_title, dashboard.name)
      |> assign(:dashboard, dashboard)
      |> assign(:widget_data, widget_data)
      |> assign(:editing, false)

    {:ok, socket}
  end

  @impl true
  def handle_info({:widget_data, widget_id, new_data}, socket) do
    widget_data =
      Map.update(socket.assigns.widget_data, widget_id, new_data, fn existing ->
        widget = find_widget(socket.assigns.dashboard.widgets, widget_id)
        limit = if widget, do: get_limit(widget), else: 100
        Enum.take(new_data ++ existing, limit)
      end)

    {:noreply, assign(socket, :widget_data, widget_data)}
  end

  @impl true
  def handle_info({:pipeline_data, _pipeline_id, _data}, socket) do
    # Pipeline data is handled via widget subscriptions
    {:noreply, socket}
  end

  @impl true
  def handle_info({:widget_added, widget}, socket) do
    dashboard = %{socket.assigns.dashboard | widgets: [widget | socket.assigns.dashboard.widgets]}
    PubSub.subscribe_widget(widget.id)
    PubSub.subscribe_pipeline(widget.pipeline_id)
    {:noreply, assign(socket, :dashboard, dashboard)}
  end

  @impl true
  def handle_info({:widget_removed, widget_id}, socket) do
    widgets = Enum.reject(socket.assigns.dashboard.widgets, &(&1.id == widget_id))
    dashboard = %{socket.assigns.dashboard | widgets: widgets}
    widget_data = Map.delete(socket.assigns.widget_data, widget_id)

    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:widget_data, widget_data)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:dashboard_updated, dashboard}, socket) do
    {:noreply, assign(socket, :dashboard, dashboard)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_widget", %{"id" => widget_id}, socket) do
    widget = find_widget(socket.assigns.dashboard.widgets, widget_id)

    if widget do
      case Ash.destroy(widget, actor: socket.assigns.current_user) do
        :ok ->
          PubSub.broadcast_widget_removed(socket.assigns.dashboard.id, widget_id)

          socket =
            socket
            |> put_flash(:info, "Widget deleted")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete widget")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <div>
          <div class="flex items-center space-x-3">
            <.link navigate={~p"/dashboards"} class="text-gray-400 hover:text-gray-600">
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </.link>
            <h1 class="text-2xl font-semibold text-gray-900"><%= @dashboard.name %></h1>
            <%= if @dashboard.is_default do %>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                Default
              </span>
            <% end %>
          </div>
          <%= if @dashboard.description do %>
            <p class="mt-1 text-sm text-gray-500"><%= @dashboard.description %></p>
          <% end %>
        </div>
        <div class="flex items-center space-x-3">
          <.link
            navigate={~p"/dashboards/#{@dashboard.id}/widgets/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
          >
            Add Widget
          </.link>
          <.link
            navigate={~p"/dashboards/#{@dashboard.id}/edit"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            Settings
          </.link>
        </div>
      </div>

      <%= if @dashboard.widgets == [] do %>
        <div class="text-center py-16 bg-white rounded-lg border-2 border-dashed border-gray-300">
          <svg
            class="mx-auto h-12 w-12 text-gray-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"
            />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">No widgets yet</h3>
          <p class="mt-1 text-sm text-gray-500">
            Add widgets to display data from your pipelines
          </p>
          <div class="mt-6">
            <.link
              navigate={~p"/dashboards/#{@dashboard.id}/widgets/new"}
              class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
            >
              Add Widget
            </.link>
          </div>
        </div>
      <% else %>
        <div class="grid grid-cols-12 gap-4 auto-rows-[100px]">
          <%= for widget <- @dashboard.widgets do %>
            <.widget_container
              widget={widget}
              data={Map.get(@widget_data, widget.id, [])}
              dashboard_id={@dashboard.id}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp widget_container(assigns) do
    ~H"""
    <div
      class="bg-white rounded-lg border border-gray-200 shadow-sm overflow-hidden"
      style={"grid-column: span #{@widget.position["w"]}; grid-row: span #{@widget.position["h"]};"}
    >
      <div class="flex justify-between items-center px-4 py-2 border-b border-gray-100 bg-gray-50">
        <h3 class="font-medium text-sm text-gray-900 truncate"><%= @widget.name %></h3>
        <div class="flex items-center space-x-2">
          <.link
            navigate={~p"/dashboards/#{@dashboard_id}/widgets/#{@widget.id}/edit"}
            class="text-gray-400 hover:text-gray-600"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
          </.link>
          <button
            phx-click="delete_widget"
            phx-value-id={@widget.id}
            data-confirm="Are you sure you want to delete this widget?"
            class="text-gray-400 hover:text-red-600"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
      <div class="p-4 h-[calc(100%-3rem)] overflow-hidden">
        <%= case @widget.type do %>
          <% :table -> %>
            <.table_widget config={@widget.config} data={@data} />
          <% :line_chart -> %>
            <.line_chart_widget widget_id={@widget.id} config={@widget.config} data={@data} />
          <% :stat_card -> %>
            <.stat_card_widget config={@widget.config} data={@data} />
          <% :bar_chart -> %>
            <.bar_chart_widget widget_id={@widget.id} config={@widget.config} data={@data} />
          <% _ -> %>
            <p class="text-gray-500 text-sm">Unknown widget type: <%= @widget.type %></p>
        <% end %>
      </div>
    </div>
    """
  end

  defp table_widget(assigns) do
    columns =
      case assigns.config["columns"] do
        cols when is_list(cols) and cols != [] -> cols
        _ -> auto_detect_columns(assigns.data)
      end
    rows = assigns.data || []

    assigns =
      assigns
      |> assign(:columns, columns)
      |> assign(:rows, rows)

    ~H"""
    <div class="overflow-auto h-full">
      <%= if @rows == [] do %>
        <div class="flex items-center justify-center h-full text-gray-400 text-sm">
          No data yet
        </div>
      <% else %>
        <table class="min-w-full text-sm">
          <thead class="bg-gray-50 sticky top-0">
            <tr>
              <%= for col <- @columns do %>
                <th class="px-3 py-2 text-left font-medium text-gray-600 text-xs uppercase tracking-wider">
                  <%= col["label"] || col["field"] %>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for row <- @rows do %>
              <tr class="hover:bg-gray-50">
                <%= for col <- @columns do %>
                  <td class="px-3 py-2 text-gray-900">
                    <%= format_cell(row[col["field"]], col["format"]) %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      <% end %>
    </div>
    """
  end

  defp line_chart_widget(assigns) do
    ~H"""
    <div
      id={"chart-#{@widget_id}"}
      phx-hook="LineChart"
      data-config={Jason.encode!(@config)}
      data-widget-id={@widget_id}
      data-initial-data={Jason.encode!(@data)}
      class="h-full w-full"
    >
      <canvas id={"canvas-#{@widget_id}"}></canvas>
    </div>
    """
  end

  defp stat_card_widget(assigns) do
    value = calculate_stat_value(assigns.data, assigns.config)
    formatted = format_stat_value(value, assigns.config)

    assigns =
      assigns
      |> assign(:value, formatted)
      |> assign(:label, assigns.config["label"] || "Value")

    ~H"""
    <div class="flex flex-col items-center justify-center h-full">
      <p class="text-4xl font-bold text-gray-900">
        <%= @value %><span class="text-2xl text-gray-500"><%= @config["suffix"] %></span>
      </p>
      <p class="text-sm text-gray-500 mt-2"><%= @label %></p>
    </div>
    """
  end

  defp bar_chart_widget(assigns) do
    ~H"""
    <div
      id={"bar-chart-#{@widget_id}"}
      phx-hook="BarChart"
      data-config={Jason.encode!(@config)}
      data-widget-id={@widget_id}
      data-initial-data={Jason.encode!(@data)}
      class="h-full w-full"
    >
      <canvas id={"bar-canvas-#{@widget_id}"}></canvas>
    </div>
    """
  end

  # Helper functions

  defp load_dashboard(id, actor) do
    Dashboard
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load(widgets: [:pipeline])
    |> Ash.read_one!(actor: actor)
  end

  defp find_widget(widgets, widget_id) do
    Enum.find(widgets, &(&1.id == widget_id))
  end

  defp get_limit(widget) do
    case widget.type do
      :table -> widget.config["max_rows"] || 50
      :line_chart -> widget.config["max_points"] || 100
      :stat_card -> 100
      :bar_chart -> widget.config["max_points"] || 50
      _ -> 50
    end
  end

  defp auto_detect_columns(data) do
    case data do
      [first | _] when is_map(first) ->
        first
        |> Map.keys()
        |> Enum.map(fn key -> %{"field" => key, "label" => humanize(key)} end)

      _ ->
        []
    end
  end

  defp humanize(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize(field), do: to_string(field)

  defp format_cell(nil, _format), do: "-"

  defp format_cell(value, "datetime") when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%H:%M:%S")
      _ -> value
    end
  end

  defp format_cell(value, "number") when is_number(value) do
    :erlang.float_to_binary(value / 1, decimals: 2)
  end

  defp format_cell(value, _format), do: to_string(value)

  defp calculate_stat_value([], _config), do: nil

  defp calculate_stat_value(data, config) do
    field = config["field"]
    values = data |> Enum.map(&(&1[field])) |> Enum.filter(&is_number/1)

    case config["aggregation"] do
      "latest" -> List.first(values)
      "avg" -> if values != [], do: Enum.sum(values) / length(values), else: nil
      "min" -> if values != [], do: Enum.min(values), else: nil
      "max" -> if values != [], do: Enum.max(values), else: nil
      "sum" -> Enum.sum(values)
      "count" -> length(values)
      _ -> List.first(values)
    end
  end

  defp format_stat_value(nil, _config), do: "-"

  defp format_stat_value(value, config) do
    decimals = config["decimals"] || 0
    :erlang.float_to_binary(value / 1, decimals: decimals)
  end
end
