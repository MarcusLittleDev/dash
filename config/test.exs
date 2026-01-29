import Config
config :dash, token_signing_secret: "VQ1zWdXnW85FVJwYxeKduOlDN8g42iHr"

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dash, Dash.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dash_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  ownership_timeout: 60_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dash, DashWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PZABN3koxPc52x7sDAX/vnKIuAABWUOjj2PN8B+9gTC8J94kuCcYijpwOavv4e/v",
  server: false

# In test we don't send emails
config :dash, Dash.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Ash Framework test settings
config :ash_authentication,
  signing_secret: "test_secret_minimum_32_characters_long_for_security"

# Faster password hashing in tests
config :bcrypt_elixir, :log_rounds, 1

# Disable Oban during tests to avoid Sandbox conflicts
config :dash, Oban, testing: :manual

# Ash Framework test settings - disable async to work with SQL sandbox
config :ash, :disable_async?, true

# Suppress missed notification warnings in tests (they occur in transactions)
config :ash, :missed_notifications, :ignore
