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
  alias Elder.LLM.InterviewResponse
  alias Elder.LLM.InterviewResponseDraft
  alias Elder.Skills
  alias Phoenix.PubSub

  @impl Phoenix.LiveView
  def mount(%{"slug" => slug}, _session, socket) do
    skill = Skills.get_skill!(slug)

    review_skill =
      case skill.review_slug do
        nil -> nil
        review_slug -> Skills.get_skill!(review_slug)
      end

    socket =
      socket
      |> assign(
        page_title: skill.name,
        skill: skill,
        review_skill: review_skill,
        skill_run: nil,
        phase: :idle,
        user_input: "",
        llm_output: "",
        llm_cost: nil,
        asana_task_url: nil,
        error: nil,
        token_count: 0,
        conversation: [],
        chat_loading: false,
        workspaces: [],
        projects: [],
        sections: [],
        selected_workspace_gid: nil,
        selected_project_gid: nil,
        selected_section_gid: nil,
        asana_loading: connected?(socket)
      )
      |> stream(:tokens, [])

    if connected?(socket) do
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
    end

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

    case socket.assigns.review_skill do
      nil ->
        :ok = LLM.stream_run(socket.assigns.skill, input, topic)

        socket =
          socket
          |> assign(phase: :streaming, user_input: input, error: nil, token_count: 0)
          |> stream(:tokens, [], reset: true)

        {:noreply, socket}

      review_skill ->
        conversation = [%{role: :user, text: input}]
        :ok = LLM.interview_run(review_skill, conversation, topic)

        socket =
          assign(socket,
            phase: :chatting,
            conversation: conversation,
            chat_loading: true,
            error: nil
          )

        {:noreply, socket}
    end
  end

  def handle_event("chat_reply", _params, %{assigns: %{chat_loading: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("chat_reply", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("chat_reply", %{"message" => message}, socket) do
    {:noreply, interview_user_message(socket, message)}
  end

  def handle_event("pick_suggestion", _params, %{assigns: %{chat_loading: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("pick_suggestion", %{"message" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("pick_suggestion", %{"message" => message}, socket) do
    {:noreply, interview_user_message(socket, message)}
  end

  def handle_event("pick_suggestion", _params, socket) do
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
        selected_project_gid: nil,
        sections: [],
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
    selected = if gid in [nil, ""], do: nil, else: gid
    {:noreply, assign(socket, selected_section_gid: selected)}
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
        conversation: [],
        chat_loading: false,
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
        socket =
          assign(socket,
            skill_run: skill_run,
            phase: :done,
            llm_output: meta.output,
            llm_cost: meta.cost_usd
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

  def handle_info({:interview_done, {:ok, text}}, socket) do
    case InterviewResponse.parse(text) do
      {:ok, %{status: :ready}} ->
        {:noreply, interview_finish_to_streaming(socket)}

      {:ok, %{status: :continue} = p} ->
        msg = %{
          role: :assistant,
          text: p.assistant_message,
          question: p.question,
          draft: p.draft,
          suggestions: p.suggestions
        }

        conversation = append_conversation_message(socket.assigns.conversation, msg)

        {:noreply, assign(socket, conversation: conversation, chat_loading: false, error: nil)}

      {:error, _parse_error} ->
        if String.trim(text) == "[READY]" do
          {:noreply, interview_finish_to_streaming(socket)}
        else
          {:noreply,
           assign(socket,
             chat_loading: false,
             error: "The assistant reply could not be read. Please try again."
           )}
        end
    end
  end

  def handle_info({:interview_done, {:error, reason}}, socket) do
    {:noreply, assign(socket, chat_loading: false, error: format_llm_error(reason))}
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
    {:noreply, assign(socket, asana_loading: false, error: "Could not load Asana sections")}
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

  defp format_llm_error(_unknown_reason) do
    "Generation failed. Please try again."
  end

  defp interview_user_message(socket, text) do
    topic = "skill_run:#{socket.id}"

    conversation =
      append_conversation_message(socket.assigns.conversation, %{role: :user, text: text})

    :ok = LLM.interview_run(socket.assigns.review_skill, conversation, topic)
    assign(socket, conversation: conversation, chat_loading: true, error: nil)
  end

  defp append_conversation_message(conversation, message) do
    Enum.reverse([message | Enum.reverse(conversation)])
  end

  defp sanitize_llm_output(html) do
    html
    |> String.replace(~r/<body>/i, "")
    |> String.replace(~r/<\/body>/i, "")
    |> String.trim()
  end

  defp interview_finish_to_streaming(socket) do
    topic = "skill_run:#{socket.id}"
    transcript = build_transcript(socket.assigns.conversation)
    :ok = LLM.stream_run(socket.assigns.skill, transcript, topic)

    socket =
      socket
      |> assign(
        phase: :streaming,
        user_input: transcript,
        error: nil,
        token_count: 0,
        chat_loading: false
      )
      |> stream(:tokens, [], reset: true)

    socket
  end

  defp build_transcript(conversation) do
    Enum.map_join(conversation, "\n\n", fn
      %{role: :user, text: text} ->
        "User: #{text}"

      %{role: :assistant, text: text} = msg ->
        base = "Assistant: #{text}"

        base =
          case Map.get(msg, :question) do
            q when is_binary(q) and q != "" -> base <> "\nQuestion: #{q}"
            _no_question -> base
          end

        case msg do
          %{draft: %InterviewResponseDraft{} = d} ->
            case draft_transcript_line(d) do
              nil -> base
              line -> base <> "\n" <> line
            end

          _no_draft ->
            base
        end
    end)
  end

  defp draft_transcript_line(%InterviewResponseDraft{} = d) do
    parts =
      [
        {:title, d.title},
        {:responsible, d.responsible},
        {:description, d.description},
        {:due_date, d.due_date}
      ]
      |> Enum.filter(fn {_key, v} -> present_draft_value?(v) end)
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)

    case parts do
      [] -> nil
      _non_empty -> "Draft — " <> Enum.join(parts, " | ")
    end
  end

  defp present_draft_value?(v) when v in [nil, ""], do: false
  defp present_draft_value?(_present), do: true

  defp format_draft_cell(value) when value in [nil, ""], do: "—"
  defp format_draft_cell(value) when is_binary(value), do: value
  defp format_draft_cell(_other), do: "—"

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto py-10 px-4">
      <div class="mb-8">
        <.link navigate={~p"/skills"} class="text-sm text-muted hover:text-secondary">
          ← Back to Skills
        </.link>
        <h1 class="mt-2 text-2xl font-bold text-primary">{@skill.name}</h1>

        <p class="mt-1 text-sm text-secondary">{@skill.description}</p>
      </div>

      <div :if={@error} class="mb-4 rounded-md bg-red-950/50 p-4 text-sm text-red-400">{@error}</div>

      <div :if={@phase == :idle}>
        <form phx-submit="generate">
          <label class="block text-sm font-medium text-secondary mb-1">Your brief</label>
          <textarea
            name="user_input"
            rows="5"
            placeholder="Describe what you need..."
            class="block w-full rounded-md border-base-border bg-field text-primary placeholder:text-muted text-sm shadow-sm focus:border-accent focus:ring-accent"
          >{@user_input}</textarea>
          <div class="mt-3 flex justify-end">
            <button
              type="submit"
              class="rounded-md bg-accent px-4 py-2 text-sm font-semibold text-white hover:bg-accent/80"
            >
              Generate →
            </button>
          </div>
        </form>
      </div>

      <div :if={@phase == :chatting}>
        <div class="space-y-5 mb-8">
          <div
            :for={msg <- @conversation}
            class={[
              "flex w-full",
              if(msg.role == :user, do: "justify-end", else: "justify-start")
            ]}
          >
            <div
              :if={msg.role == :user}
              class="max-w-[85%] sm:max-w-prose rounded-2xl bg-accent px-4 py-2.5 text-sm text-white shadow-sm leading-relaxed"
            >
              {msg.text}
            </div>

            <div
              :if={
                msg.role == :assistant &&
                  not is_struct(Map.get(msg, :draft), InterviewResponseDraft)
              }
              class="max-w-[85%] sm:max-w-prose rounded-2xl bg-surface-raised px-4 py-2.5 text-sm text-primary shadow-sm leading-relaxed"
            >
              {msg.text}
            </div>

            <div
              :if={
                msg.role == :assistant &&
                  is_struct(Map.get(msg, :draft), InterviewResponseDraft)
              }
              class="w-full max-w-xl rounded-xl border border-base-border bg-surface-raised shadow-md"
            >
              <div class="border-b border-raised-border bg-surface-raised px-4 py-2.5">
                <p class="text-[11px] font-semibold uppercase tracking-widest text-muted">
                  Task brief
                </p>
              </div>

              <div class="px-4 py-3 space-y-3">
                <p class="text-sm text-primary leading-relaxed">{msg.text}</p>

                <div
                  :if={
                    is_binary(Map.get(msg, :question)) &&
                      String.trim(Map.get(msg, :question)) != ""
                  }
                  class="rounded-lg border border-accent/20 bg-accent/10 px-3 py-2.5"
                  data-testid="interview-question"
                >
                  <p class="text-[11px] font-semibold uppercase tracking-wide text-accent-text">
                    Next question
                  </p>

                  <p class="mt-1 text-sm font-medium text-primary leading-snug">
                    {Map.get(msg, :question)}
                  </p>
                </div>

                <dl
                  class="grid grid-cols-1 gap-x-4 gap-y-2.5 border-t border-raised-border pt-3 sm:grid-cols-[6.5rem_1fr] text-sm"
                  data-testid="interview-draft"
                >
                  <dt class="text-xs font-medium uppercase tracking-wide text-muted sm:pt-0.5">
                    Title
                  </dt>

                  <dd class="text-primary leading-snug break-words">
                    {format_draft_cell(msg.draft.title)}
                  </dd>

                  <dt class="text-xs font-medium uppercase tracking-wide text-muted sm:pt-0.5">
                    Owner
                  </dt>

                  <dd class="text-primary leading-snug break-words">
                    {format_draft_cell(msg.draft.responsible)}
                  </dd>

                  <dt class="text-xs font-medium uppercase tracking-wide text-muted sm:pt-0.5">
                    Description
                  </dt>

                  <dd class="text-primary leading-snug break-words">
                    {format_draft_cell(msg.draft.description)}
                  </dd>

                  <dt class="text-xs font-medium uppercase tracking-wide text-muted sm:pt-0.5">
                    Due
                  </dt>

                  <dd class="text-primary leading-snug break-words">
                    {format_draft_cell(msg.draft.due_date)}
                  </dd>
                </dl>
              </div>

              <div
                :if={Map.get(msg, :suggestions, []) != []}
                class="flex flex-wrap gap-2 border-t border-raised-border bg-surface/50 px-4 py-3"
              >
                <button
                  :for={s <- Map.get(msg, :suggestions, [])}
                  type="button"
                  phx-click="pick_suggestion"
                  phx-value-message={s.value}
                  class="rounded-full border border-accent/30 bg-surface px-3.5 py-1.5 text-xs font-medium text-accent-text shadow-sm transition hover:border-accent/50 hover:bg-surface-raised"
                >
                  {s.label}
                </button>
              </div>
            </div>
          </div>

          <div :if={@chat_loading} class="flex justify-start">
            <div class="flex items-center gap-2 rounded-xl border border-base-border bg-surface px-4 py-2.5 text-sm text-muted shadow-sm">
              <span class="animate-spin inline-block w-3.5 h-3.5 border-2 border-accent-text border-t-transparent rounded-full">
              </span>
              Thinking…
            </div>
          </div>
        </div>

        <form
          :if={not @chat_loading}
          phx-submit="chat_reply"
          class="flex flex-col gap-2 sm:flex-row sm:items-stretch"
        >
          <input
            type="text"
            name="message"
            placeholder="Type your reply…"
            autofocus
            class="block w-full rounded-lg border-base-border shadow-sm text-sm focus:border-accent focus:ring-accent sm:min-w-0"
          />
          <button
            type="submit"
            class="shrink-0 rounded-lg bg-accent px-5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-accent/80 sm:w-auto"
          >
            Send
          </button>
        </form>
      </div>

      <div :if={@phase == :streaming}>
        <div class="mb-3 flex items-center gap-2 text-sm text-muted">
          <span class="animate-spin inline-block h-4 w-4 rounded-full border-2 border-accent-text border-t-transparent">
          </span>
          Generating...
        </div>

        <div
          id="token-stream"
          phx-update="stream"
          class="min-h-32 rounded-md border border-base-border bg-surface p-4 font-mono text-sm whitespace-pre-wrap text-primary"
        >
          <span :for={{dom_id, item} <- @streams.tokens} id={dom_id}>{item.text}</span>
        </div>
      </div>

      <div :if={@phase in [:done, :sending_to_asana, :asana_success]}>
        <label class="mb-1 block text-sm font-medium text-secondary">Generated output</label>
        <div class="brief-output prose prose-invert prose-sm max-w-none min-h-40 rounded-md border border-base-border bg-surface-raised p-4">
          {raw(sanitize_llm_output(@llm_output))}
        </div>

        <div :if={@phase in [:done, :sending_to_asana]} class="mt-6 space-y-3">
          <p class="text-sm font-medium text-secondary">Send to Asana</p>

          <div :if={@asana_loading} class="flex items-center gap-2 text-sm text-muted">
            <span class="animate-spin inline-block w-3 h-3 border-2 border-secondary border-t-transparent rounded-full">
            </span>
            Loading...
          </div>

          <div :if={not @asana_loading and @workspaces != []}>
            <label class="block text-xs text-muted mb-1">Workspace</label>
            <form phx-change="select_workspace">
              <select
                name="workspace_gid"
                class="block w-full rounded-md border-base-border text-sm shadow-sm focus:border-accent focus:ring-accent"
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
            <label class="block text-xs text-muted mb-1">Project</label>
            <form phx-change="select_project">
              <select
                name="project_gid"
                class="block w-full rounded-md border-base-border text-sm shadow-sm focus:border-accent focus:ring-accent"
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
            <label class="block text-xs text-muted mb-1">Section</label>
            <form phx-change="select_section">
              <select
                name="section_gid"
                class="block w-full rounded-md border-base-border text-sm shadow-sm focus:border-accent focus:ring-accent"
              >
                <option value="">Select section...</option>

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
              disabled={is_nil(@selected_section_gid)}
              class={[
                "rounded-md px-4 py-2 text-sm font-semibold text-white",
                if(is_nil(@selected_section_gid),
                  do: "cursor-not-allowed bg-green-800/50",
                  else: "bg-green-700 hover:bg-green-600"
                )
              ]}
            >
              Send to Asana →
            </button>
            <button
              :if={@phase == :sending_to_asana}
              disabled
              class="cursor-not-allowed rounded-md bg-green-900/50 px-4 py-2 text-sm font-semibold text-green-300"
            >
              Sending...
            </button>
            <button
              phx-click="reset"
              class="rounded-md bg-surface-raised px-4 py-2 text-sm font-medium text-primary ring-1 ring-raised-border hover:bg-surface"
            >
              Start over
            </button>
          </div>

          <p :if={is_nil(@selected_section_gid)} class="text-xs text-muted">
            Select a workspace, project, and section above before sending.
          </p>
        </div>

        <div
          :if={@phase == :asana_success}
          class="mt-4 rounded-md bg-green-900/30 p-4 text-sm text-green-300"
        >
          Task created:
          <a href={@asana_task_url} target="_blank" class="font-medium underline">View in Asana →</a>
          <button
            phx-click="reset"
            class="ml-4 text-green-400 underline text-sm"
          >
            Run again
          </button>
        </div>
      </div>
    </div>
    """
  end
end
