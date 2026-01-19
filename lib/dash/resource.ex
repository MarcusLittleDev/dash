defmodule Dash.Resource do
  defmacro __using__(opts) do
    quote do
      # Inherit Ash.Resource behavior
      use Ash.Resource, unquote(opts)

      # Inject common attributes for all resources
      attributes do
        uuid_primary_key(:id) # Adds a UUID primary key :id
        timestamps() # Adds :inserted_at and :updated_at
      end
    end
  end
end
