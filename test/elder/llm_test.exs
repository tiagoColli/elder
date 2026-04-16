defmodule Elder.LLMTest do
  use ExUnit.Case, async: false

  alias Elder.LLM
  alias ExLLM.Providers.Mock
  alias ExLLM.Types.StreamChunk

  setup do
    Mock.reset()
    :ok
  end

  describe "stream_run/3" do
    test "sends llm_token messages during streaming" do
      Mock.set_stream_chunks([
        %StreamChunk{content: "Hello ", finish_reason: nil},
        %StreamChunk{content: "world", finish_reason: nil},
        %StreamChunk{content: "", finish_reason: "stop"}
      ])

      skill = %{system_prompt: "You are a test assistant.", slug: "test-skill"}
      LLM.stream_run(skill, "say hello", caller: self())

      assert_receive {:llm_token, "Hello "}, 1000
      assert_receive {:llm_token, "world"}, 1000
    end

    test "sends llm_done with output, cost, and model on completion" do
      Mock.set_stream_chunks([
        %StreamChunk{content: "done", finish_reason: nil},
        %StreamChunk{content: "", finish_reason: "stop"}
      ])

      skill = %{system_prompt: "Test.", slug: "test-skill"}
      LLM.stream_run(skill, "test input", caller: self())

      assert_receive {:llm_done, %{output: output, cost_usd: cost, model: model}}, 1000
      assert output == "done"
      assert is_float(cost)
      assert is_binary(model)
    end

    test "sends llm_error on failure" do
      Mock.set_error({:api_error, "server error"})

      skill = %{system_prompt: "Test.", slug: "test-skill"}
      LLM.stream_run(skill, "test input", caller: self())

      assert_receive {:llm_error, _reason}, 1000
    end
  end

  describe "structured_run/4" do
    test "sends llm_object_done with parsed JSON object on success" do
      json_body = Jason.encode!(%{"name" => "Test Task", "html_notes" => "<body>Notes</body>"})

      Mock.set_response(%{
        content: json_body,
        model: "mock-model",
        usage: %{input_tokens: 10, output_tokens: 20}
      })

      skill = %{system_prompt: "Test.", slug: "test-skill"}
      schema = %{"type" => "object", "properties" => %{"name" => %{"type" => "string"}}}

      LLM.structured_run(skill, "create a task", schema, caller: self())

      assert_receive {:llm_object_done, {:ok, result}}, 1000
      assert result.object["name"] == "Test Task"
      assert is_float(result.cost_usd)
      assert is_binary(result.model)
    end

    test "sends llm_object_done error on LLM failure" do
      Mock.set_error({:api_error, "rate limited"})

      skill = %{system_prompt: "Test.", slug: "test-skill"}
      schema = %{"type" => "object"}

      LLM.structured_run(skill, "test", schema, caller: self())

      assert_receive {:llm_object_done, {:error, _reason}}, 1000
    end

    test "sends json_parse_error when response is not valid JSON" do
      Mock.set_response(%{
        content: "not valid json at all",
        model: "mock-model"
      })

      skill = %{system_prompt: "Test.", slug: "test-skill"}
      schema = %{"type" => "object"}

      LLM.structured_run(skill, "test", schema, caller: self())

      assert_receive {:llm_object_done, {:error, {:json_parse_error, content}}}, 1000
      assert content == "not valid json at all"
    end

    test "injects date/time context into system prompt by default" do
      json_body = Jason.encode!(%{"result" => "ok"})

      Mock.set_response(%{
        content: json_body,
        model: "mock-model"
      })

      skill = %{system_prompt: "Base prompt.", slug: "test-skill"}
      schema = %{"type" => "object"}

      LLM.structured_run(skill, "test", schema, caller: self(), user_name: "Alice")

      assert_receive {:llm_object_done, {:ok, _}}, 1000

      request = Mock.get_last_request()
      system_msg = Enum.find(request.messages, &(&1[:role] == "system"))
      assert system_msg.content =~ "Alice"
      assert system_msg.content =~ "Base prompt."
    end
  end
end
