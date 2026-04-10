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

    test "system prompt content includes user_name when opt is provided" do
      skill = %{system_prompt: "You are a helpful assistant."}

      context =
        ContextBuilder.build(skill, "Brief me on the campaign", user_name: "Alice Cardoso")

      [system_msg | _rest] = context.messages
      system_text = Enum.map_join(system_msg.content, & &1.text)
      assert String.contains?(system_text, "Alice Cardoso")
    end

    test "system prompt does not include date/time by default" do
      skill = %{system_prompt: "You are a helpful assistant."}

      context = ContextBuilder.build(skill, "Create a task brief")

      [system_msg | _rest] = context.messages
      system_text = Enum.map_join(system_msg.content, & &1.text)
      refute String.contains?(system_text, "Today is")
      refute String.contains?(system_text, "UTC")
    end

    test "system prompt includes date/time when inject_context is true" do
      skill = %{system_prompt: "You are a helpful assistant."}

      context = ContextBuilder.build(skill, "Create a task brief", inject_context: true)

      [system_msg | _rest] = context.messages
      system_text = Enum.map_join(system_msg.content, & &1.text)
      assert String.contains?(system_text, "Today is")
      assert String.contains?(system_text, "UTC")
    end
  end

  describe "build_conversation/2" do
    test "returns a ReqLLM.Context struct" do
      skill = %{system_prompt: "You are a project management assistant."}
      messages = [%{role: :user, text: "I need a task for the product launch."}]

      context = ContextBuilder.build_conversation(skill, messages)

      assert %ReqLLM.Context{} = context
    end

    test "context has system message plus one message per conversation turn" do
      skill = %{system_prompt: "You are a helpful assistant."}

      messages = [
        %{role: :user, text: "Set up a task for the new feature rollout."},
        %{role: :assistant, text: "Sure, what's the deadline?"},
        %{role: :user, text: "End of next month."}
      ]

      context = ContextBuilder.build_conversation(skill, messages)

      assert length(context.messages) == 4
    end

    test "first message is always the system prompt" do
      skill = %{system_prompt: "You are a project management assistant."}
      messages = [%{role: :user, text: "Create a task."}]

      context = ContextBuilder.build_conversation(skill, messages)

      [system_msg | _rest] = context.messages
      assert system_msg.role == :system
    end

    test "user role maps to user message" do
      skill = %{system_prompt: "You are a helpful assistant."}
      messages = [%{role: :user, text: "Schedule the onboarding session."}]

      context = ContextBuilder.build_conversation(skill, messages)

      [_system, user_msg] = context.messages
      assert user_msg.role == :user
    end

    test "assistant role maps to assistant message" do
      skill = %{system_prompt: "You are a helpful assistant."}

      messages = [
        %{role: :user, text: "Set up a campaign task."},
        %{role: :assistant, text: "Got it. What's the title?"}
      ]

      context = ContextBuilder.build_conversation(skill, messages)

      [_system, _user, assistant_msg] = context.messages
      assert assistant_msg.role == :assistant
    end

    test "raises ArgumentError for unsupported role" do
      skill = %{system_prompt: "You are a helpful assistant."}
      messages = [%{role: :moderator, text: "Invalid role."}]

      assert_raise ArgumentError, ~r/unsupported role/, fn ->
        ContextBuilder.build_conversation(skill, messages)
      end
    end

    test "empty conversation returns only the system message" do
      skill = %{system_prompt: "You are a helpful assistant."}

      context = ContextBuilder.build_conversation(skill, [])

      assert length(context.messages) == 1
      [system_msg] = context.messages
      assert system_msg.role == :system
    end
  end
end
