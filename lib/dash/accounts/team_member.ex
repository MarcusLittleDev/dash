defmodule Dash.Accounts.TeamMember do
  use Dash.Resource,
    otp_app: :dash,
    domain: Dash.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("team_member")
    repo(Dash.Repo)
  end
end
