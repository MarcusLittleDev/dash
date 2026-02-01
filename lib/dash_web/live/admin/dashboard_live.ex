defmodule DashWeb.Admin.DashboardLive do
  use DashWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Admin Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Admin Dashboard
        <:subtitle>Manage organizations, users, and system settings</:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <.link
          navigate={~p"/admin/organizations"}
          class="card bg-base-200 hover:bg-base-300 transition-colors"
        >
          <div class="card-body">
            <h2 class="card-title">
              <.icon name="hero-building-office-2" class="w-6 h-6" /> Organizations
            </h2>
            <p>Create and manage customer organizations</p>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
