defmodule Dash.Accounts do
  use Ash.Domain,
    otp_app: :dash

  resources do
    resource Dash.Accounts.Token
    resource Dash.Accounts.User
    resource Dash.Accounts.Organization
    resource Dash.Accounts.OrgMembership
    resource Dash.Accounts.Team
    resource Dash.Accounts.TeamMember
  end
end
