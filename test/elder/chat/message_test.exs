defmodule Elder.Chat.MessageTest do
  use ExUnit.Case, async: true

  alias Elder.Chat.Message

  describe "new_user/1" do
    test "returns ok with a user message for valid text" do
      assert {:ok, %Message{} = msg} = Message.new_user("Launch the Q4 campaign")

      assert msg.role == :user
      assert msg.text == "Launch the Q4 campaign"
      assert is_binary(msg.id)
      assert %DateTime{} = msg.inserted_at
      assert msg.question == nil
      assert msg.suggestions == []
      assert msg.artifacts == []
    end

    test "returns error for empty string" do
      assert {:error, :empty_text} = Message.new_user("")
    end

    test "returns error for nil" do
      assert {:error, :empty_text} = Message.new_user(nil)
    end

    test "returns error for non-binary input" do
      assert {:error, :empty_text} = Message.new_user(123)
    end

    test "generates unique IDs for each message" do
      {:ok, msg1} = Message.new_user("First message")
      {:ok, msg2} = Message.new_user("Second message")

      assert msg1.id != msg2.id
    end
  end

  describe "new_assistant/2" do
    test "returns ok with an assistant message for valid text" do
      assert {:ok, %Message{} = msg} = Message.new_assistant("Here is the draft")

      assert msg.role == :assistant
      assert msg.text == "Here is the draft"
      assert is_binary(msg.id)
      assert %DateTime{} = msg.inserted_at
    end

    test "accepts question option" do
      {:ok, msg} = Message.new_assistant("Got it.", question: "Who should own this task?")

      assert msg.question == "Who should own this task?"
    end

    test "accepts suggestions option" do
      suggestions = [
        %{label: "Skip", value: "skip this field"},
        %{label: "Use default", value: "use default value"}
      ]

      {:ok, msg} = Message.new_assistant("Choose one:", suggestions: suggestions)

      assert msg.suggestions == suggestions
    end

    test "accepts artifacts option" do
      artifact = %{type: :draft, name: "Campaign brief"}

      {:ok, msg} = Message.new_assistant("Draft ready.", artifacts: [artifact])

      assert msg.artifacts == [artifact]
    end

    test "defaults optional fields when not provided" do
      {:ok, msg} = Message.new_assistant("Simple response")

      assert msg.question == nil
      assert msg.suggestions == []
      assert msg.artifacts == []
    end

    test "returns error for empty string" do
      assert {:error, :empty_text} = Message.new_assistant("")
    end

    test "returns error for nil text" do
      assert {:error, :empty_text} = Message.new_assistant(nil)
    end

    test "returns error for non-binary text with options" do
      assert {:error, :empty_text} = Message.new_assistant(42, question: "What?")
    end
  end

  describe "new_system/1" do
    test "returns ok with a system message for valid text" do
      assert {:ok, %Message{} = msg} = Message.new_system("You are a helpful assistant")

      assert msg.role == :system
      assert msg.text == "You are a helpful assistant"
      assert is_binary(msg.id)
      assert %DateTime{} = msg.inserted_at
    end

    test "returns error for empty string" do
      assert {:error, :empty_text} = Message.new_system("")
    end

    test "returns error for nil" do
      assert {:error, :empty_text} = Message.new_system(nil)
    end
  end
end
