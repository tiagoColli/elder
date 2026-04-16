defmodule Elder.LLM do
  @moduledoc """
  Public context for LLM interactions.

  Provides streaming and structured generation paths using ExLLM directly.
  """

  require Logger

  @doc """
  Starts a streaming LLM text generation run for the given skill and input.

  Dispatches `{:llm_token, chunk}` messages to `caller` during generation,
  followed by `{:llm_done, meta}` on success or `{:llm_error, reason}` on failure.

  ## Params
    - `skill` - skill map with at minimum `:system_prompt`
    - `user_input` - user input string
    - `opts` - keyword options; `:caller` (pid) required
  """
  @spec stream_run(map(), String.t(), keyword()) :: :ok
  def stream_run(skill, user_input, opts) do
    caller = Keyword.fetch!(opts, :caller)
    slug = Map.get(skill, :slug, "unknown")

    Logger.info("LLM | stream_run | skill:#{slug} model:#{model()} | ok",
      feature: "LLM",
      step: "stream_run",
      cid: slug
    )

    messages = [
      %{role: "system", content: skill.system_prompt},
      %{role: "user", content: user_input}
    ]

    model = model()

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      try do
        run_stream(messages, model, caller)
      rescue
        e ->
          Logger.error("LLM | stream_error | error:#{Exception.message(e)}",
            feature: "LLM",
            step: "stream_error"
          )

          send(caller, {:llm_error, Exception.message(e)})
      end
    end)

    :ok
  end

  @doc """
  Starts a structured object generation run for the given skill and input.

  Dispatches `{:llm_object_done, {:ok, %{object: map(), cost_usd: float(), model: String.t()}}}`
  or `{:llm_object_done, {:error, reason}}` to `caller` on completion.

  ## Params
    - `skill` - skill map with at minimum `:system_prompt`
    - `user_input` - user input string
    - `schema` - JSON Schema map defining the expected object shape
    - `opts` - keyword options; `:caller` (pid) required; `:user_name` and `:inject_context` optional
  """
  @spec structured_run(map(), String.t(), map(), keyword()) :: :ok
  def structured_run(skill, user_input, schema, opts) do
    caller = Keyword.fetch!(opts, :caller)
    slug = Map.get(skill, :slug, "unknown")
    {build_opts, _rest} = Keyword.split(opts, [:inject_context, :user_name])

    Logger.info("LLM | structured_run | skill:#{slug} model:#{model()} | ok",
      feature: "LLM",
      step: "structured_run",
      cid: slug
    )

    system_prompt =
      with_context(skill.system_prompt, Keyword.put_new(build_opts, :inject_context, true))

    schema_instruction =
      "Respond with a JSON object matching this schema:\n#{Jason.encode!(schema)}"

    messages = [
      %{role: "system", content: "#{system_prompt}\n\n#{schema_instruction}"},
      %{role: "user", content: user_input}
    ]

    model = model()

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      try do
        run_structured(messages, model, caller)
      rescue
        e ->
          Logger.error("LLM | structured_run_error | error:#{Exception.message(e)}",
            feature: "LLM",
            step: "structured_run_error"
          )

          send(caller, {:llm_object_done, {:error, Exception.message(e)}})
      end
    end)

    :ok
  end

  # --- Private ---

  defp run_stream(messages, model, caller) do
    case ExLLM.stream_chat(provider(), messages, model: model) do
      {:ok, stream} ->
        full_text =
          Enum.reduce(stream, "", fn chunk, acc ->
            if chunk.content do
              send(caller, {:llm_token, chunk.content})
              acc <> chunk.content
            else
              acc
            end
          end)

        send(caller, {:llm_done, %{output: full_text, cost_usd: 0.0, model: model}})

      {:error, reason} ->
        Logger.error("LLM | stream_error | error:stream",
          feature: "LLM",
          step: "stream_error"
        )

        send(caller, {:llm_error, reason})
    end
  end

  defp run_structured(messages, model, caller) do
    result =
      case ExLLM.chat(provider(), messages, model: model) do
        {:ok, response} ->
          case Jason.decode(response.content) do
            {:ok, object} ->
              cost = if response.cost, do: response.cost.total_cost, else: 0.0
              {:ok, %{object: object, cost_usd: cost, model: model}}

            {:error, _decode_error} ->
              {:error, {:json_parse_error, response.content}}
          end

        {:error, reason} ->
          {:error, reason}
      end

    case result do
      {:ok, %{cost_usd: cost}} ->
        Logger.info("LLM | structured_run_complete | cost_usd:#{cost} | ok",
          feature: "LLM",
          step: "structured_run_complete"
        )

      {:error, _reason} ->
        Logger.error("LLM | structured_run_error | error:structured",
          feature: "LLM",
          step: "structured_run_error"
        )
    end

    send(caller, {:llm_object_done, result})
  end

  defp with_context(system_prompt, opts) do
    date_time_lines =
      if Keyword.get(opts, :inject_context, false) do
        now = DateTime.utc_now()
        date_line = Calendar.strftime(now, "Today is %A, %B %-d, %Y.")
        time_line = Calendar.strftime(now, "Current time: %H:%M UTC.")
        [date_line, time_line]
      else
        []
      end

    user_line =
      case Keyword.get(opts, :user_name) do
        nil -> nil
        name -> "You are assisting #{name}."
      end

    context_lines = Enum.reject([user_line | date_time_lines], &is_nil/1)

    if context_lines == [] do
      system_prompt
    else
      "#{Enum.join(context_lines, " ")}\n\n#{system_prompt}"
    end
  end

  defp provider do
    Application.get_env(:ex_llm, :default_provider, :gemini)
  end

  defp model do
    Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
  end
end
