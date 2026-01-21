defmodule Dash.Accounts.TeamMember do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("team_members")
    repo(Dash.Repo)

    custom_indexes do
      index([:team_id],
        unique: true,
        where: "role = 'owner'",
        name: "team_members_one_owner_per_team"
      )
    end
  end

  attributes do
    attribute :role, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:owner, :manager, :member])
      default(:member)
    end
  end

  relationships do
    belongs_to :team, Dash.Accounts.Team do
      description("foreign key to Team")
      allow_nil?(false)
    end

    belongs_to :user, Dash.Accounts.User do
      description("foreign key to User")
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:role])
      argument(:team_id, :uuid, allow_nil?: false)
      argument(:user_id, :uuid, allow_nil?: false)

      change(manage_relationship(:team_id, :team, type: :append))
      change(manage_relationship(:user_id, :user, type: :append))
    end

    update :update_role do
      accept([:role])
    end
  end

  identities do
    identity(:unique_team_user, [:team_id, :user_id])
  end

  policies do
    # Anyone in the organization can read team members
    policy action_type(:read) do
      authorize_if(expr(exists(team.organization.org_memberships, user_id == ^actor(:id))))
    end

    # Team owner can add managers and members (not other owners)
    policy action_type(:create) do
      authorize_if(
        expr(
          exists(team.team_members, user_id == ^actor(:id) and role == :owner) and
            role != :owner
        )
      )
    end

    # Team manager can add members only (not managers or owners)
    policy action_type(:create) do
      authorize_if(
        expr(
          exists(team.team_members, user_id == ^actor(:id) and role == :manager) and
            role == :member
        )
      )
    end

    # Team owner can remove anyone except themselves
    policy action_type(:destroy) do
      authorize_if(
        expr(
          exists(team.team_members, user_id == ^actor(:id) and role == :owner) and
            user_id != ^actor(:id)
        )
      )
    end

    # Team manager can remove members only
    policy action_type(:destroy) do
      authorize_if(
        expr(
          exists(team.team_members, user_id == ^actor(:id) and role == :manager) and
            role == :member
        )
      )
    end

    # Only owner can update roles
    policy action_type(:update) do
      authorize_if(expr(exists(team.team_members, user_id == ^actor(:id) and role == :owner)))
    end
  end
end
