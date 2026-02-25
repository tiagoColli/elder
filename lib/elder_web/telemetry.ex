defmodule ElderWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_arg) do
    children = [
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.mount.stop.duration",
        tags: [:view],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        tags: [:view, :event],
        unit: {:native, :millisecond}
      ),
      summary("elder.repo.query.total_time",
        unit: {:native, :millisecond}
      ),
      summary("elder.repo.query.decode_time",
        unit: {:native, :millisecond}
      ),
      summary("elder.repo.query.query_time",
        unit: {:native, :millisecond}
      ),
      summary("elder.repo.query.queue_time",
        unit: {:native, :millisecond}
      ),
      summary("elder.repo.query.idle_time",
        unit: {:native, :millisecond}
      )
    ]
  end

  defp periodic_measurements do
    []
  end
end
