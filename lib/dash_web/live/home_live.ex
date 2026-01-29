defmodule DashWeb.HomeLive do
  use DashWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Home")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-[60vh]">
      <div class="text-center space-y-4">
        <h1 class="text-4xl font-bold text-primary">Welcome to Dash</h1>
        <p class="text-lg text-base-content/70">
          Your data pipeline and visualization platform
        </p>
      </div>
    </div>
    """
  end
end
