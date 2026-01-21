defmodule Dash.Accounts.Organization do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshSlug],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("organizations")
    repo(Dash.Repo)
  end

  attributes do
    attribute(:name, :string, allow_nil?: false, public?: true)
    attribute(:slug, :string, allow_nil?: false, public?: true, writable?: false)
    attribute(:active, :boolean, allow_nil?: false, default: true)
    attribute(:deactivated_at, :utc_datetime_usec, public?: false)
  end

  actions do
    defaults([:read])

    create :create do
      # AshSlug generates the slug from :name before validation
      accept([:name])
      change(slugify(:name, into: :slug))
    end

    update :update do
      accept([:name])
      change(slugify(:name, into: :slug))
    end

    update :deactivate do
      accept([])
      change(set_attribute(:active, false))
      change(set_attribute(:deactivated_at, &DateTime.utc_now/0))
    end

    update :reactivate do
      accept([])
      change(set_attribute(:active, true))
      change(set_attribute(:deactivated_at, nil))
    end
  end

  identities do
    identity(:unique_name, [:name])
    identity(:unique_slug, [:slug])
  end

  relationships do
    has_many :org_memberships, Dash.Accounts.OrgMembership
    has_many :teams, Dash.Accounts.Team
  end

  policies do
    policy action_type(:read) do
      authorize_if(expr(exists(org_memberships, user_id == ^actor(:id))))
    end

    # ONLY system/admin can create organizations (not regular users)
    policy action_type(:create) do
      # Block everyone for now
      forbid_if(always())
      # TODO: add exception to create organizations
      # Later you can add: authorize_if actor_attribute_equals(:is_system_admin, true)
    end

    # Owners can update organization details
    policy action_type(:update) do
      authorize_if(expr(exists(org_memberships, user_id == ^actor(:id) and role == :owner)))
    end

    # Only system admins can deactivate/reactivate (or owners with confirmation)
    policy action([:deactivate, :reactivate]) do
      # For now, only via system/admin
      forbid_if(always())
      # TODO: add exception to deactivate/reactivate organizations
    end
  end
end
