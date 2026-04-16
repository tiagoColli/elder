import Config

if System.get_env("PHX_SERVER") do
  config :elder, ElderWeb.Endpoint, server: true
end

if config_env() in [:prod, :dev] do
  config :ueberauth, Ueberauth.Strategy.Google.OAuth,
    client_id: System.get_env("GOOGLE_CLIENT_ID") || "",
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || ""
end

if config_env() != :test do
  config :elder, Elder.LLM, model: System.get_env("LLM_MODEL", "google:gemini-2.5-flash")
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :elder, Elder.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :elder, ElderWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base
end

if config_env() != :test do
  # Bridge GOOGLE_API_KEY to GEMINI_API_KEY for ExLLM's Gemini provider.
  # ExLLM reads GEMINI_API_KEY from env; Elder historically used GOOGLE_API_KEY.
  # Remove once all deployments use GEMINI_API_KEY directly.
  gemini_key = System.get_env("GEMINI_API_KEY") || System.get_env("GOOGLE_API_KEY")

  if gemini_key do
    System.put_env("GEMINI_API_KEY", gemini_key)
  end

  config :elder, Elder.Asana,
    pat: System.fetch_env!("ASANA_PAT"),
    default_project_gid: System.get_env("ASANA_DEFAULT_PROJECT_GID"),
    default_workspace_gid: System.get_env("ASANA_DEFAULT_WORKSPACE_GID")
end
