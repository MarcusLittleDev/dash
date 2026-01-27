defmodule DashWeb.Hooks.LiveOrgContext do
  @moduledoc "Loads current user's organizations and teams into socket assigns"
  import Phoenix.Component
  require Ash.Query

  def on_mount(:load_context, _params, _session, socket) do
    socket =
      if socket.assigns[:current_user] do
        load_user_context(socket)
      else
        socket
      end

    {:cont, socket}
  end

  defp load_user_context(socket) do
    user = socket.assigns.current_user

    # Load user's organizations with memberships
    organizations = load_user_organizations(user)

    # Get current org from session or default to first
    current_org = get_current_org(socket, organizations)

    # Load teams for current org
    teams = if current_org, do: load_org_teams(current_org, user), else: []

    socket
    |> assign(:organizations, organizations)
    |> assign(:current_org, current_org)
    |> assign(:teams, teams)
    |> assign(:current_team, nil)
  end

  # Load all organizations the user is a member of.
  # Returns organizations with the user's role preloaded.
  defp load_user_organizations(user) do
    Dash.Accounts.OrgMembership
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.Query.load(:organization)
    |> Ash.read!(actor: user)
    |> Enum.map(fn membership ->
      Map.put(membership.organization, :user_role, membership.role)
    end)
  end

  # Get current org from socket assigns or default to first org.
  defp get_current_org(socket, organizations) do
    cond do
      # If already set in socket, keep it
      socket.assigns[:current_org] ->
        socket.assigns.current_org

      # Default to first org
      organizations != [] ->
        List.first(organizations)

      # No orgs
      true ->
        nil
    end
  end

  # Load all teams in the organization that the user can see.
  defp load_org_teams(organization, user) do
    Dash.Accounts.Team
    |> Ash.Query.filter(organization_id == ^organization.id)
    |> Ash.Query.load(:team_members)
    |> Ash.read!(actor: user)
    |> Enum.map(fn team ->
      # Find user's membership to get their role
      user_membership = Enum.find(team.team_members, &(&1.user_id == user.id))
      role = if user_membership, do: user_membership.role, else: nil
      Map.put(team, :user_role, role)
    end)
  end

  @doc """
  Reload teams when org changes. Call from handle_event.
  """
  def reload_teams(socket) do
    user = socket.assigns.current_user
    current_org = socket.assigns.current_org

    teams = if current_org, do: load_org_teams(current_org, user), else: []

    assign(socket, :teams, teams)
  end
end
