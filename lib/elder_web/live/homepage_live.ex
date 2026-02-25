defmodule ElderWeb.HomepageLive do
  use ElderWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="flex min-h-[80vh] flex-col items-center justify-center">
      <h1 class="text-5xl font-bold tracking-tight text-zinc-900">
        Elder
      </h1>
      <p class="mt-4 text-lg text-zinc-600">
        Building something great.
      </p>
    </div>
    """
  end
end
