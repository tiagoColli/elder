defmodule ElderWeb.SkillRunLive do
  @moduledoc """
  Executes a single skill: accepts user input, streams LLM tokens, and sends
  the result to Asana.

  State machine: `:idle` → `:streaming` → `:done` → `:sending_to_asana` → `:asana_success`
  Errors at any stage return to `:idle` or `:done` with an error message.
  """

  use ElderWeb, :live_view

  @compile {:no_warn_undefined, Elder.Asana}

  alias Elder.Asana
  alias Elder.LLM
  alias Elder.Skills
  alias Phoenix.PubSub

  @impl Phoenix.LiveView
  def mount(%{"slug" => slug}, _session, socket) do
    skill = Skills.get_skill!(slug)

    socket =
      socket
      |> assign(
        page_title: skill.name,
        skill: skill,
        skill_run: nil,
        phase: :idle,
        user_input: "",
        llm_output: "",
        llm_cost: nil,
        asana_task_url: nil,
        error: nil,
        token_count: 0,
        workspaces: [],
        projects: [],
        sections: [],
        selected_workspace_gid: nil,
        selected_project_gid: nil,
        selected_section_gid: nil,
        asana_loading: false
      )
      |> stream(:tokens, [])

    {:ok, socket}
  rescue
    _error -> {:ok, push_navigate(socket, to: ~p"/skills")}
  end

  @impl Phoenix.LiveView
  def handle_event("generate", %{"user_input" => ""}, socket) do
    {:noreply, assign(socket, error: "Please describe what you need")}
  end

  def handle_event("generate", %{"user_input" => input}, socket) do
    topic = "skill_run:#{socket.id}"
    PubSub.subscribe(Elder.PubSub, topic)
    :ok = LLM.stream_run(socket.assigns.skill, input, topic)

    socket =
      socket
      |> assign(phase: :streaming, user_input: input, error: nil, token_count: 0)
      |> stream(:tokens, [], reset: true)

    {:noreply, socket}
  end

  def handle_event("select_workspace", %{"workspace_gid" => gid}, socket) do
    lv_pid = self()

    Task.start(fn ->
      result =
        try do
          Asana.list_projects(gid)
        rescue
          e -> {:error, {:exception, e}}
        end

      send(lv_pid, {:asana_projects_loaded, result})
    end)

    socket =
      assign(socket,
        selected_workspace_gid: gid,
        projects: [],
        sections: [],
        selected_project_gid: nil,
        selected_section_gid: nil,
        asana_loading: true
      )

    {:noreply, socket}
  end

  def handle_event("select_project", %{"project_gid" => gid}, socket) do
    lv_pid = self()

    Task.start(fn ->
      result =
        try do
          Asana.list_sections(gid)
        rescue
          e -> {:error, {:exception, e}}
        end

      send(lv_pid, {:asana_sections_loaded, result})
    end)

    socket =
      assign(socket,
        selected_project_gid: gid,
        sections: [],
        selected_section_gid: nil,
        asana_loading: true
      )

    {:noreply, socket}
  end

  def handle_event("select_section", %{"section_gid" => gid}, socket) do
    {:noreply, assign(socket, selected_section_gid: gid)}
  end

  def handle_event("send_to_asana", _params, socket) do
    skill_run = socket.assigns.skill_run
    lv_pid = self()

    target = %{
      workspace_gid: socket.assigns.selected_workspace_gid,
      project_gid: socket.assigns.selected_project_gid,
      section_gid: socket.assigns.selected_section_gid
    }

    Task.start(fn ->
      result =
        try do
          Asana.create_task(skill_run, target)
        rescue
          e -> {:error, {:exception, e}}
        end

      send(lv_pid, {:asana_result, result})
    end)

    {:noreply, assign(socket, phase: :sending_to_asana)}
  end

  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign(
        skill_run: nil,
        phase: :idle,
        user_input: "",
        llm_output: "",
        llm_cost: nil,
        asana_task_url: nil,
        error: nil,
        token_count: 0,
        workspaces: [],
        projects: [],
        sections: [],
        selected_workspace_gid: nil,
        selected_project_gid: nil,
        selected_section_gid: nil,
        asana_loading: false
      )
      |> stream(:tokens, [], reset: true)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:llm_token, token}, socket) do
    n = socket.assigns.token_count

    socket =
      socket
      |> stream_insert(:tokens, %{id: "token-#{n}", text: token})
      |> assign(:token_count, n + 1)

    {:noreply, socket}
  end

  def handle_info({:llm_done, meta}, socket) do
    attrs = %{
      skill_slug: socket.assigns.skill.slug,
      user_id: socket.assigns.current_user.id,
      user_input: socket.assigns.user_input,
      llm_output: meta.output,
      model: meta.model,
      cost_usd: meta.cost_usd,
      status: :done
    }

    case Skills.save_run(attrs) do
      {:ok, skill_run} ->
        lv_pid = self()

        Task.start(fn ->
          result =
            try do
              Asana.list_workspaces()
            rescue
              e -> {:error, {:exception, e}}
            end

          send(lv_pid, {:asana_workspaces_loaded, result})
        end)

        socket =
          assign(socket,
            skill_run: skill_run,
            phase: :done,
            llm_output: meta.output,
            llm_cost: meta.cost_usd,
            asana_loading: true
          )

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> assign(phase: :idle, error: "Failed to save result. Please try again.")
          |> stream(:tokens, [], reset: true)

        {:noreply, socket}
    end
  end

  def handle_info({:llm_error, reason}, socket) do
    socket =
      socket
      |> assign(phase: :idle, error: format_llm_error(reason))
      |> stream(:tokens, [], reset: true)

    {:noreply, socket}
  end

  def handle_info({:asana_workspaces_loaded, {:ok, workspaces}}, socket) do
    {:noreply, assign(socket, workspaces: workspaces, asana_loading: false)}
  end

  def handle_info({:asana_workspaces_loaded, {:error, _reason}}, socket) do
    {:noreply, assign(socket, asana_loading: false, error: "Could not load Asana workspaces")}
  end

  def handle_info({:asana_projects_loaded, {:ok, projects}}, socket) do
    {:noreply, assign(socket, projects: projects, asana_loading: false)}
  end

  def handle_info({:asana_projects_loaded, {:error, _reason}}, socket) do
    {:noreply, assign(socket, asana_loading: false, error: "Could not load Asana projects")}
  end

  def handle_info({:asana_sections_loaded, {:ok, sections}}, socket) do
    {:noreply, assign(socket, sections: sections, asana_loading: false)}
  end

  def handle_info({:asana_sections_loaded, {:error, _reason}}, socket) do
    {:noreply,
     assign(socket, asana_loading: false, sections: [], error: "Could not load Asana sections")}
  end

  def handle_info({:asana_result, {:ok, %{task_url: url}}}, socket) do
    {:noreply, assign(socket, phase: :asana_success, asana_task_url: url)}
  end

  def handle_info({:asana_result, {:error, reason}}, socket) do
    {:noreply,
     assign(socket,
       phase: :done,
       error: "Could not create Asana task: #{inspect(reason)}"
     )}
  end

  defp format_llm_error(%{status: status}) when status in [503, 429] do
    "The AI provider is temporarily unavailable. Please try again in a moment."
  end

  defp format_llm_error(%{reason: reason}) when is_binary(reason) do
    "Generation failed: #{reason}"
  end

  defp format_llm_error(%{cause: %{reason: reason}}) when is_binary(reason) do
    "Generation failed: #{reason}"
  end

  defp format_llm_error(_reason) do
    "Generation failed. Please try again."
  end

  defp sanitize_llm_output(html) do
    html
    |> String.replace(~r/<body>/i, "")
    |> String.replace(~r/<\/body>/i, "")
    |> String.trim()
    |> HtmlSanitizeEx.basic_html()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto py-10 px-4">
      <div class="mb-8">
        <.link navigate={~p"/skills"} class="text-sm text-zinc-500 hover:text-zinc-700">
          ← Back to Skills
        </.link>
        <h1 class="mt-2 text-2xl font-bold text-zinc-900">{@skill.name}</h1>
        <p class="mt-1 text-sm text-zinc-500">{@skill.description}</p>
      </div>

      <div :if={@error} class="mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700">
        {@error}
      </div>

      <div :if={@phase == :idle}>
        <form phx-submit="generate">
          <label class="block text-sm font-medium text-zinc-700 mb-1">Your brief</label>
          <textarea
            name="user_input"
            rows="5"
            placeholder="Describe what you need..."
            class="block w-full rounded-md border-zinc-300 shadow-sm text-sm focus:border-indigo-500 focus:ring-indigo-500"
          >{@user_input}</textarea>
          <div class="mt-3 flex justify-end">
            <button
              type="submit"
              class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-500"
            >
              Generate →
            </button>
          </div>
        </form>
      </div>

      <div :if={@phase == :streaming}>
        <div class="flex items-center gap-2 mb-3 text-sm text-zinc-500">
          <span class="animate-spin inline-block w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full">
          </span>
          Generating...
        </div>
        <div
          id="token-stream"
          phx-update="stream"
          class="rounded-md bg-zinc-50 border border-zinc-200 p-4 text-sm text-zinc-800 font-mono whitespace-pre-wrap min-h-32"
        >
          <span :for={{dom_id, item} <- @streams.tokens} id={dom_id}>{item.text}</span>
        </div>
      </div>

      <div :if={@phase in [:done, :sending_to_asana, :asana_success]}>
        <label class="block text-sm font-medium text-zinc-700 mb-1">Generated output</label>
        <div class="brief-output rounded-md border border-zinc-200 bg-white p-4 min-h-40">
          {raw(sanitize_llm_output(@llm_output))}
        </div>

        <div :if={@phase in [:done, :sending_to_asana]} class="mt-6 space-y-3">
          <p class="text-sm font-medium text-zinc-700">Send to Asana</p>

          <div :if={@asana_loading} class="flex items-center gap-2 text-sm text-zinc-400">
            <span class="animate-spin inline-block w-3 h-3 border-2 border-zinc-400 border-t-transparent rounded-full">
            </span>
            Loading...
          </div>

          <div :if={not @asana_loading and @workspaces != []}>
            <label class="block text-xs text-zinc-500 mb-1">Workspace</label>
            <form phx-change="select_workspace">
              <select
                name="workspace_gid"
                class="block w-full rounded-md border-zinc-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              >
                <option value="">Select workspace...</option>
                <option
                  :for={ws <- @workspaces}
                  value={ws.gid}
                  selected={ws.gid == @selected_workspace_gid}
                >
                  {ws.name}
                </option>
              </select>
            </form>
          </div>

          <div :if={@selected_workspace_gid && not @asana_loading && @projects != []}>
            <label class="block text-xs text-zinc-500 mb-1">Project</label>
            <form phx-change="select_project">
              <select
                name="project_gid"
                class="block w-full rounded-md border-zinc-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              >
                <option value="">Select project...</option>
                <option
                  :for={p <- @projects}
                  value={p.gid}
                  selected={p.gid == @selected_project_gid}
                >
                  {p.name}
                </option>
              </select>
            </form>
          </div>

          <div :if={@selected_project_gid && not @asana_loading && @sections != []}>
            <label class="block text-xs text-zinc-500 mb-1">Section (optional)</label>
            <form phx-change="select_section">
              <select
                name="section_gid"
                class="block w-full rounded-md border-zinc-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
              >
                <option value="">No section</option>
                <option
                  :for={s <- @sections}
                  value={s.gid}
                  selected={s.gid == @selected_section_gid}
                >
                  {s.name}
                </option>
              </select>
            </form>
          </div>

          <div class="flex items-center gap-3 pt-1">
            <button
              :if={@phase == :done}
              phx-click="send_to_asana"
              disabled={is_nil(@selected_workspace_gid)}
              class={[
                "rounded-md px-4 py-2 text-sm font-semibold text-white",
                if(is_nil(@selected_workspace_gid),
                  do: "bg-green-300 cursor-not-allowed",
                  else: "bg-green-600 hover:bg-green-500"
                )
              ]}
            >
              Send to Asana →
            </button>

            <button
              :if={@phase == :sending_to_asana}
              disabled
              class="rounded-md bg-green-400 px-4 py-2 text-sm font-semibold text-white cursor-not-allowed"
            >
              Sending...
            </button>

            <button
              phx-click="reset"
              class="rounded-md bg-white px-4 py-2 text-sm font-medium text-zinc-700 ring-1 ring-zinc-300 hover:bg-zinc-50"
            >
              Start over
            </button>
          </div>
        </div>

        <div
          :if={@phase == :asana_success}
          class="mt-4 rounded-md bg-green-50 p-4 text-sm text-green-800"
        >
          Task created:
          <a href={@asana_task_url} target="_blank" class="font-medium underline">
            View in Asana →
          </a>
          <button
            phx-click="reset"
            class="ml-4 text-green-700 underline text-sm"
          >
            Run again
          </button>
        </div>
      </div>
    </div>
    """
  end
end
