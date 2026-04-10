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
        <h1 class="text-2xl font-bold text-primary">
          Welcome back, {@current_user.name || @current_user.email}
        </h1>

        <p class="mt-1 text-sm text-secondary">Here's your dashboard.</p>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div class="rounded-lg border border-base-border bg-surface p-6 shadow-sm">
          <h3 class="text-sm font-medium text-secondary">Status</h3>

          <p class="mt-2 text-3xl font-semibold text-primary">Active</p>
        </div>

        <div class="rounded-lg border border-base-border bg-surface p-6 shadow-sm">
          <h3 class="text-sm font-medium text-secondary">Member since</h3>

          <p class="mt-2 text-3xl font-semibold text-primary">
            {Calendar.strftime(@current_user.inserted_at, "%b %Y")}
          </p>
        </div>

        <div class="rounded-lg border border-base-border bg-surface p-6 shadow-sm">
          <h3 class="text-sm font-medium text-secondary">Account</h3>

          <p class="mt-2 text-lg font-semibold text-primary truncate">{@current_user.email}</p>
        </div>
      </div>
    </div>
    """
  end
end
