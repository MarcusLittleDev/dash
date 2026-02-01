defmodule DashWeb.PipelineLive.Index do
  use DashWeb, :live_view

  require Ash.Query
  alias Dash.Pipelines.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Pipelines")
      |> load_pipelines()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-semibold text-gray-900">Pipelines</h1>
          <p class="mt-2 text-sm text-gray-700">
            Manage data ingestion pipelines for your organization
          </p>
        </div>
        <.link
          navigate={~p"/pipelines/new"}
          class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700"
        >
          Create Pipeline
        </.link>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-md">
        <ul role="list" class="divide-y divide-gray-200">
          <%= if @pipelines == [] do %>
            <li class="px-6 py-12">
              <div class="text-center">
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
                    d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
                  />
                </svg>
                <h3 class="mt-2 text-sm font-medium text-gray-900">No pipelines</h3>
                <p class="mt-1 text-sm text-gray-500">
                  Get started by creating a new data pipeline
                </p>
                <div class="mt-6">
                  <.link
                    navigate={~p"/pipelines/new"}
                    class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                  >
                    Create Pipeline
                  </.link>
                </div>
              </div>
            </li>
          <% else %>
            <%= for pipeline <- @pipelines do %>
              <li>
                <.link navigate={~p"/pipelines/#{pipeline.id}"} class="block hover:bg-gray-50 transition duration-150">
                  <div class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center space-x-3">
                          <h3 class="text-sm font-medium text-gray-900 truncate">
                            <%= pipeline.name %>
                          </h3>
                          <span class={[
                            "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                            status_color(pipeline.status)
                          ]}>
                            <%= pipeline.status %>
                          </span>
                          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                            <%= pipeline.type %>
                          </span>
                        </div>
                        <%= if pipeline.description do %>
                          <p class="mt-1 text-sm text-gray-500 line-clamp-1">
                            <%= pipeline.description %>
                          </p>
                        <% end %>
                      </div>
                      <div class="ml-4 flex items-center space-x-4">
                        <%= if pipeline.type == :polling && pipeline.interval_seconds do %>
                          <div class="text-sm text-gray-500">
                            Every <%= format_interval(pipeline.interval_seconds) %>
                          </div>
                        <% end %>
                        <svg
                          class="h-5 w-5 text-gray-400"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M9 5l7 7-7 7"
                          />
                        </svg>
                      </div>
                    </div>
                  </div>
                </.link>
              </li>
            <% end %>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  defp load_pipelines(socket) do
    # Get current organization from socket assigns
    org = socket.assigns[:current_org]

    pipelines =
      if org do
        Pipeline
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(organization_id == ^org.id)
        |> Ash.read!(actor: socket.assigns.current_user)
      else
        []
      end

    assign(socket, :pipelines, pipelines)
  rescue
    error ->
      require Logger
      Logger.error("Failed to load pipelines: #{inspect(error)}")
      assign(socket, :pipelines, [])
  end

  defp status_color(:active), do: "bg-green-100 text-green-800"
  defp status_color(:inactive), do: "bg-gray-100 text-gray-800"
  defp status_color(:error), do: "bg-red-100 text-red-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  defp format_interval(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_interval(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m"
  defp format_interval(seconds), do: "#{div(seconds, 3600)}h"
end
