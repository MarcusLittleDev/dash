defmodule DashWeb.TeamLive.Show do
  use DashWeb, :live_view
  use DashWeb.OrgContextLive

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Team {@team.id}
      <:subtitle>This is a team record from your database.</:subtitle>
    </.header>

    <.list>
      <:item title="Id">{@team.id}</:item>

      <:item title="Name">{@team.name}</:item>

      <:item title="Slug">{@team.slug}</:item>

      <:item title="Description">{@team.description}</:item>
    </.list>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Team")
     |> assign(:team, Ash.get!(Dash.Accounts.Team, id))}
  end
end
