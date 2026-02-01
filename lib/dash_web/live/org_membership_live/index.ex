defmodule DashWeb.OrgMembershipLive.Index do
  use DashWeb, :live_view
  use DashWeb.OrgContextLive

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Org memberships
      <:actions>
        <.button variant="primary" navigate={~p"/org_memberships/new"}>
          <.icon name="hero-plus" /> New Org membership
        </.button>
      </:actions>
    </.header>

    <.table
      id="org_memberships"
      rows={@streams.org_memberships}
      row_click={fn {_id, org_membership} -> JS.navigate(~p"/org_memberships/#{org_membership}") end}
    >
      <:col :let={{_id, org_membership}} label="Id">{org_membership.id}</:col>

      <:col :let={{_id, org_membership}} label="Role">{org_membership.role}</:col>

      <:action :let={{_id, org_membership}}>
        <div class="sr-only">
          <.link navigate={~p"/org_memberships/#{org_membership}"}>Show</.link>
        </div>

        <.link navigate={~p"/org_memberships/#{org_membership}/edit"}>Edit</.link>
      </:action>

      <:action :let={{id, org_membership}}>
        <.link
          phx-click={JS.push("delete", value: %{id: org_membership.id}) |> hide("##{id}")}
          data-confirm="Are you sure?"
        >
          Delete
        </.link>
      </:action>
    </.table>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Org memberships")
     |> stream(
       :org_memberships,
       Ash.read!(Dash.Accounts.OrgMembership, actor: socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    org_membership = Ash.get!(Dash.Accounts.OrgMembership, id)
    Ash.destroy!(org_membership)

    {:noreply, stream_delete(socket, :org_memberships, org_membership)}
  end
end
