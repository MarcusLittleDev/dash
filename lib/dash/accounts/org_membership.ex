defmodule Dash.Accounts.OrgMembership do
  @moduledoc """
  Org Membership resource. Junction Object between Organization and User
  """
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("org_memberships")
    repo(Dash.Repo)

    custom_indexes do
      index([:organization_id],
        unique: true,
        where: "role = 'owner'",
        name: "org_memberships_one_owner_per_org"
      )
    end
  end

  attributes do
    attribute :role, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:owner, :admin, :member])
      default(:member)
    end
  end

  relationships do
    belongs_to :organization, Dash.Accounts.Organization do
      description("foreign key to Organization")
      source_attribute(:organization_id)
      allow_nil?(false)
    end

    belongs_to :user, Dash.Accounts.User do
      description("foreign key to User")
      source_attribute(:user_id)
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :destroy, create: :*, update: :*])
  end

  policies do
    # Org owners can manage ALL memberships
    policy action_type([:create, :update, :destroy]) do
      authorize_if(
        expr(
          exists(
            organization.org_memberships,
            user_id == ^actor(:id) and role == :owner
          )
        )
      )
    end

    # Org admins can manage memberships EXCEPT owner memberships
    policy action_type([:create, :update, :destroy]) do
      authorize_if(
        expr(
          exists(
            organization.org_memberships,
            user_id == ^actor(:id) and role == :admin
          ) and role != :owner
        )
      )
    end

    # Org owners and admins can read all memberships
    policy action_type(:read) do
      authorize_if(
        expr(
          exists(
            organization.org_memberships,
            user_id == ^actor(:id) and role in [:owner, :admin]
          )
        )
      )
    end

    # Users can read their own membership
    policy action_type(:read) do
      authorize_if(expr(user_id == ^actor(:id)))
    end
  end

  identities do
    identity(:unique_user_per_org, [:user_id, :organization_id])
  end
end
