defmodule DashWeb.DashboardLive.WidgetForm do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Dashboards.{Dashboard, Widget, PubSub}
  alias Dash.Pipelines.Pipeline

  @impl true
  def mount(%{"dashboard_id" => dashboard_id} = params, _session, socket) do
    dashboard = load_dashboard(dashboard_id, socket.assigns.current_user)
    pipelines = load_pipelines(socket.assigns.current_org, socket.assigns.current_user)

    {widget, action} =
      case params do
        %{"widget_id" => widget_id} ->
          {load_widget(widget_id, socket.assigns.current_user), :edit}

        _ ->
          {%Widget{type: :table, config: %{}, position: %{"x" => 0, "y" => 0, "w" => 6, "h" => 4}}, :new}
      end

    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:widget, widget)
      |> assign(:pipelines, pipelines)
      |> assign(:action, action)
      |> assign(:selected_type, widget.type || :table)
      |> assign(:page_title, if(action == :new, do: "Add Widget", else: "Edit Widget"))
      |> assign(:form, build_form(widget))

    {:ok, socket}
  end

  @impl true
  def handle_event("select_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_type, String.to_existing_atom(type))}
  end

  @impl true
  def handle_event("validate", %{"widget" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(params))}
  end

  @impl true
  def handle_event("save", %{"widget" => params}, socket) do
    config = build_config(socket.assigns.selected_type, params)
    position = build_position(params)

    widget_params = %{
      name: params["name"],
      type: socket.assigns.selected_type,
      config: config,
      position: position,
      dashboard_id: socket.assigns.dashboard.id,
      pipeline_id: params["pipeline_id"]
    }

    case socket.assigns.action do
      :new -> create_widget(socket, widget_params)
      :edit -> update_widget(socket, widget_params)
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Ash.destroy(socket.assigns.widget, actor: socket.assigns.current_user) do
      :ok ->
        PubSub.broadcast_widget_removed(socket.assigns.dashboard.id, socket.assigns.widget.id)

        {:noreply,
         socket
         |> put_flash(:info, "Widget deleted")
         |> push_navigate(to: ~p"/dashboards/#{socket.assigns.dashboard.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete widget")}
    end
  end

  defp create_widget(socket, params) do
    case Widget
         |> Ash.Changeset.for_create(:create, params)
         |> Ash.create(actor: socket.assigns.current_user) do
      {:ok, widget} ->
        # Broadcast to dashboard subscribers
        PubSub.broadcast_widget_added(socket.assigns.dashboard.id, widget)

        {:noreply,
         socket
         |> put_flash(:info, "Widget created")
         |> push_navigate(to: ~p"/dashboards/#{socket.assigns.dashboard.id}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  defp update_widget(socket, params) do
    # Remove dashboard_id and pipeline_id from update params (can't change these)
    update_params = Map.drop(params, [:dashboard_id, :pipeline_id])

    case socket.assigns.widget
         |> Ash.Changeset.for_update(:update, update_params)
         |> Ash.update(actor: socket.assigns.current_user) do
      {:ok, widget} ->
        PubSub.broadcast_widget_config_updated(widget.id, widget.config)

        {:noreply,
         socket
         |> put_flash(:info, "Widget updated")
         |> push_navigate(to: ~p"/dashboards/#{socket.assigns.dashboard.id}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  defp format_errors(error) do
    case error do
      %Ash.Changeset{errors: errors} ->
        errors
        |> Enum.map(&Exception.message/1)
        |> Enum.join(", ")

      %Ash.Error.Invalid{} = err ->
        Exception.message(err)

      other ->
        inspect(other)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="flex items-center space-x-3 mb-6">
        <.link navigate={~p"/dashboards/#{@dashboard.id}"} class="text-gray-400 hover:text-gray-600">
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
        </.link>
        <h1 class="text-2xl font-semibold text-gray-900"><%= @page_title %></h1>
      </div>

      <div class="bg-white shadow rounded-lg">
        <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6 p-6">
          <div>
            <label for="name" class="block text-sm font-medium text-gray-700">Widget Name</label>
            <input
              type="text"
              name="widget[name]"
              id="name"
              value={@form[:name].value || @widget.name}
              required
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
              placeholder="My Widget"
            />
          </div>

          <div>
            <label for="pipeline_id" class="block text-sm font-medium text-gray-700">Pipeline</label>
            <select
              name="widget[pipeline_id]"
              id="pipeline_id"
              required
              disabled={@action == :edit}
              class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm disabled:bg-gray-100"
            >
              <option value="">Select a pipeline...</option>
              <%= for pipeline <- @pipelines do %>
                <option value={pipeline.id} selected={(@form[:pipeline_id].value || @widget.pipeline_id) == pipeline.id}>
                  <%= pipeline.name %>
                </option>
              <% end %>
            </select>
            <%= if @action == :edit do %>
              <p class="mt-1 text-xs text-gray-500">Pipeline cannot be changed after widget creation</p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Widget Type</label>
            <div class="grid grid-cols-2 gap-4">
              <.type_card type={:table} selected={@selected_type} label="Table" description="Display data in rows and columns" />
              <.type_card type={:line_chart} selected={@selected_type} label="Line Chart" description="Time-series visualization" />
              <.type_card type={:stat_card} selected={@selected_type} label="Stat Card" description="Single metric display" />
              <.type_card type={:bar_chart} selected={@selected_type} label="Bar Chart" description="Categorical comparison" />
            </div>
          </div>

          <.type_config type={@selected_type} widget={@widget} form={@form} />

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Size</label>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label for="width" class="text-xs text-gray-500">Width (columns, 1-12)</label>
                <select
                  name="widget[position][w]"
                  id="width"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                >
                  <%= for w <- [3, 4, 6, 8, 12] do %>
                    <option value={w} selected={@widget.position["w"] == w}><%= w %> columns</option>
                  <% end %>
                </select>
              </div>
              <div>
                <label for="height" class="text-xs text-gray-500">Height (rows)</label>
                <select
                  name="widget[position][h]"
                  id="height"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                >
                  <%= for h <- [2, 3, 4, 6, 8] do %>
                    <option value={h} selected={@widget.position["h"] == h}><%= h %> rows</option>
                  <% end %>
                </select>
              </div>
            </div>
          </div>

          <div class="flex justify-between pt-4 border-t">
            <div>
              <%= if @action == :edit do %>
                <button
                  type="button"
                  phx-click="delete"
                  data-confirm="Are you sure you want to delete this widget?"
                  class="inline-flex items-center px-4 py-2 border border-red-300 text-sm font-medium rounded-md text-red-700 bg-white hover:bg-red-50"
                >
                  Delete Widget
                </button>
              <% end %>
            </div>
            <div class="flex space-x-3">
              <.link
                navigate={~p"/dashboards/#{@dashboard.id}"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
              >
                <%= if @action == :new, do: "Add Widget", else: "Save Changes" %>
              </button>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp type_card(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="select_type"
      phx-value-type={@type}
      class={"p-4 border rounded-lg text-left transition-colors #{if @selected == @type, do: "border-indigo-500 bg-indigo-50 ring-2 ring-indigo-500", else: "border-gray-200 hover:border-gray-400"}"}
    >
      <p class="font-medium text-gray-900"><%= @label %></p>
      <p class="text-xs text-gray-500 mt-1"><%= @description %></p>
    </button>
    """
  end

  defp type_config(%{type: :table} = assigns) do
    ~H"""
    <div class="space-y-4 p-4 bg-gray-50 rounded-lg">
      <h3 class="font-medium text-gray-900">Table Configuration</h3>
      <div>
        <label class="text-sm text-gray-700">Max Rows</label>
        <input
          type="number"
          name="widget[config][max_rows]"
          value={@widget.config["max_rows"] || 50}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          min="10"
          max="500"
        />
      </div>
      <p class="text-xs text-gray-500">
        Columns will be automatically detected from the pipeline data.
      </p>
    </div>
    """
  end

  defp type_config(%{type: :line_chart} = assigns) do
    ~H"""
    <div class="space-y-4 p-4 bg-gray-50 rounded-lg">
      <h3 class="font-medium text-gray-900">Line Chart Configuration</h3>
      <div>
        <label class="text-sm text-gray-700">X-Axis Field (time)</label>
        <input
          type="text"
          name="widget[config][x_field]"
          value={@widget.config["x_field"] || "timestamp"}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="timestamp"
        />
      </div>
      <div>
        <label class="text-sm text-gray-700">Y-Axis Fields (comma-separated)</label>
        <input
          type="text"
          name="widget[config][y_fields_raw]"
          value={get_y_fields_raw(@widget.config)}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="temperature, humidity"
        />
        <p class="text-xs text-gray-500 mt-1">Enter field names separated by commas</p>
      </div>
      <div>
        <label class="text-sm text-gray-700">Max Data Points</label>
        <input
          type="number"
          name="widget[config][max_points]"
          value={@widget.config["max_points"] || 100}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          min="10"
          max="1000"
        />
      </div>
    </div>
    """
  end

  defp type_config(%{type: :stat_card} = assigns) do
    ~H"""
    <div class="space-y-4 p-4 bg-gray-50 rounded-lg">
      <h3 class="font-medium text-gray-900">Stat Card Configuration</h3>
      <div>
        <label class="text-sm text-gray-700">Field</label>
        <input
          type="text"
          name="widget[config][field]"
          value={@widget.config["field"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="temperature"
          required
        />
      </div>
      <div>
        <label class="text-sm text-gray-700">Label</label>
        <input
          type="text"
          name="widget[config][label]"
          value={@widget.config["label"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="Current Temperature"
        />
      </div>
      <div>
        <label class="text-sm text-gray-700">Aggregation</label>
        <select
          name="widget[config][aggregation]"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
        >
          <%= for agg <- ["latest", "avg", "min", "max", "sum", "count"] do %>
            <option value={agg} selected={@widget.config["aggregation"] == agg}>
              <%= String.capitalize(agg) %>
            </option>
          <% end %>
        </select>
      </div>
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="text-sm text-gray-700">Decimal Places</label>
          <input
            type="number"
            name="widget[config][decimals]"
            value={@widget.config["decimals"] || 0}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            min="0"
            max="6"
          />
        </div>
        <div>
          <label class="text-sm text-gray-700">Suffix</label>
          <input
            type="text"
            name="widget[config][suffix]"
            value={@widget.config["suffix"]}
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
            placeholder="°F"
          />
        </div>
      </div>
    </div>
    """
  end

  defp type_config(%{type: :bar_chart} = assigns) do
    ~H"""
    <div class="space-y-4 p-4 bg-gray-50 rounded-lg">
      <h3 class="font-medium text-gray-900">Bar Chart Configuration</h3>
      <div>
        <label class="text-sm text-gray-700">Category Field (X-Axis)</label>
        <input
          type="text"
          name="widget[config][x_field]"
          value={@widget.config["x_field"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="category"
        />
      </div>
      <div>
        <label class="text-sm text-gray-700">Value Field (Y-Axis)</label>
        <input
          type="text"
          name="widget[config][y_field]"
          value={@widget.config["y_field"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          placeholder="value"
        />
      </div>
      <div>
        <label class="text-sm text-gray-700">Max Bars</label>
        <input
          type="number"
          name="widget[config][max_points]"
          value={@widget.config["max_points"] || 50}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
          min="5"
          max="100"
        />
      </div>
    </div>
    """
  end

  defp type_config(assigns) do
    ~H"""
    <div class="p-4 bg-gray-50 rounded-lg">
      <p class="text-gray-500 text-sm">Select a widget type to configure</p>
    </div>
    """
  end

  # Helper functions

  defp load_dashboard(id, actor) do
    Dashboard
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: actor)
  end

  defp load_widget(id, actor) do
    Widget
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!(actor: actor)
  end

  defp load_pipelines(org, actor) do
    if org do
      Pipeline
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(organization_id == ^org.id)
      |> Ash.read!(actor: actor)
    else
      []
    end
  end

  defp build_form(widget) do
    to_form(%{
      "name" => widget.name,
      "pipeline_id" => widget.pipeline_id
    })
  end

  defp get_y_fields_raw(config) do
    case config["y_fields"] do
      nil -> ""
      fields when is_list(fields) -> Enum.map_join(fields, ", ", & &1["field"])
      _ -> ""
    end
  end

  defp build_config(:table, params) do
    %{
      "max_rows" => parse_int(params["config"]["max_rows"], 50),
      "columns" => []
    }
  end

  defp build_config(:line_chart, params) do
    y_fields_raw = params["config"]["y_fields_raw"] || ""

    y_fields =
      y_fields_raw
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.with_index()
      |> Enum.map(fn {field, idx} ->
        colors = ["#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6"]
        %{"field" => field, "label" => field, "color" => Enum.at(colors, rem(idx, 5))}
      end)

    %{
      "x_field" => params["config"]["x_field"] || "timestamp",
      "y_fields" => y_fields,
      "max_points" => parse_int(params["config"]["max_points"], 100)
    }
  end

  defp build_config(:stat_card, params) do
    %{
      "field" => params["config"]["field"],
      "label" => params["config"]["label"],
      "aggregation" => params["config"]["aggregation"] || "latest",
      "decimals" => parse_int(params["config"]["decimals"], 0),
      "suffix" => params["config"]["suffix"]
    }
  end

  defp build_config(:bar_chart, params) do
    %{
      "x_field" => params["config"]["x_field"],
      "y_field" => params["config"]["y_field"],
      "max_points" => parse_int(params["config"]["max_points"], 50)
    }
  end

  defp build_config(_type, _params), do: %{}

  defp build_position(params) do
    %{
      "x" => 0,
      "y" => 0,
      "w" => parse_int(params["position"]["w"], 6),
      "h" => parse_int(params["position"]["h"], 4)
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end
  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_, default), do: default
end
