defmodule Elder.InterviewTest do
  use ExUnit.Case, async: false

  alias Elder.Asana.Artifacts.Draft
  alias Elder.Interview
  alias Elder.Schemas.InterviewResponse
  alias ExLLM.Providers.Mock

  @skill %{system_prompt: "You are a helpful task assistant."}

  defp build_response(attrs) do
    defaults = %{
      status: :continue,
      assistant_message: "What should the task be called?",
      question: "What should the task be called?",
      suggestions: [],
      draft: %InterviewResponse.Draft{
        name: nil,
        description: nil,
        due_on: nil,
        responsible_email: nil,
        skipped_fields: []
      }
    }

    struct!(InterviewResponse, Map.merge(defaults, attrs))
  end

  defp start_interview(opts \\ []) do
    caller = Keyword.get(opts, :caller, self())
    {:ok, interview} = Interview.start(@skill, "Create a marketing task", caller: caller)
    interview
  end

  defp make_awaiting_user do
    started = start_interview()

    response =
      build_response(%{
        status: :continue,
        assistant_message: "Got the title.",
        question: "Who should own it?",
        draft: %InterviewResponse.Draft{name: "Marketing task"}
      })

    {:ok, awaiting, :continue} = Interview.handle_response(started, response)
    awaiting
  end

  describe "start/2" do
    test "creates interview with awaiting_llm status" do
      interview = start_interview()

      assert interview.status == :awaiting_llm
      assert interview.draft == %Draft{}
      assert interview.turn_data == %{}
      assert interview.skill == @skill
      assert interview.caller == self()
      assert is_binary(interview.id)
    end

    test "session contains system and user messages" do
      interview = start_interview()
      messages = ExLLM.get_session_messages(interview.session)

      assert length(messages) == 2
      assert Enum.at(messages, 0).role == "system"
      assert Enum.at(messages, 0).content == @skill.system_prompt
      assert Enum.at(messages, 1).role == "user"
      assert Enum.at(messages, 1).content == "Create a marketing task"
    end

    test "dispatches async LLM call when enabled" do
      Application.put_env(:elder, Elder.Interview, dispatch_enabled: true)
      on_exit(fn -> Application.put_env(:elder, Elder.Interview, dispatch_enabled: false) end)

      _interview = start_interview()

      assert_receive {:interview_done, _result}, 2_000
    end

    test "does not dispatch when dispatch_enabled is false" do
      _interview = start_interview()

      refute_receive {:interview_done, _result}, 100
    end
  end

  describe "handle_response/2 with :continue" do
    test "transitions to awaiting_user and merges draft" do
      interview = start_interview()

      response =
        build_response(%{
          status: :continue,
          assistant_message: "Got the title. Who should own it?",
          question: "Who should own it?",
          draft: %InterviewResponse.Draft{name: "Q4 Launch"}
        })

      assert {:ok, updated, :continue} = Interview.handle_response(interview, response)
      assert updated.status == :awaiting_user
      assert updated.draft.name == "Q4 Launch"
      assert updated.draft.description == nil
    end

    test "stores turn_data for assistant message" do
      interview = start_interview()

      response =
        build_response(%{
          question: "Who owns it?",
          suggestions: [%InterviewResponse.Suggestion{label: "Me", value: "me"}],
          draft: %InterviewResponse.Draft{name: "Task"}
        })

      {:ok, updated, :continue} = Interview.handle_response(interview, response)

      assert map_size(updated.turn_data) == 1
      [{_idx, turn}] = Map.to_list(updated.turn_data)
      assert turn.question == "Who owns it?"
      assert length(turn.suggestions) == 1
    end
  end

  describe "handle_response/2 with :ready" do
    test "transitions to awaiting_user with :ready signal" do
      interview = start_interview()

      response =
        build_response(%{
          status: :ready,
          assistant_message: "All set. Generating task.",
          draft: %InterviewResponse.Draft{
            name: "Q4 Launch",
            description: "Full campaign brief",
            responsible_email: "owner@co.com",
            due_on: "2026-06-01"
          }
        })

      assert {:ok, updated, :ready} = Interview.handle_response(interview, response)
      assert updated.status == :awaiting_user
      assert updated.draft.name == "Q4 Launch"
      assert updated.draft.description == "Full campaign brief"
    end
  end

  describe "handle_response/2 guards" do
    test "rejects when not awaiting_llm" do
      interview = make_awaiting_user()
      response = build_response(%{})

      assert {:error, ^interview, :not_awaiting_llm} =
               Interview.handle_response(interview, response)
    end
  end

  describe "continue/2" do
    test "adds user message and transitions to awaiting_llm" do
      interview = make_awaiting_user()

      assert {:ok, updated} = Interview.continue(interview, "The marketing team")
      assert updated.status == :awaiting_llm

      messages = ExLLM.get_session_messages(updated.session)
      last_msg = List.last(messages)
      assert last_msg.role == "user"
      assert last_msg.content == "The marketing team"
    end

    test "dispatches async LLM call when enabled" do
      Application.put_env(:elder, Elder.Interview, dispatch_enabled: true)
      on_exit(fn -> Application.put_env(:elder, Elder.Interview, dispatch_enabled: false) end)

      interview = make_awaiting_user()
      {:ok, _updated} = Interview.continue(interview, "The marketing team")

      assert_receive {:interview_done, _result}, 2_000
    end

    test "rejects when not awaiting_user" do
      interview = start_interview()

      assert {:error, :not_awaiting_user} = Interview.continue(interview, "text")
    end
  end

  describe "draft accumulation" do
    test "merges fields across turns" do
      iv0 = start_interview()

      turn1 =
        build_response(%{
          draft: %InterviewResponse.Draft{name: "Campaign"}
        })

      {:ok, iv1, :continue} = Interview.handle_response(iv0, turn1)
      assert iv1.draft.name == "Campaign"
      assert iv1.draft.description == nil

      {:ok, iv2} = Interview.continue(iv1, "Q4 product launch")

      turn2 =
        build_response(%{
          draft: %InterviewResponse.Draft{description: "Full brief for Q4"}
        })

      {:ok, iv3, :continue} = Interview.handle_response(iv2, turn2)
      assert iv3.draft.name == "Campaign"
      assert iv3.draft.description == "Full brief for Q4"
    end

    test "new values overwrite old values" do
      iv0 = start_interview()

      turn1 =
        build_response(%{
          draft: %InterviewResponse.Draft{name: "Old name"}
        })

      {:ok, iv1, :continue} = Interview.handle_response(iv0, turn1)

      {:ok, iv2} = Interview.continue(iv1, "Actually, different name")

      turn2 =
        build_response(%{
          draft: %InterviewResponse.Draft{name: "New name"}
        })

      {:ok, iv3, :continue} = Interview.handle_response(iv2, turn2)
      assert iv3.draft.name == "New name"
    end

    test "nil new values preserve existing values" do
      iv0 = start_interview()

      turn1 =
        build_response(%{
          draft: %InterviewResponse.Draft{name: "Keep this", description: "Also keep"}
        })

      {:ok, iv1, :continue} = Interview.handle_response(iv0, turn1)

      {:ok, iv2} = Interview.continue(iv1, "continue")

      turn2 =
        build_response(%{
          draft: %InterviewResponse.Draft{name: nil, description: nil, due_on: "2026-07-01"}
        })

      {:ok, iv3, :continue} = Interview.handle_response(iv2, turn2)
      assert iv3.draft.name == "Keep this"
      assert iv3.draft.description == "Also keep"
      assert iv3.draft.due_on == "2026-07-01"
    end
  end

  describe "finish/1" do
    test "produces transcript and transitions to completed" do
      interview = make_awaiting_user()

      assert {:ok, finished, transcript} = Interview.finish(interview)
      assert finished.status == :completed
      assert is_binary(transcript)
      assert transcript =~ "User:"
      assert transcript =~ "Assistant:"
      refute transcript =~ "system"
    end

    test "rejects when not awaiting_user" do
      interview = start_interview()

      assert {:error, :not_awaiting_user} = Interview.finish(interview)
    end
  end

  describe "messages/1" do
    test "returns enriched messages with role atoms" do
      interview = make_awaiting_user()

      msgs = Interview.messages(interview)

      assert length(msgs) >= 3

      system_msg = Enum.find(msgs, &(&1.role == :system))
      assert system_msg.text == @skill.system_prompt

      user_msg = Enum.find(msgs, &(&1.role == :user))
      assert user_msg.text == "Create a marketing task"

      assistant_msg = Enum.find(msgs, &(&1.role == :assistant))
      assert assistant_msg.text == "Got the title."
      assert assistant_msg.question == "Who should own it?"
    end
  end

  describe "inject_feedback/2" do
    test "adds assistant message to session" do
      interview = make_awaiting_user()
      updated = Interview.inject_feedback(interview, "I still need the description.")

      messages = ExLLM.get_session_messages(updated.session)
      last_msg = List.last(messages)
      assert last_msg.role == "assistant"
      assert last_msg.content == "I still need the description."
    end

    test "stores current draft in turn_data" do
      interview = make_awaiting_user()
      updated = Interview.inject_feedback(interview, "Missing fields.")

      messages = ExLLM.get_session_messages(updated.session)
      msg_index = length(messages) - 1
      turn = Map.fetch!(updated.turn_data, msg_index)
      assert turn.draft == interview.draft
      assert turn.question == nil
      assert turn.suggestions == []
    end

    test "preserves awaiting_user status" do
      interview = make_awaiting_user()
      updated = Interview.inject_feedback(interview, "Please provide more details.")

      assert updated.status == :awaiting_user
    end
  end

  describe "dispatch_chat contract" do
    # ExLLM's mock provider returns {:error, :instructor_not_available} when
    # response_model is used — Instructor is only wired for real providers.
    # This test documents the expected contract for production (Gemini).
    @tag :skip
    test "dispatch_chat sends {:interview_done, {:ok, %InterviewResponse{}}} on success" do
      Application.put_env(:elder, Elder.Interview, dispatch_enabled: true)
      on_exit(fn -> Application.put_env(:elder, Elder.Interview, dispatch_enabled: false) end)

      Mock.set_response(%{
        content:
          Jason.encode!(%{
            status: "continue",
            assistant_message: "Hi",
            question: "Name?",
            suggestions: [],
            draft: %{name: nil, description: nil, due_on: nil, responsible_email: nil}
          })
      })

      _interview = start_interview()

      assert_receive {:interview_done, {:ok, %InterviewResponse{}}}, 2_000
    end
  end

  describe "handle_error/1" do
    test "transitions to failed with reason" do
      interview = start_interview()

      assert {:ok, failed} = Interview.handle_error(interview, :rate_limited)
      assert failed.status == :failed
      assert failed.error == :rate_limited
    end
  end

  describe "awaiting_user?/1" do
    test "returns true when awaiting_user" do
      interview = make_awaiting_user()
      assert Interview.awaiting_user?(interview)
    end

    test "returns false for other statuses" do
      interview = start_interview()
      refute Interview.awaiting_user?(interview)
    end
  end
end
