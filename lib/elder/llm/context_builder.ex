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
end
