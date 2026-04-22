defmodule Elder.Interview do
  @moduledoc """
  Thin orchestrator for the interview chat flow.

  Manages the interview lifecycle (start → continue → handle_response → finish)
  by delegating session management to `ExLLM.Session` and LLM calls to
  `ExLLM.chat/3` with `response_model: Elder.Schemas.InterviewResponse`.

  Holds a pure functional state struct — no GenServer. The owning LiveView
  keeps the struct in its socket assigns.
  """

  alias Elder.Asana.Artifacts.Draft
  alias Elder.ExAgent.AsanaAgent
  alias Elder.Schemas.InterviewResponse

  require Logger

  @type status :: :awaiting_llm | :awaiting_user | :completed | :failed

  @type t :: %__MODULE__{
          id: String.t(),
          session: ExLLM.Types.Session.t(),
          skill: map(),
          caller: pid(),
          status: status(),
          draft: Draft.t(),
          turn_data: %{non_neg_integer() => map()},
          error: term() | nil
        }

  @enforce_keys [:id, :session, :skill, :caller]
  defstruct [
    :id,
    :session,
    :skill,
    :caller,
    :error,
    status: :awaiting_llm,
    draft: %Draft{},
    turn_data: %{}
  ]

  @doc """
  Creates a new interview and dispatches the first LLM call.

  Builds an `ExLLM.Session` with the skill's system prompt and the user's
  opening message, then fires an async `ExLLM.chat/3` call. The caller
  receives `{:interview_done, result}` when the LLM responds.

  ## Params
    - `skill` — review skill map with `:system_prompt`
    - `user_prompt` — the user's opening message
    - `opts` — keyword options; `:caller` (pid) required

  ## Returns
    - `{:ok, t()}` on success
  """
  @spec start(map(), String.t(), keyword()) :: {:ok, t()}
  def start(skill, user_prompt, opts \\ []) do
    caller = Keyword.fetch!(opts, :caller)
    id = Ecto.UUID.generate()

    session =
      :gemini
      |> ExLLM.new_session(name: "interview-#{id}")
      |> ExLLM.add_session_message("system", skill.system_prompt)
      |> ExLLM.add_session_message("user", user_prompt)

    interview = %__MODULE__{
      id: id,
      session: session,
      skill: skill,
      caller: caller
    }

    Logger.info("Interview | start | interview:#{id} | ok",
      feature: "Interview",
      step: "start",
      cid: id
    )

    dispatch_chat(interview)

    {:ok, interview}
  end

  @doc """
  Adds a user reply and dispatches the next LLM call.

  ## Returns
    - `{:ok, t()}` with status `:awaiting_llm`
    - `{:error, :not_awaiting_user}` if the interview isn't waiting for user input
  """
  @spec continue(t(), String.t()) :: {:ok, t()} | {:error, :not_awaiting_user}
  def continue(%__MODULE__{status: :awaiting_user} = interview, user_text) do
    session = ExLLM.add_session_message(interview.session, "user", user_text)
    updated = %{interview | session: session, status: :awaiting_llm}

    Logger.info("Interview | continue | interview:#{interview.id} | ok",
      feature: "Interview",
      step: "continue",
      cid: interview.id
    )

    dispatch_chat(updated)

    {:ok, updated}
  end

  def continue(%__MODULE__{}, _user_text), do: {:error, :not_awaiting_user}

  @doc """
  Processes an `InterviewResponse` from the LLM.

  Adds the assistant message to the session, merges draft fields, stores
  turn metadata, and transitions the status based on `response.status`.

  ## Returns
    - `{:ok, t(), :continue}` when the interview should continue
    - `{:ok, t(), :ready}` when the draft is complete
    - `{:error, t(), :not_awaiting_llm}` if the interview isn't waiting for LLM
  """
  @spec handle_response(t(), InterviewResponse.t()) ::
          {:ok, t(), :continue | :ready} | {:error, t(), :not_awaiting_llm}
  def handle_response(
        %__MODULE__{status: :awaiting_llm} = interview,
        %InterviewResponse{} = response
      ) do
    session =
      ExLLM.add_session_message(interview.session, "assistant", response.assistant_message)

    draft = merge_draft(interview.draft, response.draft)
    msg_index = length(ExLLM.get_session_messages(session)) - 1

    turn_entry = %{
      question: response.question,
      suggestions: response.suggestions || [],
      draft: draft
    }

    updated = %{
      interview
      | session: session,
        status: :awaiting_user,
        draft: draft,
        turn_data: Map.put(interview.turn_data, msg_index, turn_entry)
    }

    Logger.info("Interview | handle_response | interview:#{interview.id} | #{response.status}",
      feature: "Interview",
      step: "handle_response",
      cid: interview.id
    )

    {:ok, updated, response.status}
  end

  def handle_response(%__MODULE__{} = interview, _response) do
    {:error, interview, :not_awaiting_llm}
  end

  @doc """
  Records an error and transitions the interview to `:failed`.

  ## Returns
    - `{:ok, t()}` with status `:failed`
  """
  @spec handle_error(t(), term()) :: {:ok, t()}
  def handle_error(%__MODULE__{} = interview, reason) do
    Logger.warning(
      "Interview | handle_error | interview:#{interview.id} | error:interview_failed",
      feature: "Interview",
      step: "handle_error",
      cid: interview.id,
      reason: reason
    )

    {:ok, %{interview | status: :failed, error: reason}}
  end

  @doc """
  Completes the interview and returns a transcript.

  ## Returns
    - `{:ok, t(), String.t()}` with status `:completed` and a transcript
    - `{:error, :not_awaiting_user}` if the interview isn't in the right state
  """
  @spec finish(t()) :: {:ok, t(), String.t()} | {:error, :not_awaiting_user}
  def finish(%__MODULE__{status: :awaiting_user} = interview) do
    transcript = build_transcript(interview.session)

    Logger.info("Interview | finish | interview:#{interview.id} | ok",
      feature: "Interview",
      step: "finish",
      cid: interview.id
    )

    {:ok, %{interview | status: :completed}, transcript}
  end

  def finish(%__MODULE__{}), do: {:error, :not_awaiting_user}

  @doc """
  Returns enriched messages for rendering in the LiveView.

  Each message has `:role` (atom), `:text`, `:question`, `:suggestions`,
  and `:artifacts` matching the shape `SkillRunLive` expects.
  """
  @spec messages(t()) :: [map()]
  def messages(%__MODULE__{} = interview) do
    interview.session
    |> ExLLM.get_session_messages()
    |> Enum.with_index()
    |> Enum.map(fn {msg, idx} -> enrich_message(msg, idx, interview.turn_data) end)
  end

  @doc """
  Adds an assistant feedback message without dispatching an LLM call.

  Used for re-prompting (e.g. missing required fields) while preserving
  the current draft in turn_data for rendering.
  """
  @spec inject_feedback(t(), String.t()) :: t()
  def inject_feedback(%__MODULE__{status: :awaiting_user} = interview, message) do
    session = ExLLM.add_session_message(interview.session, "assistant", message)
    msg_index = length(ExLLM.get_session_messages(session)) - 1

    turn_entry = %{
      question: nil,
      suggestions: [],
      draft: interview.draft
    }

    %{
      interview
      | session: session,
        turn_data: Map.put(interview.turn_data, msg_index, turn_entry)
    }
  end

  @doc """
  Returns `true` if the interview is waiting for user input.
  """
  @spec awaiting_user?(t()) :: boolean()
  def awaiting_user?(%__MODULE__{status: :awaiting_user}), do: true
  def awaiting_user?(%__MODULE__{}), do: false

  @doc """
  Spawns an ExAgent agent to execute the Asana task from the completed draft.

  Runs under `Elder.LLM.TaskSupervisor` and sends `{:execution_done, result}`
  to the interview's `caller` when the agent finishes.

  Only callable when the interview status is `:completed`.

  ## Params
    - `interview` — a completed interview with a populated draft
    - `target` — map with `:workspace_gid`, `:project_gid`, `:section_gid`
  """
  @spec execute(t(), map()) :: :ok | {:error, :not_completed}
  def execute(%__MODULE__{status: :completed, draft: draft, caller: caller} = interview, target) do
    draft_context = draft_to_context(draft)
    topic = agent_topic(interview.id)

    Logger.info("Interview | execute | interview:#{interview.id} | spawning agent",
      feature: "Interview",
      step: "execute",
      cid: interview.id
    )

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      result = AsanaAgent.run(draft_context, target, topic: topic)
      send(caller, {:execution_done, result})
    end)

    :ok
  end

  def execute(%__MODULE__{}, _target), do: {:error, :not_completed}

  @doc false
  @spec agent_topic(String.t()) :: String.t()
  def agent_topic(interview_id), do: "agent:#{interview_id}"

  @doc false
  @spec draft_to_context(Draft.t()) :: map()
  def draft_to_context(%Draft{} = draft) do
    %{
      name: draft.name,
      html_notes: wrap_html_notes(draft.description),
      due_on: draft.due_on,
      assignee_email: draft.responsible_email
    }
  end

  # --- Private ---

  defp dispatch_chat(%__MODULE__{} = interview) do
    if dispatch_enabled?() do
      caller = interview.caller
      session = interview.session
      interview_id = interview.id

      Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
        try do
          messages = ExLLM.get_session_messages(session)
          result = ExLLM.chat(provider(), messages, chat_opts())
          send(caller, {:interview_done, result})
        rescue
          e ->
            Logger.error(
              "Interview | dispatch_error | interview:#{interview_id} | error:#{Exception.message(e)}",
              feature: "Interview",
              step: "dispatch_error",
              cid: interview_id,
              reason: Exception.message(e)
            )

            send(caller, {:interview_done, {:error, Exception.message(e)}})
        end
      end)
    end
  end

  defp dispatch_enabled? do
    Application.get_env(:elder, __MODULE__, [])[:dispatch_enabled] != false
  end

  defp provider do
    Application.get_env(:ex_llm, :default_provider, :gemini)
  end

  defp chat_opts do
    [
      response_model: InterviewResponse,
      max_retries: 2,
      strategy: :sliding_window,
      preserve_messages: 6
    ]
  end

  defp merge_draft(%Draft{} = acc, nil), do: acc

  defp merge_draft(%Draft{} = acc, %InterviewResponse.Draft{} = new) do
    %Draft{
      name: new.name || acc.name,
      description: new.description || acc.description,
      due_on: new.due_on || acc.due_on,
      responsible_email: new.responsible_email || acc.responsible_email,
      skipped_fields: non_empty_list(new.skipped_fields, acc.skipped_fields)
    }
  end

  defp non_empty_list([], fallback), do: fallback
  defp non_empty_list(list, _fallback) when is_list(list), do: list
  defp non_empty_list(_other, fallback), do: fallback

  defp build_transcript(session) do
    session
    |> ExLLM.get_session_messages()
    |> Enum.reject(fn msg -> msg.role == "system" end)
    |> Enum.map_join("\n\n", fn msg ->
      label = if msg.role == "user", do: "User", else: "Assistant"
      "#{label}: #{msg.content}"
    end)
  end

  defp enrich_message(msg, idx, turn_data) do
    role = role_atom(msg.role)
    base = %{role: role, text: msg.content, question: nil, suggestions: [], artifacts: []}

    case Map.get(turn_data, idx) do
      nil ->
        base

      turn ->
        %{
          base
          | question: turn.question,
            suggestions: turn.suggestions,
            artifacts: if(turn.draft, do: [turn.draft], else: [])
        }
    end
  end

  defp role_atom("system"), do: :system
  defp role_atom("user"), do: :user
  defp role_atom("assistant"), do: :assistant
  defp role_atom("tool"), do: :tool

  defp wrap_html_notes(nil), do: "<body></body>"

  defp wrap_html_notes(description) do
    if String.starts_with?(description, "<body>"),
      do: description,
      else: "<body>#{description}</body>"
  end
end
