defmodule DashWeb.Admin.OrganizationLive.Index do
  use DashWeb, :live_view

  alias Dash.Accounts.Organization

  @impl true
  def mount(_params, _session, socket) do
    # Employees/superadmins can view all organizations via policy bypass
    organizations = Ash.read!(Organization, actor: socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:page_title, "Organizations")
     |> stream(:organizations, organizations)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Organizations
        <:subtitle>Manage customer organizations</:subtitle>
        <:actions>
          <.link navigate={~p"/admin/organizations/new"}>
            <.button variant="primary">
              <.icon name="hero-plus" class="w-4 h-4 mr-1" /> New Organization
            </.button>
          </.link>
        </:actions>
      </.header>

      <.table
        id="organizations"
        rows={@streams.organizations}
        row_click={fn {_id, org} -> JS.navigate(~p"/admin/organizations/#{org}") end}
      >
        <:col :let={{_id, org}} label="Name">{org.name}</:col>
        <:col :let={{_id, org}} label="Slug">{org.slug}</:col>
        <:col :let={{_id, org}} label="Status">
          <span class={[
            "badge badge-sm",
            org.active && "badge-success",
            !org.active && "badge-error"
          ]}>
            {if org.active, do: "Active", else: "Inactive"}
          </span>
        </:col>
        <:col :let={{_id, org}} label="Created">
          {Calendar.strftime(org.inserted_at, "%Y-%m-%d")}
        </:col>
        <:action :let={{_id, org}}>
          <.link navigate={~p"/admin/organizations/#{org}"} class="btn btn-ghost btn-xs">
            View
          </.link>
          <.link navigate={~p"/admin/organizations/#{org}/edit"} class="btn btn-ghost btn-xs">
            Edit
          </.link>
        </:action>
      </.table>
    </div>
    """
  end
end
