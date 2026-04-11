defmodule Elder.Chat.ConversationTest do
  use ExUnit.Case, async: true

  alias Elder.Chat.Conversation

  describe "new/1" do
    test "returns ok with default values" do
      assert {:ok, %Conversation{} = conv} = Conversation.new()

      assert is_binary(conv.id)
      assert %DateTime{} = conv.started_at
      assert conv.status == :active
      assert conv.finished_at == nil
      assert conv.turn_count == 0
      assert conv.messages == []
      assert conv.context == %{}
    end

    test "accepts context option" do
      ctx = %{user_name: "Maria Silva", skill_slug: "create-asana-task"}

      assert {:ok, %Conversation{} = conv} = Conversation.new(context: ctx)

      assert conv.context == ctx
    end
  end

  describe "add_user_message/2" do
    test "appends user message and increments turn count" do
      {:ok, conv} = Conversation.new()

      assert {:ok, %Conversation{} = updated} =
               Conversation.add_user_message(conv, "Create a campaign brief")

      assert updated.turn_count == 1
      assert length(updated.messages) == 1

      [msg] = updated.messages
      assert msg.role == :user
      assert msg.text == "Create a campaign brief"
    end

    test "appends multiple user messages sequentially" do
      {:ok, conv} = Conversation.new()
      {:ok, after_first} = Conversation.add_user_message(conv, "First request")
      {:ok, after_second} = Conversation.add_user_message(after_first, "Follow-up detail")

      assert after_second.turn_count == 2
      assert length(after_second.messages) == 2
    end

    test "returns error when conversation is completed" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.complete(conv)

      assert {:error, :conversation_finished} =
               Conversation.add_user_message(done, "Too late")
    end

    test "returns error when conversation is failed" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.fail(conv)

      assert {:error, :conversation_finished} =
               Conversation.add_user_message(done, "Too late")
    end

    test "returns error when conversation is cancelled" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.cancel(conv)

      assert {:error, :conversation_finished} =
               Conversation.add_user_message(done, "Too late")
    end

    test "returns error for empty text" do
      {:ok, conv} = Conversation.new()

      assert {:error, :empty_text} = Conversation.add_user_message(conv, "")
    end
  end

  describe "add_assistant_message/3" do
    test "appends assistant message without incrementing turn count" do
      {:ok, conv} = Conversation.new()
      {:ok, after_user} = Conversation.add_user_message(conv, "Help me")

      assert {:ok, %Conversation{} = updated} =
               Conversation.add_assistant_message(after_user, "Sure, here is the draft")

      assert updated.turn_count == 1
      assert length(updated.messages) == 2
      assert List.last(Conversation.messages(updated)).role == :assistant
    end

    test "passes options through to message" do
      {:ok, conv} = Conversation.new()

      {:ok, updated} =
        Conversation.add_assistant_message(conv, "Got it.",
          question: "Who owns it?",
          suggestions: [%{label: "Me", value: "I will own it"}]
        )

      msg = Conversation.last_message(updated)
      assert msg.question == "Who owns it?"
      assert length(msg.suggestions) == 1
    end

    test "returns error when conversation is finished" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.complete(conv)

      assert {:error, :conversation_finished} =
               Conversation.add_assistant_message(done, "Response")
    end

    test "returns error for empty text" do
      {:ok, conv} = Conversation.new()

      assert {:error, :empty_text} = Conversation.add_assistant_message(conv, "")
    end
  end

  describe "add_system_message/2" do
    test "appends system message" do
      {:ok, conv} = Conversation.new()

      assert {:ok, %Conversation{} = updated} =
               Conversation.add_system_message(conv, "You are a task creation assistant")

      assert length(updated.messages) == 1
      assert hd(updated.messages).role == :system
    end

    test "returns error when conversation is finished" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.fail(conv)

      assert {:error, :conversation_finished} =
               Conversation.add_system_message(done, "System prompt")
    end

    test "returns error for empty text" do
      {:ok, conv} = Conversation.new()

      assert {:error, :empty_text} = Conversation.add_system_message(conv, "")
    end
  end

  describe "complete/1" do
    test "transitions active conversation to completed with finished_at" do
      {:ok, conv} = Conversation.new()

      assert {:ok, %Conversation{} = completed} = Conversation.complete(conv)

      assert completed.status == :completed
      assert %DateTime{} = completed.finished_at
    end

    test "returns error when already completed" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.complete(conv)

      assert {:error, :already_finished} = Conversation.complete(done)
    end

    test "returns error when already failed" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.fail(conv)

      assert {:error, :already_finished} = Conversation.complete(done)
    end

    test "returns error when already cancelled" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.cancel(conv)

      assert {:error, :already_finished} = Conversation.complete(done)
    end
  end

  describe "fail/1" do
    test "transitions active conversation to failed" do
      {:ok, conv} = Conversation.new()

      assert {:ok, %Conversation{} = failed} = Conversation.fail(conv)

      assert failed.status == :failed
      assert %DateTime{} = failed.finished_at
    end

    test "returns error when already in terminal state" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.complete(conv)

      assert {:error, :already_finished} = Conversation.fail(done)
    end
  end

  describe "cancel/1" do
    test "transitions active conversation to cancelled" do
      {:ok, conv} = Conversation.new()

      assert {:ok, %Conversation{} = cancelled} = Conversation.cancel(conv)

      assert cancelled.status == :cancelled
      assert %DateTime{} = cancelled.finished_at
    end

    test "returns error when already in terminal state" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.fail(conv)

      assert {:error, :already_finished} = Conversation.cancel(done)
    end
  end

  describe "active?/1" do
    test "returns true for active conversation" do
      {:ok, conv} = Conversation.new()

      assert Conversation.active?(conv) == true
    end

    test "returns false for completed conversation" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.complete(conv)

      assert Conversation.active?(done) == false
    end

    test "returns false for failed conversation" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.fail(conv)

      assert Conversation.active?(done) == false
    end

    test "returns false for cancelled conversation" do
      {:ok, conv} = Conversation.new()
      {:ok, done} = Conversation.cancel(conv)

      assert Conversation.active?(done) == false
    end
  end

  describe "messages/1" do
    test "returns empty list for new conversation" do
      {:ok, conv} = Conversation.new()

      assert Conversation.messages(conv) == []
    end

    test "returns all messages in order" do
      {:ok, conv} = Conversation.new()
      {:ok, after_user} = Conversation.add_user_message(conv, "Hello")
      {:ok, after_assistant} = Conversation.add_assistant_message(after_user, "Hi there")

      msgs = Conversation.messages(after_assistant)
      assert length(msgs) == 2
      assert Enum.at(msgs, 0).role == :user
      assert Enum.at(msgs, 1).role == :assistant
    end
  end

  describe "last_message/1" do
    test "returns nil for empty conversation" do
      {:ok, conv} = Conversation.new()

      assert Conversation.last_message(conv) == nil
    end

    test "returns the most recent message" do
      {:ok, conv} = Conversation.new()
      {:ok, after_first} = Conversation.add_user_message(conv, "First")
      {:ok, after_second} = Conversation.add_assistant_message(after_first, "Second")

      msg = Conversation.last_message(after_second)
      assert msg.text == "Second"
      assert msg.role == :assistant
    end
  end

  describe "messages_by_role/2" do
    test "filters messages by user role" do
      {:ok, conv} = Conversation.new()
      {:ok, after_system} = Conversation.add_system_message(conv, "System prompt")
      {:ok, after_user_1} = Conversation.add_user_message(after_system, "User request")
      {:ok, after_assistant} = Conversation.add_assistant_message(after_user_1, "Assistant reply")
      {:ok, after_user_2} = Conversation.add_user_message(after_assistant, "Follow-up")

      user_msgs = Conversation.messages_by_role(after_user_2, :user)
      assert length(user_msgs) == 2
      assert Enum.all?(user_msgs, &(&1.role == :user))
    end

    test "returns empty list when no messages match the role" do
      {:ok, conv} = Conversation.new()
      {:ok, after_user} = Conversation.add_user_message(conv, "Only user message")

      assert Conversation.messages_by_role(after_user, :system) == []
    end
  end

  describe "to_llm_messages/1" do
    test "maps messages to role/text maps" do
      {:ok, conv} = Conversation.new()
      {:ok, after_system} = Conversation.add_system_message(conv, "Be helpful")
      {:ok, after_user} = Conversation.add_user_message(after_system, "Create a task")

      llm_msgs = Conversation.to_llm_messages(after_user)
      assert length(llm_msgs) == 2

      assert Enum.at(llm_msgs, 0).role == :system
      assert Enum.at(llm_msgs, 0).text == "Be helpful"
      assert Enum.at(llm_msgs, 1).role == :user
      assert Enum.at(llm_msgs, 1).text == "Create a task"
    end

    test "appends question to message text when present" do
      {:ok, conv} = Conversation.new()

      {:ok, updated} =
        Conversation.add_assistant_message(conv, "Got it.", question: "Who owns this?")

      [llm_msg] = Conversation.to_llm_messages(updated)
      assert llm_msg.text =~ "Got it."
      assert llm_msg.text =~ "Question: Who owns this?"
    end

    test "appends artifact transcript when artifact implements to_transcript" do
      {:ok, conv} = Conversation.new()

      draft = %Elder.Asana.Artifacts.Draft{
        name: "Q4 Campaign",
        description: "Full campaign details"
      }

      {:ok, updated} =
        Conversation.add_assistant_message(conv, "Here is the draft.", artifacts: [draft])

      [llm_msg] = Conversation.to_llm_messages(updated)
      assert llm_msg.text =~ "Here is the draft."
      assert llm_msg.text =~ "Q4 Campaign"
    end
  end

  describe "to_transcript/1" do
    test "formats messages with role prefixes" do
      {:ok, conv} = Conversation.new()
      {:ok, after_system} = Conversation.add_system_message(conv, "Be a task assistant")
      {:ok, after_user} = Conversation.add_user_message(after_system, "Create a brief")
      {:ok, after_assistant} = Conversation.add_assistant_message(after_user, "Here is the draft")

      transcript = Conversation.to_transcript(after_assistant)

      assert transcript =~ "System: Be a task assistant"
      assert transcript =~ "User: Create a brief"
      assert transcript =~ "Assistant: Here is the draft"
    end

    test "returns empty string for empty conversation" do
      {:ok, conv} = Conversation.new()

      assert Conversation.to_transcript(conv) == ""
    end

    test "includes question in assistant transcript" do
      {:ok, conv} = Conversation.new()

      {:ok, updated} =
        Conversation.add_assistant_message(conv, "Got it.", question: "What is the due date?")

      transcript = Conversation.to_transcript(updated)
      assert transcript =~ "Question: What is the due date?"
    end

    test "includes artifact transcript for assistant messages" do
      {:ok, conv} = Conversation.new()

      draft = %Elder.Asana.Artifacts.Draft{
        name: "Annual Report",
        description: "Comprehensive annual report",
        responsible_email: "owner@company.com"
      }

      {:ok, updated} =
        Conversation.add_assistant_message(conv, "Draft ready.", artifacts: [draft])

      transcript = Conversation.to_transcript(updated)
      assert transcript =~ "Draft —"
      assert transcript =~ "Annual Report"
    end
  end
end
