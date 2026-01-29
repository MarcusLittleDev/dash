defmodule DashWeb.TeamMemberLive.Index do
  use DashWeb, :live_view
  use DashWeb.OrgContextLive

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Listing Team members
      <:actions>
        <.button variant="primary" navigate={~p"/team_members/new"}>
          <.icon name="hero-plus" /> New Team member
        </.button>
      </:actions>
    </.header>

    <.table
      id="team_members"
      rows={@streams.team_members}
      row_click={fn {_id, team_member} -> JS.navigate(~p"/team_members/#{team_member}") end}
    >
      <:col :let={{_id, team_member}} label="Id">{team_member.id}</:col>

      <:col :let={{_id, team_member}} label="Role">{team_member.role}</:col>

      <:action :let={{_id, team_member}}>
        <div class="sr-only">
          <.link navigate={~p"/team_members/#{team_member}"}>Show</.link>
        </div>
      </:action>

      <:action :let={{id, team_member}}>
        <.link
          phx-click={JS.push("delete", value: %{id: team_member.id}) |> hide("##{id}")}
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
     |> assign(:page_title, "Listing Team members")
     |> stream(
       :team_members,
       Ash.read!(Dash.Accounts.TeamMember, actor: socket.assigns.current_user)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    team_member = Ash.get!(Dash.Accounts.TeamMember, id)
    Ash.destroy!(team_member)

    {:noreply, stream_delete(socket, :team_members, team_member)}
  end
end
