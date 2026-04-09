defmodule ElderWeb.SkillsLive do
  @moduledoc """
  Lists all available skills as a grid of cards.
  Skills are file-based and sorted alphabetically by name.
  """

  use ElderWeb, :live_view

  alias Elder.Skills

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Skills", skills: Skills.list_skills())}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto py-10 px-4">
      <h1 class="text-2xl font-bold text-primary mb-6">Skills</h1>

      <div :if={@skills == []} class="text-muted text-sm">No skills available yet.</div>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <div
          :for={skill <- @skills}
          class="rounded-lg border border-base-border bg-surface p-5 hover:shadow-md transition-shadow"
        >
          <h2 class="text-base font-semibold text-primary">{skill.name}</h2>

          <p class="mt-1 text-sm text-secondary line-clamp-2">{skill.description}</p>

          <.link
            navigate={~p"/skills/#{skill.slug}/run"}
            class="mt-4 inline-block text-sm font-medium text-accent-text hover:text-accent-text/80"
          >
            Run →
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
