defmodule Dash.Accounts.OrgMembership do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("org_membership")
    repo(Dash.Repo)
  end
end
