defmodule Dash.Accounts.User.Senders do
  @moduledoc """
  Email senders for user authentication.
  """

  defmodule SendMagicLinkEmail do
    @moduledoc """
    Sends magic link emails for passwordless authentication.
    """
    use AshAuthentication.Sender
    import Swoosh.Email

    @impl true
    def send(user, token, _opts) do
      url = DashWeb.Endpoint.url() <> "/auth/user/magic_link?token=#{token}"

      new()
      |> to(user.email)
      |> from({"Dash", "noreply@yourdomain.com"})
      |> subject("Sign in to Dash")
      |> text_body("""
      Click the link below to sign in to Dash:

      #{url}

      This link will expire in 15 minutes.
      """)
      |> html_body("""
      <p>Click the link below to sign in to Dash:</p>
      <p><a href="#{url}">Sign in to Dash</a></p>
      <p>This link will expire in 15 minutes.</p>
      """)
      |> Dash.Mailer.deliver()
    end
  end

  defmodule SendPasswordResetEmail do
    @moduledoc """
    Sends password reset emails.
    """
    use AshAuthentication.Sender
    import Swoosh.Email

    @impl true
    def send(user, token, _opts) do
      url = DashWeb.Endpoint.url() <> "/auth/user/password/reset?token=#{token}"

      new()
      |> to(user.email)
      |> from({"Dash", "noreply@yourdomain.com"})
      |> subject("Reset your Dash password")
      |> text_body("""
      Click the link below to reset your password:

      #{url}

      This link will expire in 1 hour.
      """)
      |> html_body("""
      <p>Click the link below to reset your password:</p>
      <p><a href="#{url}">Reset Password</a></p>
      <p>This link will expire in 1 hour.</p>
      """)
      |> Dash.Mailer.deliver()
    end
  end
end
