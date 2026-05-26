import Config
config :exhs, token_signing_secret: "CE11p10HNjaR+TROWM+NfRWaXsx9tpeH"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Run Oban jobs inline during tests
config :exhs, Oban, testing: :inline

# Tests use a stub instead of hitting Stripe. The stub returns canned data
# and verifies signatures by checking against a known marker.
config :exhs, :stripe_client, Exhs.Billing.StripeClient.Stub
config :exhs, :stripe_webhook_signing_secret, "whsec_test_secret"

# Local Minio for tests
config :ex_aws,
  access_key_id: "minioadmin",
  secret_access_key: "minioadmin"

config :ex_aws, :s3,
  scheme: "http://",
  host: "localhost",
  port: 9000

config :exhs, :s3_bucket, "exhs-test"

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :exhs, Exhs.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "exhs_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :exhs, ExhsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+5GCX0JP9mKdVtJEIfI9JZhTRmSDve7RR4Em2vpQf97mwmwe5Kk0vBBl9kd4R7Xd",
  server: false

# In test we don't send emails
config :exhs, Exhs.Mailer, adapter: Swoosh.Adapters.Test

# Subdomain resolution in tests
config :exhs, :base_host, "lvh.me"

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
