defmodule Elder.Chat.SessionTest do
  use ExUnit.Case, async: false

  import Mox

  alias Elder.Chat.Conversation
  alias Elder.Chat.Session

  setup :set_mox_global
  setup :verify_on_exit!

  @review_skill %{system_prompt: "You are a helpful task assistant."}

  defp stub_llm_call do
    stub(Elder.LLM.ClientMock, :call, fn _context, _model, _opts -> :ok end)
  end

  defp handler_continue do
    fn _text ->
      {:continue,
       %{
         text: "Got the title. Who should own it?",
         question: "Who is the owner?",
         suggestions: [],
         artifacts: []
       }}
    end
  end

  defp handler_ready do
    fn _text -> {:ready, %{text: "All set.", artifacts: []}} end
  end

  defp handler_error(reason) do
    fn _text -> {:error, reason} end
  end

  defp make_awaiting_llm_session(opts \\ []) do
    {:ok, new_conversation} = Conversation.new()

    {:ok, updated_conversation} =
      Conversation.add_user_message(new_conversation, "Create a campaign brief")

    handler = Keyword.get(opts, :response_handler, handler_continue())

    %Session{
      id: Ecto.UUID.generate(),
      conversation: updated_conversation,
      review_skill: @review_skill,
      caller: self(),
      response_handler: handler,
      status: :awaiting_llm
    }
  end

  defp make_awaiting_user_session(opts \\ []) do
    session = make_awaiting_llm_session(opts)
    %{session | status: :awaiting_user}
  end

  describe "start/4" do
    test "returns ok with session in awaiting_llm status" do
      stub_llm_call()

      assert {:ok, %Session{} = session} =
               Session.start(@review_skill, "Create a task for the Q4 campaign", handler_ready(),
                 caller: self()
               )

      assert session.status == :awaiting_llm
      assert session.review_skill == @review_skill
      assert session.caller == self()
      assert is_binary(session.id)
    end

    test "session conversation contains the initial user message" do
      stub_llm_call()

      {:ok, session} =
        Session.start(@review_skill, "Prepare a handover document", handler_ready(),
          caller: self()
        )

      [msg] = Session.messages(session)
      assert msg.role == :user
      assert msg.text == "Prepare a handover document"
    end

    test "raises when :caller option is missing" do
      assert_raise KeyError, fn ->
        Session.start(@review_skill, "Some input", handler_ready(), [])
      end
    end

    test "calls interview_run with the caller pid" do
      expect(Elder.LLM.ClientMock, :call, fn _context, _model, opts ->
        assert Keyword.fetch!(opts, :caller) == self()
        :ok
      end)

      assert {:ok, _session} =
               Session.start(@review_skill, "Create an audit log task", handler_ready(),
                 caller: self()
               )
    end
  end

  describe "continue/2" do
    test "adds user reply, calls interview_run, and returns session in awaiting_llm" do
      expect(Elder.LLM.ClientMock, :call, fn _context, _model, _opts -> :ok end)

      session = make_awaiting_user_session()

      assert {:ok, updated} = Session.continue(session, "Engineering team, due next Friday")

      assert updated.status == :awaiting_llm

      user_messages = Enum.filter(Session.messages(updated), &(&1.role == :user))
      assert Enum.any?(user_messages, &(&1.text == "Engineering team, due next Friday"))
    end

    test "returns error when status is awaiting_llm" do
      session = make_awaiting_llm_session()

      assert {:error, :not_awaiting_user} = Session.continue(session, "Some reply")
    end

    test "returns error when session is failed" do
      session = make_awaiting_llm_session()
      {:ok, failed} = Session.handle_error(session, :some_reason)

      assert {:error, :not_awaiting_user} = Session.continue(failed, "Try again")
    end
  end

  describe "handle_response/2" do
    test "returns :continue signal and session in awaiting_user when handler returns continue" do
      session = make_awaiting_llm_session(response_handler: handler_continue())

      assert {:ok, updated, :continue} = Session.handle_response(session, "some raw text")

      assert updated.status == :awaiting_user

      last_msg =
        updated
        |> Session.messages()
        |> List.last()

      assert last_msg.role == :assistant
      assert last_msg.text == "Got the title. Who should own it?"
    end

    test "returns :ready signal and session in awaiting_user when handler returns ready" do
      session = make_awaiting_llm_session(response_handler: handler_ready())

      assert {:ok, updated, :ready} = Session.handle_response(session, "[READY]")

      assert updated.status == :awaiting_user
    end

    test "uses default Ready text when handler ready response has no :text key" do
      session =
        make_awaiting_llm_session(
          response_handler: fn _response -> {:ready, %{artifacts: []}} end
        )

      {:ok, updated, :ready} = Session.handle_response(session, "[READY]")

      last_msg =
        updated
        |> Session.messages()
        |> List.last()

      assert last_msg.text == "Ready."
    end

    test "returns error with failed session and reason when handler returns error" do
      session =
        make_awaiting_llm_session(response_handler: handler_error(:invalid_interview_json))

      assert {:error, failed_session, :invalid_interview_json} =
               Session.handle_response(session, "bad json")

      assert failed_session.status == :failed
      assert failed_session.error == :invalid_interview_json
    end

    test "returns error when session is not in awaiting_llm status" do
      session = make_awaiting_user_session()

      assert {:error, ^session, :not_awaiting_llm} =
               Session.handle_response(session, "some text")
    end
  end

  describe "handle_error/2" do
    test "marks session as failed with the given reason" do
      session = make_awaiting_llm_session()

      assert {:ok, failed} = Session.handle_error(session, :upstream_timeout)

      assert failed.status == :failed
      assert failed.error == :upstream_timeout
    end

    test "marks session as failed even when conversation is already in a terminal state" do
      session = make_awaiting_llm_session()
      {:ok, first_failure} = Session.handle_error(session, :first_error)

      assert {:ok, second_failure} = Session.handle_error(first_failure, :second_error)

      assert second_failure.status == :failed
      assert second_failure.error == :second_error
    end
  end

  describe "finish/1" do
    test "completes session and returns a transcript string when awaiting_user" do
      session = make_awaiting_user_session()

      assert {:ok, completed, transcript} = Session.finish(session)

      assert completed.status == :completed
      assert is_binary(transcript)
    end

    test "returns error when status is awaiting_llm" do
      session = make_awaiting_llm_session()

      assert {:error, :not_awaiting_user} = Session.finish(session)
    end

    test "returns error when status is failed" do
      session = make_awaiting_llm_session()
      {:ok, failed} = Session.handle_error(session, :reason)

      assert {:error, :not_awaiting_user} = Session.finish(failed)
    end
  end

  describe "messages/1" do
    test "returns messages from the conversation" do
      session = make_awaiting_llm_session()

      msgs = Session.messages(session)

      assert length(msgs) == 1
      assert hd(msgs).role == :user
    end
  end

  describe "conversation/1" do
    test "returns the underlying Conversation struct" do
      session = make_awaiting_llm_session()

      assert %Conversation{} = Session.conversation(session)
    end
  end

  describe "awaiting_user?/1" do
    test "returns true when status is awaiting_user" do
      session = make_awaiting_user_session()

      assert Session.awaiting_user?(session) == true
    end

    test "returns false when status is awaiting_llm" do
      session = make_awaiting_llm_session()

      assert Session.awaiting_user?(session) == false
    end

    test "returns false when session is failed" do
      session = make_awaiting_llm_session()
      {:ok, failed} = Session.handle_error(session, :reason)

      assert Session.awaiting_user?(failed) == false
    end
  end
end
