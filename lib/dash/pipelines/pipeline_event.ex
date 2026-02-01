defmodule Dash.Pipelines.PipelineEvent do
  @moduledoc """
  PipelineEvent resource for storing time-series data events from pipelines.

  Each event represents a data point captured by a pipeline at a specific timestamp.
  Stored in a TimescaleDB hypertable for efficient time-series querying.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Pipelines,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("pipeline_events")
    repo(Dash.Repo)
  end

  attributes do
    attribute :timestamp, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      default(&DateTime.utc_now/0)
      description("The timestamp when this event occurred")
    end

    attribute :data, :map do
      allow_nil?(false)
      public?(true)
      description("The actual event data payload (JSONB in PostgreSQL)")
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
      description("Processing metadata (source info, transformations applied, etc.)")
    end
  end

  relationships do
    belongs_to :pipeline, Dash.Pipelines.Pipeline do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([:timestamp, :data, :metadata])
      argument(:pipeline_id, :uuid, allow_nil?: false)

      change(manage_relationship(:pipeline_id, :pipeline, type: :append))
    end

    read :recent do
      argument(:pipeline_id, :uuid, allow_nil?: false)
      argument(:limit, :integer, default: 100)

      prepare(fn query, _context ->
        pipeline_id = Ash.Query.get_argument(query, :pipeline_id)
        limit = Ash.Query.get_argument(query, :limit)

        query
        |> Ash.Query.filter(expr(pipeline_id == ^pipeline_id))
        |> Ash.Query.sort(timestamp: :desc)
        |> Ash.Query.limit(limit)
      end)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if(expr(exists(pipeline.organization.org_memberships, user_id == ^actor(:id))))
    end

    # Pipeline events are created by the executor (system), not users directly
    # The executor uses authorize?: false when creating events
    policy action_type(:create) do
      authorize_if(actor_present())
    end
  end

  code_interface do
    define(:list_recent, action: :recent, args: [:pipeline_id, :limit])
  end
end
