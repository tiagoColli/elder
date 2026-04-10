defmodule Elder.LLM.ContextBuilder do
  @moduledoc """
  Builds a `ReqLLM.Context` from a skill definition and user input.
  """

  @doc "Returns a `ReqLLM.Context` with a system prompt from the skill and a user message."
  @spec build(map(), String.t(), keyword()) :: ReqLLM.Context.t()
  def build(skill, user_input, opts \\ []) do
    ReqLLM.Context.new([
      ReqLLM.Context.system(with_context(skill.system_prompt, opts)),
      ReqLLM.Context.user(user_input)
    ])
  end

  @doc "Returns a `ReqLLM.Context` from a skill and a list of conversation turns."
  @spec build_conversation(map(), [%{role: :user | :assistant, text: String.t()}], keyword()) ::
          ReqLLM.Context.t()
  def build_conversation(skill, messages, opts \\ []) do
    turns =
      Enum.map(messages, fn
        %{role: :user, text: text} -> ReqLLM.Context.user(text)
        %{role: :assistant, text: text} -> ReqLLM.Context.assistant(text)
        %{role: role} -> raise ArgumentError, "unsupported role in conversation: #{inspect(role)}"
      end)

    ReqLLM.Context.new([ReqLLM.Context.system(with_context(skill.system_prompt, opts)) | turns])
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
end
