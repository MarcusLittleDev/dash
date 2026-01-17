defmodule Dash.Domain do
  @moduledoc """
  Dash Ash Domain - contains all resources for the application.

  In Ash 3.x, Domains replace Registries. A Domain groups related resources
  and defines how they interact with each other.
  """

  use Ash.Domain

  resources do
    # Register all resources in the domain here
    resource(Dash.Accounts.Token)
    resource(Dash.Accounts.User)
  end
end
