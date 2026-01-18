# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :spark,
  formatter: ["Ash.Resource": [section_order: [:authentication, :token, :user_identity]]]

config :dash,
  ecto_repos: [Dash.Repo],
  generators: [timestamp_type: :utc_datetime],
  ash_domains: [Dash.Accounts, Dash.Domain],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true]

# Configure the endpoint
config :dash, DashWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DashWeb.ErrorHTML, json: DashWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Dash.PubSub,
  live_view: [signing_salt: "LtGE5eT8"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :dash, Dash.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  dash: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  dash: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# configures ecto to use binary id's for primary and foreign keys
# uses utc time for timestamps instead of native_datetime (timestamp with no timezone info)
config :dash, Dash.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [column: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime]

# Configure AshPostgres
config :ash, :use_all_identities_in_manage_relationship?, false

# Configure AshAuthentication
config :ash_authentication,
  token_lifetime: {1, :hour},
  signing_secret: "change_this_in_production"

# Configure Oban for background job processing
config :dash, Oban,
  repo: Dash.Repo,
  plugins: [
    # Automatically prune completed jobs
    Oban.Plugins.Pruner
  ],
  queues: [
    default: 10,
    # For pipeline polling jobs
    pipelines: 20,
    # For sending emails
    mailers: 5
  ]
