defmodule Dash.Pipelines.Pipeline do
  @moduledoc """
  Pipeline resource for managing data ingestion pipelines.

  A pipeline defines how to fetch data from an external source, transform it,
  and store it as time-series events in the database.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Pipelines,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("pipelines")
    repo(Dash.Repo)
  end

  attributes do
    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :description, :string do
      public?(true)
    end

    attribute :status, :atom do
      allow_nil?(false)
      constraints(one_of: [:active, :inactive, :error])
      default(:inactive)
      public?(true)
      description("Pipeline execution status: active, inactive, or error")
    end

    attribute :type, :atom do
      allow_nil?(false)
      constraints(one_of: [:polling, :webhook, :realtime, :p2p])
      public?(true)
      description("Pipeline type: polling, webhook, realtime (future), or p2p (future)")
    end

    attribute :interval_seconds, :integer do
      public?(true)
      description("Polling interval in seconds (required for polling type, min: 30, max: 86400)")
    end

    attribute :source_type, :string do
      allow_nil?(false)
      public?(true)
      description("Source adapter type (e.g., 'http', 'graphql')")
    end

    attribute :source_config, :map do
      allow_nil?(false)
      public?(true)
      description("Source-specific configuration (url, headers, auth, etc.)")
    end

    attribute :sink_configs, {:array, :map} do
      default([])
      public?(true)
      description("Array of sink configurations for data output")
    end

    attribute :persist_data, :boolean do
      allow_nil?(false)
      default(true)
      public?(true)
      description("Whether to persist data to TimescaleDB as pipeline events")
    end

    attribute :retention_days, :integer do
      public?(true)
      description("Number of days to retain data (null for infinite retention)")
    end
  end

  relationships do
    belongs_to :organization, Dash.Accounts.Organization do
      allow_nil?(false)
      public?(true)
    end

    has_many :pipeline_events, Dash.Pipelines.PipelineEvent do
      public?(true)
    end

    has_many :execution_logs, Dash.Pipelines.ExecutionLog do
      public?(true)
    end
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :name,
        :description,
        :status,
        :type,
        :interval_seconds,
        :source_type,
        :source_config,
        :sink_configs,
        :persist_data,
        :retention_days,
        :organization_id
      ])
    end

    update :update do
      accept([
        :name,
        :description,
        :status,
        :type,
        :interval_seconds,
        :source_type,
        :source_config,
        :sink_configs,
        :persist_data,
        :retention_days
      ])
      require_atomic?(false)
    end

    destroy(:destroy)
  end

  identities do
    identity(:unique_name_per_org, [:organization_id, :name])
  end

  validations do
    validate(fn changeset, _context ->
      type = Ash.Changeset.get_attribute(changeset, :type)
      interval = Ash.Changeset.get_attribute(changeset, :interval_seconds)

      cond do
        type == :polling and is_nil(interval) ->
          {:error, field: :interval_seconds, message: "is required for polling pipelines"}

        type == :polling and interval != nil and (interval < 30 or interval > 86_400) ->
          {:error,
           field: :interval_seconds, message: "must be between 30 and 86400 seconds for polling"}

        type != :polling and interval != nil ->
          {:error, field: :interval_seconds, message: "should only be set for polling pipelines"}

        true ->
          :ok
      end
    end)

    validate(fn changeset, _context ->
      source_config = Ash.Changeset.get_attribute(changeset, :source_config)

      if is_map(source_config) and map_size(source_config) > 0 do
        :ok
      else
        {:error, field: :source_config, message: "must be a non-empty map"}
      end
    end)

    validate(fn changeset, _context ->
      sink_configs = Ash.Changeset.get_attribute(changeset, :sink_configs)

      if is_list(sink_configs) do
        if Enum.all?(sink_configs, fn config ->
             is_map(config) and Map.has_key?(config, "type") and Map.has_key?(config, "config")
           end) do
          :ok
        else
          {:error,
           field: :sink_configs,
           message: "each sink must have 'type' and 'config' keys (as strings)"}
        end
      else
        {:error, field: :sink_configs, message: "must be a list"}
      end
    end)
  end

  policies do
    policy action_type(:read) do
      authorize_if(relates_to_actor_via(:organization))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(relates_to_actor_via(:organization))
    end
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: [:id])
  end
end
