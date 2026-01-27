defmodule DashWeb.TeamLive.Index do
  use DashWeb, :live_view
  use DashWeb.OrgContextLive

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Teams
      <:actions>
        <.button variant="primary" navigate={~p"/teams/new"}>
          <.icon name="hero-plus" /> New Team
        </.button>
      </:actions>
    </.header>

    <.table
      id="teams"
      rows={@streams.teams}
      row_click={fn {_id, team} -> JS.navigate(~p"/teams/#{team}") end}
    >
      <:col :let={{_id, team}} label="Id">{team.id}</:col>

      <:col :let={{_id, team}} label="Name">{team.name}</:col>

      <:col :let={{_id, team}} label="Slug">{team.slug}</:col>

      <:col :let={{_id, team}} label="Description">{team.description}</:col>

      <:action :let={{_id, team}}>
        <div class="sr-only">
          <.link navigate={~p"/teams/#{team}"}>Show</.link>
        </div>
      </:action>

      <:action :let={{id, team}}>
        <.link
          phx-click={JS.push("delete", value: %{id: team.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Listing Teams")
     |> stream(:teams, Ash.read!(Dash.Accounts.Team))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    team = Ash.get!(Dash.Accounts.Team, id)
    Ash.destroy!(team)

    {:noreply, stream_delete(socket, :teams, team)}
  end
end
