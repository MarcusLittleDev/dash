defmodule Dash.Accounts do
  use Ash.Domain,
    otp_app: :dash

  resources do
    resource Dash.Accounts.Token
    resource Dash.Accounts.User
  end
end
