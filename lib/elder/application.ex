defmodule Elder.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElderWeb.Telemetry,
      Elder.Repo,
      {DNSCluster, query: Application.get_env(:elder, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Elder.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Elder.Finch},
      # Start a worker by calling: Elder.Worker.start_link(arg)
      # {Elder.Worker, arg},
      # Start to serve requests, typically the last entry
      ElderWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Elder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
