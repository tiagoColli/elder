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
    <div class="space-y-6">
      <div class="flex items-baseline justify-between">
        <h1 class="text-2xl font-bold tracking-tight text-primary">Skills</h1>

        <span :if={@skills != []} class="text-xs text-muted">
          {length(@skills)} available
        </span>
      </div>

      <div :if={@skills == []} class="text-sm text-muted">No skills available yet.</div>

      <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div
          :for={skill <- @skills}
          class="rounded-xl border border-base-border bg-surface shadow-sm overflow-hidden"
        >
          <div class="border-b border-base-border bg-surface-raised px-4 py-2.5 flex items-center justify-between">
            <span class="text-[9px] font-bold uppercase tracking-widest text-muted">Skill</span>
            <span aria-hidden="true" class="inline-block h-1.5 w-1.5 rounded-full bg-accent/50">
            </span>
          </div>

          <div class="p-4">
            <h2 class="text-sm font-semibold text-primary">{skill.name}</h2>

            <p class="mt-1.5 text-xs leading-relaxed text-secondary line-clamp-2">
              {skill.description}
            </p>

            <.link
              navigate={~p"/skills/#{skill.slug}/run"}
              aria-label={"Run #{skill.name}"}
              class="mt-4 inline-block text-xs font-semibold text-accent-text hover:text-accent-text/80"
            >
              Run →
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
