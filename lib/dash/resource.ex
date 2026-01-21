defmodule Dash.Resource do
  defmacro __using__(opts) do
    quote do
      # Inherit Ash.Resource behavior
      use Ash.Resource, unquote(opts)

      # Inject common attributes for all resources
      attributes do
        # Adds a UUID primary key :id
        uuid_primary_key(:id)
        # Adds :inserted_at and :updated_at
        timestamps()
      end
    end
  end
end
