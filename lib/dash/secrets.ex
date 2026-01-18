defmodule Dash.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Dash.Accounts.User, _opts, _context) do
    Application.fetch_env(:dash, :token_signing_secret)
  end
end
