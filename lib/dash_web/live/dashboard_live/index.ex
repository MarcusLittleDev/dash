defmodule DashWeb.DashboardLive.Index do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Dashboards.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dashboards")
      |> load_dashboards()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Dashboards</h1>
          <p class="mt-2 text-sm text-gray-700">
            Create and manage dashboards to visualize your pipeline data
          </p>
        </div>
        <.link
          navigate={~p"/dashboards/new"}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
        >
          Create Dashboard
        </.link>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if @dashboards == [] do %>
          <div class="col-span-full">
            <div class="text-center py-12 bg-white rounded-lg border-2 border-dashed border-gray-300">
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
              <h3 class="mt-2 text-sm font-medium text-gray-900">No dashboards</h3>
              <p class="mt-1 text-sm text-gray-500">
                Get started by creating your first dashboard
              </p>
              <div class="mt-6">
                <.link
                  navigate={~p"/dashboards/new"}
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                >
                  Create Dashboard
                </.link>
              </div>
            </div>
          </div>
        <% else %>
          <%= for dashboard <- @dashboards do %>
            <.link
              navigate={~p"/dashboards/#{dashboard.id}"}
              class="block bg-white rounded-lg border border-gray-200 hover:border-indigo-500 hover:shadow-md transition-all duration-200"
            >
              <div class="p-6">
                <div class="flex items-center justify-between">
                  <h2 class="text-lg font-semibold text-gray-900 truncate">
                    <%= dashboard.name %>
                  </h2>
                  <%= if dashboard.is_default do %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                      Default
                    </span>
                  <% end %>
                </div>
                <p class="mt-2 text-sm text-gray-500 line-clamp-2">
                  <%= dashboard.description || "No description" %>
                </p>
                <div class="mt-4 flex items-center justify-between text-xs text-gray-400">
                  <span>
                    <%= widget_count(dashboard) %> widget<%= if widget_count(dashboard) != 1, do: "s" %>
                  </span>
                  <span>
                    Created <%= format_date(dashboard.inserted_at) %>
                  </span>
                </div>
              </div>
            </.link>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp load_dashboards(socket) do
    org = socket.assigns[:current_org]

    dashboards =
      if org do
        Dashboard
        |> Ash.Query.for_read(:for_organization, %{organization_id: org.id})
        |> Ash.Query.load(:widgets)
        |> Ash.read!(actor: socket.assigns.current_user)
      else
        []
      end

    assign(socket, :dashboards, dashboards)
  rescue
    error ->
      require Logger
      Logger.error("Failed to load dashboards: #{inspect(error)}")
      assign(socket, :dashboards, [])
  end

  defp widget_count(dashboard) do
    if Ash.Resource.loaded?(dashboard, :widgets) do
      length(dashboard.widgets)
    else
      0
    end
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
