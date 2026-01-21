defmodule DashWeb.OrgMembershipLive.Show do
  use DashWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Org membership {@org_membership.id}
        <:subtitle>This is a org_membership record from your database.</:subtitle>

        <:actions>
          <.button navigate={~p"/org_memberships"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={~p"/org_memberships/#{@org_membership}/edit?return_to=show"}
          >
            <.icon name="hero-pencil-square" /> Edit Org membership
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Id">{@org_membership.id}</:item>

        <:item title="Role">{@org_membership.role}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Org membership")
     |> assign(:org_membership, Ash.get!(Dash.Accounts.OrgMembership, id))}
  end
end
