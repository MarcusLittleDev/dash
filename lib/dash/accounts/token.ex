# Defines the Token resource for user authentication tokens.
defmodule Dash.Accounts.Token do
  use Ash.Resource,
    domain: Dash.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("user_tokens")
    repo(Dash.Repo)
  end
end
