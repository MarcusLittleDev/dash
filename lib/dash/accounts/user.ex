defmodule Dash.Accounts.User do
  use Ash.Resource,
    domain: Dash.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  alias Dash.Accounts.User.Senders

  attributes do
    uuid_primary_key(:id)
    timestamps()

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end
  end

  authentication do
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(Dash.Accounts.Token)

      signing_secret(fn _, _ ->
        {:ok, Application.fetch_env!(:ash_authentication, :signing_secret)}
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
        hash_provider(AshAuthentication.BcryptProvider)

        sign_in_action_name(:sign_in_with_password)
        register_action_name(:register_with_password)

        resettable do
          sender(Senders.SendPasswordResetEmail)
        end
      end

      magic_link :magic_link do
        identity_field(:email)
        sender(Senders.SendMagicLinkEmail)
        token_lifetime({15, :minutes})
        require_interaction?(true)

        request_action_name(:request_magic_link)
        sign_in_action_name(:sign_in_with_magic_link)
      end
    end
  end

  identities do
    identity :unique_email, [:email] do
      eager_check_with(Dash.Domain)
    end
  end

  policies do
    # Allow all authentication-related actions (sign in, register, password reset, etc.)
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    # Users can read their own record
    policy action_type(:read) do
      authorize_if(expr(id == ^actor(:id)))
    end

    # Users can update their own record
    policy action_type(:update) do
      authorize_if(expr(id == ^actor(:id)))
    end

    # Prevent manual user creation (users should register via authentication)
    # Note: Authentication actions bypass this policy
    policy action_type(:create) do
      forbid_if(always())
    end

    # Prevent user deletion
    policy action_type(:destroy) do
      forbid_if(always())
    end
  end

  postgres do
    table("users")
    repo(Dash.Repo)
  end

  actions do
    defaults([:read])
  end

  code_interface do
    # Defines a function to get a user by their email.
    define(:get_by_email, get_by: [:email], action: :read)
  end
end
