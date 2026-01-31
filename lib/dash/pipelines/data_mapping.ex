defmodule Dash.Pipelines.DataMapping do
  @moduledoc """
  Data mapping resource for defining field-level transformations in pipelines.

  Mappings define how to transform source fields into target fields for storage
  as pipeline events. For Week 3-4, only simple field remapping is supported.
  """

  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Pipelines,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("data_mappings")
    repo(Dash.Repo)
  end

  attributes do
    attribute :source_field, :string do
      allow_nil?(false)
      public?(true)
      description("Source field path (e.g., 'data.temperature' for nested fields)")
    end

    attribute :target_field, :string do
      allow_nil?(false)
      public?(true)
      description("Target field name for storage in pipeline events")
    end

    attribute :transformation_type, :atom do
      constraints(one_of: [:direct, :cast_integer, :cast_float, :cast_string, :timestamp])
      default(:direct)
      public?(true)
      description("Transformation type for the field (Week 3-4: only 'direct' supported)")
    end

    attribute :required, :boolean do
      allow_nil?(false)
      default(false)
      public?(true)
      description("Whether this field is required in source data")
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
      accept([:source_field, :target_field, :transformation_type, :required, :pipeline_id])
    end

    update :update do
      accept([:source_field, :target_field, :transformation_type, :required])
      require_atomic?(false)
    end

    destroy(:destroy)
  end

  identities do
    identity(:unique_target_per_pipeline, [:pipeline_id, :target_field])
  end

  validations do
    validate(fn changeset, _context ->
      source = Ash.Changeset.get_attribute(changeset, :source_field)
      target = Ash.Changeset.get_attribute(changeset, :target_field)

      cond do
        is_nil(source) or String.trim(source) == "" ->
          {:error, field: :source_field, message: "cannot be empty"}

        is_nil(target) or String.trim(target) == "" ->
          {:error, field: :target_field, message: "cannot be empty"}

        not Regex.match?(~r/^[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*$/i, source) ->
          {:error,
           field: :source_field,
           message: "must be a valid field path (e.g., 'field' or 'data.nested.field')"}

        not Regex.match?(~r/^[a-z_][a-z0-9_]*$/i, target) ->
          {:error,
           field: :target_field,
           message: "must be a valid identifier (letters, numbers, underscores only)"}

        true ->
          :ok
      end
    end)
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
