defmodule ElderWeb.DashboardLive do
  @moduledoc """
  Authenticated dashboard. Displays user profile info and account summary cards.
  """

  use ElderWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h1 class="text-2xl font-bold text-zinc-900">
          Welcome back, {@current_user.name || @current_user.email}
        </h1>
        <p class="mt-1 text-sm text-zinc-600">
          Here's your dashboard.
        </p>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div class="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h3 class="text-sm font-medium text-zinc-500">Status</h3>
          <p class="mt-2 text-3xl font-semibold text-zinc-900">Active</p>
        </div>
        <div class="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h3 class="text-sm font-medium text-zinc-500">Member since</h3>
          <p class="mt-2 text-3xl font-semibold text-zinc-900">
            {Calendar.strftime(@current_user.inserted_at, "%b %Y")}
          </p>
        </div>
        <div class="rounded-lg border border-zinc-200 bg-white p-6 shadow-sm">
          <h3 class="text-sm font-medium text-zinc-500">Account</h3>
          <p class="mt-2 text-lg font-semibold text-zinc-900 truncate">{@current_user.email}</p>
        </div>
      </div>
    </div>
    """
  end
end
