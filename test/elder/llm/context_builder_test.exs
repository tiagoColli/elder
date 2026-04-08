defmodule Elder.LLM.ContextBuilderTest do
  use ExUnit.Case, async: true

  alias Elder.LLM.ContextBuilder

  describe "build/2" do
    test "returns a ReqLLM.Context struct" do
      skill = %{system_prompt: "You are a helpful project management assistant."}

      context = ContextBuilder.build(skill, "Create a task for the product launch campaign")

      assert %ReqLLM.Context{} = context
    end

    test "context contains exactly two messages" do
      skill = %{system_prompt: "You are a helpful assistant."}

      context = ContextBuilder.build(skill, "Write a brief for the team handover")

      assert length(context.messages) == 2
    end

    test "first message is the system prompt" do
      skill = %{system_prompt: "You are a project management assistant that formats Asana tasks."}

      context = ContextBuilder.build(skill, "Create a handover task for the engineering team")

      [system_msg | _rest] = context.messages
      assert system_msg.role == :system
    end

    test "second message is the user input" do
      skill = %{system_prompt: "You are a helpful assistant."}
      user_input = "Create a task for the Q4 product launch marketing campaign"

      context = ContextBuilder.build(skill, user_input)

      [_system_msg, user_msg] = context.messages
      assert user_msg.role == :user
    end
  end
end
