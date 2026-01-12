defmodule Dash.Resource do
  @moduledoc """
  Base resource configuration shared by all Dash resources.
  """

  defmacro __using__(_opts) do
    quote do
      use Ash.Resource,
        domain: Dash.Domain,
        data_layer: AshPostgres.DataLayer

      postgres do
        repo(Dash.Repo)
      end

      # Default attributes all resources get
      attributes do
        uuid_primary_key(:id)

        timestamps()
      end
    end
  end
end
