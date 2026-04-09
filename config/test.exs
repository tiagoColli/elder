import Config

config :elder, Elder.Repo,
  username: System.get_env("DB_USER", "elder"),
  password: System.get_env("DB_PASSWORD", "elder"),
  hostname: System.get_env("DB_HOST", "elder_db"),
  database:
    "#{System.get_env("DB_TEST_NAME", "elder_test")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :elder, ElderWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "test_secret_key_base_that_is_at_least_64_bytes_long_for_test_only_do_not_use_in_production"
    ),
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :elder, :asana_client, Elder.Asana.ClientMock

config :elder, :llm_client, Elder.LLM.ClientMock
