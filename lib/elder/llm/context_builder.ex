defmodule Elder.LLM.ContextBuilder do
  @moduledoc """
  Builds a `ReqLLM.Context` from a skill definition and user input.
  """

  @doc "Returns a `ReqLLM.Context` with a system prompt from the skill and a user message."
  @spec build(map(), String.t()) :: ReqLLM.Context.t()
  def build(skill, user_input) do
    ReqLLM.Context.new([
      ReqLLM.Context.system(skill.system_prompt),
      ReqLLM.Context.user(user_input)
    ])
  end

  @doc "Returns a `ReqLLM.Context` from a skill and a list of conversation turns."
  @spec build_conversation(map(), [%{role: :user | :assistant, text: String.t()}]) ::
          ReqLLM.Context.t()
  def build_conversation(skill, messages) do
    turns =
      Enum.map(messages, fn
        %{role: :user, text: text} -> ReqLLM.Context.user(text)
        %{role: :assistant, text: text} -> ReqLLM.Context.assistant(text)
        %{role: role} -> raise ArgumentError, "unsupported role in conversation: #{inspect(role)}"
      end)

    ReqLLM.Context.new([ReqLLM.Context.system(skill.system_prompt) | turns])
  end
end
