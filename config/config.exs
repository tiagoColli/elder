import Config

config :elder,
  ecto_repos: [Elder.Repo],
  generators: [timestamp_type: :utc_datetime]

config :elder, ElderWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ElderWeb.ErrorHTML, json: ElderWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Elder.PubSub,
  live_view: [signing_salt: "k7V3xNdF"]

config :esbuild,
  version: "0.17.11",
  elder: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  elder: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :feature, :step, :cid, :count, :ms, :reason]

config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

config :phoenix, :json_library, Jason

config :elder, Elder.LLM,
  model: "google:gemini-2.5-flash",
  skip_interview_call: false

config :elder, Elder.Asana,
  pat: nil,
  default_project_gid: nil,
  default_workspace_gid: nil

config :elder, :asana_client, Elder.Asana.Client

import_config "#{config_env()}.exs"
