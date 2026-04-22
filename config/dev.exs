import Config

config :elder, Elder.Repo,
  username: System.get_env("DB_USER", "elder"),
  password: System.get_env("DB_PASSWORD", "elder"),
  hostname: System.get_env("DB_HOST", "elder_db"),
  database: System.get_env("DB_NAME", "elder_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: System.get_env("DB_POOL_SIZE", "10") |> String.to_integer()

config :elder, ElderWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: System.get_env("PHX_PORT", "4000") |> String.to_integer()],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base:
    System.get_env(
      "SECRET_KEY_BASE",
      "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_only_do_not_use_in_prod"
    ),
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:elder, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:elder, ~w(--watch)]}
  ]

config :elder, ElderWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/elder_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :elder, dev_routes: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :feature, :step, :cid, :reason]

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
