defmodule Elder.LLMTest do
  use ExUnit.Case, async: false

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  describe "structured_run/5" do
    test "calls generate_object on the client with schema and topic" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}
      topic = "test:structured_run"

      expect(Elder.LLM.ClientMock, :generate_object, fn context,
                                                        received_schema,
                                                        _model,
                                                        received_topic ->
        assert %ReqLLM.Context{} = context
        assert received_schema == schema
        assert received_topic == topic
        :ok
      end)

      assert :ok = Elder.LLM.structured_run(skill, "Create a task", schema, topic)
    end

    test "builds context with inject_context: true by default" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object"}
      topic = "test:structured_context"

      expect(Elder.LLM.ClientMock, :generate_object, fn context, _schema, _model, _topic ->
        [system_msg | _rest] = context.messages
        system_text = Enum.map_join(system_msg.content, & &1.text)
        assert String.contains?(system_text, "Today is")
        :ok
      end)

      assert :ok = Elder.LLM.structured_run(skill, "input", schema, topic)
    end

    test "forwards user_name opt to context builder" do
      skill = %{system_prompt: "You are a helpful assistant."}
      schema = %{"type" => "object"}
      topic = "test:structured_user"

      expect(Elder.LLM.ClientMock, :generate_object, fn context, _schema, _model, _topic ->
        [system_msg | _rest] = context.messages
        system_text = Enum.map_join(system_msg.content, & &1.text)
        assert String.contains?(system_text, "Alice Cardoso")
        :ok
      end)

      assert :ok =
               Elder.LLM.structured_run(skill, "input", schema, topic, user_name: "Alice Cardoso")
    end
  end
end
