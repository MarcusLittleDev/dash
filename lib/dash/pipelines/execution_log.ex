defmodule Dash.Pipelines.ExecutionLog do
  @moduledoc """
  Execution log resource for tracking pipeline execution history.

  Logs are created for EVERY pipeline execution, whether successful or failed,
  and whether data was fetched or not. This provides a complete audit trail
  of all pipeline activity.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Pipelines,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("pipeline_execution_logs")
    repo(Dash.Repo)
  end

  attributes do
    attribute :status, :atom do
      allow_nil?(false)
      constraints(one_of: [:success, :error, :no_data])
      public?(true)
      description("Execution outcome: success (data fetched), error, or no_data (successful but empty)")
    end

    attribute :started_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
      description("When the execution started")
    end

    attribute :completed_at, :utc_datetime_usec do
      public?(true)
      description("When the execution completed (null if still running)")
    end

    attribute :duration_ms, :integer do
      public?(true)
      description("Total execution duration in milliseconds")
    end

    attribute :records_fetched, :integer do
      default(0)
      public?(true)
      description("Number of records fetched from source")
    end

    attribute :records_stored, :integer do
      default(0)
      public?(true)
      description("Number of records successfully stored as pipeline events")
    end

    attribute :source_response_time_ms, :integer do
      public?(true)
      description("Time taken for source to respond in milliseconds")
    end

    attribute :error_type, :atom do
      constraints(one_of: [:source_fetch, :transformation, :storage, :sink_delivery, :validation, :timeout])
      public?(true)
      description("Category of error if execution failed")
    end

    attribute :error_message, :string do
      public?(true)
      description("Detailed error message if execution failed")
    end

    attribute :error_details, :map do
      public?(true)
      description("Additional error context (stack trace, request details, etc.)")
    end

    attribute :metadata, :map do
      default(%{})
      public?(true)
      description("Additional execution metadata (source response headers, rate limit info, etc.)")
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
      accept([
        :status,
        :started_at,
        :completed_at,
        :duration_ms,
        :records_fetched,
        :records_stored,
        :source_response_time_ms,
        :error_type,
        :error_message,
        :error_details,
        :metadata,
        :pipeline_id
      ])
    end

    update :update do
      accept([
        :status,
        :completed_at,
        :duration_ms,
        :records_fetched,
        :records_stored,
        :source_response_time_ms,
        :error_type,
        :error_message,
        :error_details,
        :metadata
      ])
      require_atomic?(false)
    end

    destroy(:destroy)
  end

  validations do
    validate(fn changeset, _context ->
      status = Ash.Changeset.get_attribute(changeset, :status)
      error_type = Ash.Changeset.get_attribute(changeset, :error_type)
      error_message = Ash.Changeset.get_attribute(changeset, :error_message)

      cond do
        status == :error and is_nil(error_type) ->
          {:error, field: :error_type, message: "is required when status is error"}

        status == :error and is_nil(error_message) ->
          {:error, field: :error_message, message: "is required when status is error"}

        status != :error and not is_nil(error_type) ->
          {:error, field: :error_type, message: "should only be set when status is error"}

        true ->
          :ok
      end
    end)

    validate(fn changeset, _context ->
      started = Ash.Changeset.get_attribute(changeset, :started_at)
      completed = Ash.Changeset.get_attribute(changeset, :completed_at)

      if not is_nil(started) and not is_nil(completed) and
           DateTime.compare(completed, started) == :lt do
        {:error, field: :completed_at, message: "cannot be before started_at"}
      else
        :ok
      end
    end)
  end

  calculations do
    calculate :is_running, :boolean, expr(is_nil(completed_at))
  end

  policies do
    policy action_type(:read) do
      authorize_if(relates_to_actor_via([:pipeline, :organization]))
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if(relates_to_actor_via([:pipeline, :organization]))
    end
  end

  code_interface do
    define(:get_by_id, action: :read, get_by: [:id])
  end
end
