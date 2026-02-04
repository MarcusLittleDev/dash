defmodule Dash.Dashboards.Widget do
  @moduledoc """
  Widget resource for displaying pipeline data in various formats.

  Widgets are configurable visualization components that belong to a dashboard
  and display data from a specific pipeline. Supported types:
  - :table - Tabular data display with configurable columns
  - :line_chart - Time-series line chart visualization
  - :stat_card - Single metric display with aggregation
  - :bar_chart - Bar chart visualization

  Widget configuration is stored as a map with type-specific options.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Dashboards,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("widgets")
    repo(Dash.Repo)
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 100)
    end

    attribute :type, :atom do
      allow_nil?(false)
      public?(true)
      constraints(one_of: [:table, :line_chart, :stat_card, :bar_chart])
      description("Widget visualization type")
    end

    attribute :config, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
      description("Type-specific configuration (columns, fields, aggregations, etc.)")
    end

    attribute :position, :map do
      allow_nil?(false)
      default(%{"x" => 0, "y" => 0, "w" => 6, "h" => 4})
      public?(true)
      description("Grid position and size: {x, y, w, h}")
    end
  end

  relationships do
    belongs_to :dashboard, Dash.Dashboards.Dashboard do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :pipeline, Dash.Pipelines.Pipeline do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :type, :config, :position, :dashboard_id, :pipeline_id])
    end

    update :update do
      accept([:name, :type, :config, :position])
      require_atomic?(false)
    end

    update :update_position do
      accept([:position])
      require_atomic?(false)
    end

    read :for_dashboard do
      argument :dashboard_id, :uuid, allow_nil?: false
      filter(expr(dashboard_id == ^arg(:dashboard_id)))
    end

    read :for_pipeline do
      argument :pipeline_id, :uuid, allow_nil?: false
      filter(expr(pipeline_id == ^arg(:pipeline_id)))
    end
  end

  validations do
    validate(fn changeset, _context ->
      position = Ash.Changeset.get_attribute(changeset, :position)

      if is_map(position) do
        required_keys = ["x", "y", "w", "h"]
        has_all_keys = Enum.all?(required_keys, &Map.has_key?(position, &1))

        if has_all_keys do
          :ok
        else
          {:error, field: :position, message: "must have x, y, w, and h keys"}
        end
      else
        {:error, field: :position, message: "must be a map"}
      end
    end)
  end

  policies do
    policy action_type(:read) do
      authorize_if(expr(exists(dashboard.organization.org_memberships, user_id == ^actor(:id))))
    end

    policy action_type(:create) do
      authorize_if(actor_present())
    end

    policy action_type([:update, :destroy]) do
      authorize_if(expr(exists(dashboard.organization.org_memberships, user_id == ^actor(:id))))
    end
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: [:id])
  end
end
