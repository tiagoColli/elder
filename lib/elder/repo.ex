defmodule Elder.Repo do
  use Ecto.Repo,
    otp_app: :elder,
    adapter: Ecto.Adapters.Postgres
end
