defmodule DashWeb.TeamMemberLive.Show do
  use DashWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Team member {@team_member.id}
        <:subtitle>This is a team_member record from your database.</:subtitle>
      </.header>

      <.list>
        <:item title="Id">{@team_member.id}</:item>

        <:item title="Role">{@team_member.role}</:item>
      </.list>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Team member")
     |> assign(:team_member, Ash.get!(Dash.Accounts.TeamMember, id))}
  end
end
