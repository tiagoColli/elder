defmodule ElderWeb.DashboardLive do
  @moduledoc """
  Authenticated dashboard. Displays user profile info and account summary cards.
  """

  use ElderWeb, :live_view

  alias Elder.Skills

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    skill_count = length(Skills.list_skills())

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       skill_count: skill_count
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 class="text-2xl font-bold text-primary">
            Welcome back, {@current_user.name || @current_user.email}
          </h1>
          <p class="mt-1 text-sm text-secondary">
            Manage your account or run skills from the catalog.
          </p>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
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

        <div class="rounded-lg border border-base-border bg-surface p-6 shadow-sm">
          <h3 class="text-sm font-medium text-secondary">Available skills</h3>
          <p class="mt-2 text-3xl font-semibold text-primary">{@skill_count}</p>
          <.link
            navigate={~p"/skills"}
            class="mt-3 inline-block text-sm font-medium text-accent-text hover:text-accent-text/80"
          >
            Browse catalog →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
