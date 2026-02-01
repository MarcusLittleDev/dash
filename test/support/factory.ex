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
  alias Dash.Pipelines.{Pipeline, DataMapping, ExecutionLog}

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

  defp unique_pipeline_name do
    "Pipeline #{System.unique_integer([:positive])}"
  end

  @doc """
  Creates a pipeline.
  Requires :organization option.
  """
  def create_pipeline!(opts \\ []) do
    {org, _owner} =
      Keyword.get_lazy(opts, :organization, fn ->
        create_organization_with_owner!()
      end)

    name = Keyword.get(opts, :name, unique_pipeline_name())
    type = Keyword.get(opts, :type, :polling)
    status = Keyword.get(opts, :status, :inactive)

    # Only set interval_seconds for polling type
    interval_seconds =
      if type == :polling do
        Keyword.get(opts, :interval_seconds, 300)
      else
        Keyword.get(opts, :interval_seconds)
      end

    source_config =
      Keyword.get(opts, :source_config, %{
        "url" => "https://jsonplaceholder.typicode.com/posts",
        "method" => "GET"
      })

    attrs = %{
      name: name,
      description: Keyword.get(opts, :description),
      type: type,
      status: status,
      source_type: Keyword.get(opts, :source_type, "http_api"),
      source_config: source_config,
      sink_configs: Keyword.get(opts, :sink_configs, []),
      persist_data: Keyword.get(opts, :persist_data, true),
      retention_days: Keyword.get(opts, :retention_days),
      organization_id: org.id
    }

    # Only include interval_seconds if not nil
    attrs =
      if is_nil(interval_seconds) do
        attrs
      else
        Map.put(attrs, :interval_seconds, interval_seconds)
      end

    Pipeline
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Creates data mappings for a pipeline.
  Requires :pipeline option.
  """
  def create_data_mapping!(opts) do
    pipeline = Keyword.fetch!(opts, :pipeline)

    mappings =
      Keyword.get(opts, :mappings, [
        %{
          source_field: "title",
          target_field: "title",
          required: true,
          transformation_type: :direct
        },
        %{
          source_field: "body",
          target_field: "content",
          required: false,
          transformation_type: :direct
        }
      ])

    # Create multiple DataMapping records, one for each mapping
    Enum.map(mappings, fn mapping ->
      DataMapping
      |> Ash.Changeset.for_create(:create, %{
        pipeline_id: pipeline.id,
        source_field: mapping[:source_field] || mapping["source_field"],
        target_field: mapping[:target_field] || mapping["target_field"],
        required: mapping[:required] || mapping["required"] || false,
        transformation_type: mapping[:transformation_type] || mapping["transformation_type"] || :direct
      })
      |> Ash.create!(authorize?: false)
    end)
  end

  @doc """
  Creates an execution log for a pipeline.
  Requires :pipeline option.
  """
  def create_execution_log!(opts) do
    pipeline = Keyword.fetch!(opts, :pipeline)

    ExecutionLog
    |> Ash.Changeset.for_create(:create, %{
      pipeline_id: pipeline.id,
      started_at: Keyword.get(opts, :started_at, DateTime.utc_now()),
      completed_at: Keyword.get(opts, :completed_at, DateTime.utc_now()),
      status: Keyword.get(opts, :status, :success),
      records_fetched: Keyword.get(opts, :records_fetched, 10),
      records_stored: Keyword.get(opts, :records_stored, 10),
      duration_ms: Keyword.get(opts, :duration_ms, 250),
      error_type: Keyword.get(opts, :error_type),
      error_message: Keyword.get(opts, :error_message),
      error_details: Keyword.get(opts, :error_details),
      source_response_time_ms: Keyword.get(opts, :source_response_time_ms, 150),
      metadata: Keyword.get(opts, :metadata, %{})
    })
    |> Ash.create!(authorize?: false)
  end
end
