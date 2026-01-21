defmodule Dash.Accounts.Team do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshSlug],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("teams")
    repo(Dash.Repo)
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
      writable?(false)
    end

    attribute :description, :string do
      public?(true)
    end
  end

  relationships do
    belongs_to :organization, Dash.Accounts.Organization do
      allow_nil?(false)
    end

    has_many :team_members, Dash.Accounts.TeamMember
  end

  validations do
    validate(fn changeset, _context ->
      with {:ok, name} <- Ash.Changeset.fetch_argument_or_change(changeset, :name),
           {:ok, org_id} <-
             Ash.Changeset.fetch_argument_or_change(changeset, :organization_id) do
        # Generate the slug that would be created
        potential_slug = Slug.slugify(name)

        # Check if a team with this slug already exists in the org
        existing_team =
          Ash.read!(Dash.Accounts.Team,
            filter: [organization_id: org_id, slug: potential_slug]
          )
          |> List.first()

        if existing_team && existing_team.id != Ash.Changeset.get_attribute(changeset, :id) do
          {:error,
           field: :name, message: "A team with a similar name already exists in this organization"}
        else
          :ok
        end
      else
        _ -> :ok
      end
    end)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :description])
      argument(:organization_id, :uuid, allow_nil?: false)

      change(manage_relationship(:organization_id, :organization, type: :append))
      change(slugify(:name, into: :slug))

      # Auto-add creator as owner
      change(fn changeset, context ->
        actor_id = context.actor.id

        # Create TeamMember record for creator as owner
        Ash.Changeset.after_action(changeset, fn _changeset, team ->
          Ash.create!(Dash.Accounts.TeamMember, %{
            team_id: team.id,
            user_id: actor_id,
            role: :owner
          })

          {:ok, team}
        end)
      end)
    end

    update :update do
      accept([:name, :description])
      change(slugify(:name, into: :slug))
    end

    action :transfer_ownership, :struct do
      description("Transfer team ownership to a new user")
      argument(:new_owner_id, :uuid, allow_nil?: false)

      run(fn input, context ->
        team = input.resource
        new_owner_id = input.arguments.new_owner_id

        # Find current owner membership
        current_owner =
          Ash.read!(Dash.Accounts.TeamMember,
            filter: [team_id: team.id, role: :owner]
          )
          |> List.first()

        # Check if new owner is already a member
        existing_membership =
          Ash.read!(Dash.Accounts.TeamMember,
            filter: [team_id: team.id, user_id: new_owner_id]
          )
          |> List.first()

        # Delete existing membership if it exists
        if existing_membership do
          Ash.destroy!(existing_membership)
        end

        # Delete current owner
        if current_owner do
          Ash.destroy!(current_owner)
        end

        # Create new owner
        new_owner_membership =
          Ash.create!(Dash.Accounts.TeamMember, %{
            team_id: team.id,
            user_id: new_owner_id,
            role: :owner
          })

        {:ok, new_owner_membership}
      end)
    end
  end

  identities do
    # Keep slug uniqueness as the primary constraint (database level)
    identity(:unique_slug_per_org, [:organization_id, :slug])
  end

  policies do
    # Org members can read teams in their org
    policy action_type(:read) do
      authorize_if(expr(exists(organization.org_memberships, user_id == ^actor(:id))))
    end

    # Org members can create teams
    policy action_type(:create) do
      authorize_if(expr(exists(parent(organization).org_memberships, user_id == ^actor(:id))))
    end

    # Team owner can update/destroy team
    policy action_type([:update, :destroy]) do
      authorize_if(expr(exists(team_members, user_id == ^actor(:id) and role == :owner)))
    end

    # Org owners and admins can update/destroy any team in their org
    policy action_type([:update, :destroy]) do
      authorize_if(
        expr(
          exists(
            organization.org_memberships,
            user_id == ^actor(:id) and role in [:owner, :admin]
          )
        )
      )
    end

    # Team owner can transfer ownership
    policy action(:transfer_ownership) do
      authorize_if(expr(exists(team_members, user_id == ^actor(:id) and role == :owner)))
    end

    # Org owners and admins can transfer team ownership
    policy action(:transfer_ownership) do
      authorize_if(
        expr(
          exists(
            organization.org_memberships,
            user_id == ^actor(:id) and role in [:owner, :admin]
          )
        )
      )
    end
  end
end
