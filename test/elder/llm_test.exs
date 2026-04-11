defmodule Elder.LLMTest do
  use ExUnit.Case, async: false

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  describe "stream_run/3" do
    test "calls stream on the client with a context and the caller opt" do
      skill = %{system_prompt: "You are a helpful writing assistant."}

      expect(Elder.LLM.ClientMock, :stream, fn context, _model, opts ->
        assert %ReqLLM.Context{} = context
        assert Keyword.fetch!(opts, :caller) == self()
        :ok
      end)

      assert :ok =
               Elder.LLM.stream_run(skill, "Write a brief for the Q4 product launch",
                 caller: self()
               )
    end

    test "passes caller through to the client" do
      skill = %{system_prompt: "You are a text assistant."}
      target = self()

      expect(Elder.LLM.ClientMock, :stream, fn _context, _model, opts ->
        assert Keyword.get(opts, :caller) == target
        :ok
      end)

      assert :ok = Elder.LLM.stream_run(skill, "Generate output", caller: target)
    end
  end

  describe "interview_run/3" do
    test "calls call on the client with a context and the caller opt" do
      review_skill = %{system_prompt: "You are a task review assistant."}
      messages = [%{role: :user, text: "Create a handover task for the engineering team"}]

      expect(Elder.LLM.ClientMock, :call, fn context, _model, opts ->
        assert %ReqLLM.Context{} = context
        assert Keyword.fetch!(opts, :caller) == self()
        :ok
      end)

      assert :ok = Elder.LLM.interview_run(review_skill, messages, caller: self())
    end
  end

  describe "structured_run/4" do
    test "calls generate_object on the client with schema and caller" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}

      expect(Elder.LLM.ClientMock, :generate_object, fn context,
                                                        received_schema,
                                                        _model,
                                                        received_opts ->
        assert %ReqLLM.Context{} = context
        assert received_schema == schema
        assert Keyword.fetch!(received_opts, :caller) == self()
        :ok
      end)

      assert :ok =
               Elder.LLM.structured_run(skill, "Create a task", schema, caller: self())
    end

    test "builds context with inject_context: true by default" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object"}

      expect(Elder.LLM.ClientMock, :generate_object, fn context, _schema, _model, _opts ->
        [system_msg | _rest] = context.messages
        system_text = Enum.map_join(system_msg.content, & &1.text)
        assert String.contains?(system_text, "Today is")
        :ok
      end)

      assert :ok = Elder.LLM.structured_run(skill, "input", schema, caller: self())
    end

    test "forwards user_name opt to context builder" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object"}

      expect(Elder.LLM.ClientMock, :generate_object, fn context, _schema, _model, _opts ->
        [system_msg | _rest] = context.messages
        system_text = Enum.map_join(system_msg.content, & &1.text)
        assert String.contains?(system_text, "Alice Cardoso")
        :ok
      end)

      assert :ok =
               Elder.LLM.structured_run(skill, "input", schema,
                 caller: self(),
                 user_name: "Alice Cardoso"
               )
    end
  end
end
