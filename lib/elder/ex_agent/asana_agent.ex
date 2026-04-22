defmodule Elder.ExAgent.AsanaAgent do
  @moduledoc """
  Spawns an ExAgent agent to create, assign, and tag an Asana task.

  Receives a draft context (task fields) and target (workspace/project/section GIDs),
  configures an ExAgent.Agent with the three Asana tools, and runs a single chat
  turn that lets the LLM decide which tools to call and in what order.
  """

  alias Elder.ExAgent.ExLLMProvider
  alias Elder.ExAgent.Tools.AddTags
  alias Elder.ExAgent.Tools.AssignUser
  alias Elder.ExAgent.Tools.CreateTask

  require Logger

  @type run_result :: {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}

  @doc """
  Runs the Asana agent to create a task from the given draft context and target.

  Starts an ExAgent.Agent GenServer, sends a single user message describing the
  task to create, lets the agent tool-loop until it finishes, then extracts the
  created task GID and URL from the conversation context.

  ## Params
    - `draft_context` — map with `:name`, `:html_notes`, `:due_on`, `:assignee_email`
    - `target` — map with `:workspace_gid`, `:project_gid`, `:section_gid`
    - `opts` — keyword options; `:topic` broadcasts progress events via PubSub
  """
  @spec run(map(), map(), keyword()) :: run_result()
  def run(draft_context, target, opts \\ []) do
    topic = opts[:topic]
    tools = build_tools(topic)
    provider = ExLLMProvider.new(system_prompt: system_prompt(), tools: tools)

    {:ok, agent} = ExAgent.Agent.start_link(provider: provider, tools: tools)

    try do
      user_message = build_user_message(draft_context, target)

      Logger.info("AsanaAgent | run | starting tool loop",
        feature: "ExAgent",
        step: "asana_agent_run"
      )

      case ExAgent.Agent.chat(agent, user_message) do
        {:ok, _response} ->
          extract_result(agent)

        {:error, reason} ->
          Logger.warning("AsanaAgent | run | agent error: #{inspect(reason)}",
            feature: "ExAgent",
            step: "asana_agent_error"
          )

          {:error, reason}
      end
    after
      GenServer.stop(agent)
    end
  end

  @doc false
  @spec system_prompt() :: String.t()
  def system_prompt do
    """
    You are an Asana task creation assistant. You MUST follow this exact sequence:

    1. ALWAYS call create_task first with the provided task details and target GIDs.
    2. If an assignee email is provided, call assign_user with the task GID from step 1.
    3. If tags are mentioned, call add_tags for each tag.
    4. After all tools complete, respond with a brief summary.

    Never skip step 1. The task must be created before any other operations.
    """
  end

  @doc false
  @spec build_user_message(map(), map()) :: String.t()
  def build_user_message(draft_context, target) do
    base = [
      "Create an Asana task with these details:",
      "- name: #{draft_context[:name]}",
      "- html_notes: #{draft_context[:html_notes]}",
      "- workspace_gid: #{target[:workspace_gid]}",
      "- project_gid: #{target[:project_gid]}",
      "- section_gid: #{target[:section_gid]}"
    ]

    optional =
      Enum.reject(
        [
          if(draft_context[:due_on], do: "- due_on: #{draft_context[:due_on]}"),
          if(draft_context[:assignee_email],
            do: "- assignee_email: #{draft_context[:assignee_email]}"
          )
        ],
        &is_nil/1
      )

    Enum.join(base ++ optional, "\n")
  end

  @spec extract_result(GenServer.server()) :: run_result()
  defp extract_result(agent) do
    context = ExAgent.Agent.get_context(agent)

    result =
      context.messages
      |> Enum.filter(&(&1.role == :tool))
      |> Enum.find_value(fn msg -> parse_task_created(msg.content) end)

    if result, do: {:ok, result}, else: {:error, :no_task_created}
  end

  @task_created_regex ~r/Task created: (?<url>\S+) \(GID: (?<gid>[^)]+)\)/

  @spec parse_task_created(String.t()) :: %{task_gid: String.t(), task_url: String.t()} | nil
  defp parse_task_created(content) do
    case Regex.named_captures(@task_created_regex, content) do
      %{"url" => url, "gid" => gid} -> %{task_gid: gid, task_url: url}
      nil -> nil
    end
  end

  defp build_tools(nil), do: [CreateTask.tool(), AssignUser.tool(), AddTags.tool()]

  defp build_tools(topic) do
    Enum.map(
      [CreateTask.tool(), AssignUser.tool(), AddTags.tool()],
      &wrap_with_progress(&1, topic)
    )
  end

  defp wrap_with_progress(%ExAgent.Tool{} = tool, topic) do
    original_fn = tool.function

    wrapped_fn = fn args ->
      broadcast(topic, {:agent_progress, :tool_started, %{tool: tool.name}})
      result = original_fn.(args)
      broadcast(topic, {:agent_progress, :tool_completed, %{tool: tool.name, result: result}})
      result
    end

    %{tool | function: wrapped_fn}
  end

  defp broadcast(topic, event) do
    Phoenix.PubSub.broadcast(Elder.PubSub, topic, event)
  end
end
