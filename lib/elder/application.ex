defmodule Elder.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      Elder.Repo,
      ElderWeb.Telemetry,
      {Phoenix.PubSub, name: Elder.PubSub},
      ElderWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Elder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    ElderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
