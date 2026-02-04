defmodule Dash.Dashboards.Dashboard do
  @moduledoc """
  Dashboard resource for organizing and displaying pipeline data visualizations.

  A dashboard contains multiple widgets that display data from pipelines in
  various formats (tables, charts, stat cards). Dashboards receive real-time
  updates via PubSub when pipeline data changes.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Dashboards,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("dashboards")
    repo(Dash.Repo)
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 100)
    end

    attribute :description, :string do
      public?(true)
      constraints(max_length: 500)
    end

    attribute :is_default, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
      description("Whether this is the default dashboard for the organization")
    end
  end

  relationships do
    belongs_to :organization, Dash.Accounts.Organization do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :created_by, Dash.Accounts.User do
      public?(true)
    end

    has_many :widgets, Dash.Dashboards.Widget do
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :description, :is_default, :organization_id, :created_by_id])
    end

    update :update do
      accept([:name, :description, :is_default])
      require_atomic?(false)
    end

    read :for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter(expr(organization_id == ^arg(:organization_id)))
    end

    read :default_for_organization do
      argument :organization_id, :uuid, allow_nil?: false
      filter(expr(organization_id == ^arg(:organization_id) and is_default == true))
    end
  end

  identities do
    identity(:unique_name_per_org, [:organization_id, :name])
  end

  policies do
    policy action_type(:read) do
      authorize_if(expr(exists(organization.org_memberships, user_id == ^actor(:id))))
    end

    policy action_type(:create) do
      authorize_if(actor_present())
    end

    policy action_type([:update, :destroy]) do
      authorize_if(expr(exists(organization.org_memberships, user_id == ^actor(:id))))
    end
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: [:id])
  end
end
