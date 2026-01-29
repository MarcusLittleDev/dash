defmodule Dash.Factory do
  @moduledoc """
  Factory module for creating test data.

  Uses Ash's built-in functionality to create resources with proper
  validations and relationships.

  ## Usage

      # Create a user
      user = Dash.Factory.create_user!()

      # Create with custom attributes
      user = Dash.Factory.create_user!(email: "custom@example.com")

      # Create an organization with an owner
      {org, owner} = Dash.Factory.create_organization_with_owner!()

      # Create a team within an organization
      team = Dash.Factory.create_team!(organization: org, actor: owner)
  """

  alias Dash.Accounts.{User, Organization, OrgMembership, Team, TeamMember}

  @doc """
  Creates a user with password authentication.
  Returns the user struct.
  """
  def create_user!(opts \\ []) do
    email = Keyword.get(opts, :email, unique_email())
    password = Keyword.get(opts, :password, "password123")

    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: password,
      password_confirmation: password
    })
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Builds user attributes without creating.
  Useful for testing validation errors.
  """
  def user_attrs(opts \\ []) do
    %{
      email: Keyword.get(opts, :email, unique_email()),
      password: Keyword.get(opts, :password, "password123"),
      password_confirmation: Keyword.get(opts, :password, "password123")
    }
  end

  @doc """
  Creates an organization. Note: This bypasses the normal policy that
  forbids organization creation (since it's admin-only).

  Returns the organization struct.
  """
  def create_organization!(opts \\ []) do
    name = Keyword.get(opts, :name, unique_org_name())

    Organization
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates an organization with an owner membership.
  Returns {organization, owner_user}.
  """
  def create_organization_with_owner!(opts \\ []) do
    owner = Keyword.get_lazy(opts, :owner, fn -> create_user!() end)
    org = create_organization!(Keyword.take(opts, [:name]))

    # Create owner membership
    create_org_membership!(organization: org, user: owner, role: :owner)

    {org, owner}
  end

  @doc """
  Creates an org membership.
  Requires :organization and :user options.
  """
  def create_org_membership!(opts) do
    org = Keyword.fetch!(opts, :organization)
    user = Keyword.fetch!(opts, :user)
    role = Keyword.get(opts, :role, :member)

    OrgMembership
    |> Ash.Changeset.for_create(:create, %{role: role})
    |> Ash.Changeset.manage_relationship(:organization, org, type: :append)
    |> Ash.Changeset.manage_relationship(:user, user, type: :append)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a team within an organization.
  Requires :organization and :actor options.
  The actor must be a member of the organization.
  """
  def create_team!(opts) do
    org = Keyword.fetch!(opts, :organization)
    actor = Keyword.fetch!(opts, :actor)
    name = Keyword.get(opts, :name, unique_team_name())
    description = Keyword.get(opts, :description)

    Team
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: name,
        description: description,
        organization_id: org.id
      },
      actor: actor
    )
    |> Ash.create!()
  end

  @doc """
  Creates a team member.
  Requires :team, :user options.
  """
  def create_team_member!(opts) do
    team = Keyword.fetch!(opts, :team)
    user = Keyword.fetch!(opts, :user)
    role = Keyword.get(opts, :role, :member)

    TeamMember
    |> Ash.Changeset.for_create(:create, %{
      team_id: team.id,
      user_id: user.id,
      role: role
    })
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates a complete test setup with:
  - An organization
  - An owner user
  - A team owned by the owner
  - Optionally additional members

  Returns a map with all created entities.
  """
  def create_full_setup!(opts \\ []) do
    {org, owner} = create_organization_with_owner!(Keyword.take(opts, [:name]))

    team =
      create_team!(
        organization: org,
        actor: owner,
        name: Keyword.get(opts, :team_name, unique_team_name())
      )

    # Create additional members if requested
    member_count = Keyword.get(opts, :member_count, 0)

    members =
      for _ <- 1..member_count do
        user = create_user!()
        create_org_membership!(organization: org, user: user, role: :member)
        create_team_member!(team: team, user: user, role: :member)
        user
      end

    %{
      organization: org,
      owner: owner,
      team: team,
      members: members
    }
  end

  # Private helpers for unique values

  defp unique_email do
    "user_#{System.unique_integer([:positive])}@example.com"
  end

  defp unique_org_name do
    "Organization #{System.unique_integer([:positive])}"
  end

  defp unique_team_name do
    "Team #{System.unique_integer([:positive])}"
  end
end
