defmodule Dash.Accounts.Organization do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("organization")
    repo(Dash.Repo)
  end
end
