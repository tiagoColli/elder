defmodule Elder.ExAgent.ExLLMProviderTest do
  use ExUnit.Case, async: false

  alias Elder.ExAgent.ExLLMProvider
  alias ExLLM.Providers.Mock

  setup do
    Mock.reset()
    :ok
  end

  defp msg_user(content) do
    %ExAgent.Message{role: :user, content: content, metadata: %{}, attachments: []}
  end

  defp msg_system(content) do
    %ExAgent.Message{role: :system, content: content, metadata: %{}, attachments: []}
  end

  describe "new/1" do
    test "defaults to the configured provider and model" do
      provider = ExLLMProvider.new()

      assert provider.provider == :mock
      assert provider.model == "mock-model"
      assert provider.system_prompt == nil
      assert provider.tools == []
    end

    test "accepts explicit overrides" do
      provider =
        ExLLMProvider.new(
          provider: :openai,
          model: "gpt-4o",
          system_prompt: "You are helpful.",
          tools: [:placeholder]
        )

      assert provider.provider == :openai
      assert provider.model == "gpt-4o"
      assert provider.system_prompt == "You are helpful."
      assert provider.tools == [:placeholder]
    end
  end

  describe "chat/3" do
    test "delegates to ExLLM and wraps the response in an ExAgent.Message" do
      Mock.set_response(%{content: "hi", model: "mock-model"})

      provider = ExLLMProvider.new()
      result = ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      assert {:ok, %ExAgent.Message{role: :assistant, content: "hi"}} = result
    end

    test "converts atom roles to ExLLM string roles" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      provider = ExLLMProvider.new()
      ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      request = Mock.get_last_request()
      assert Enum.all?(request.messages, fn msg -> is_binary(msg.role) end)
    end

    test "prepends system_prompt when set and messages lack a system entry" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      provider = ExLLMProvider.new(system_prompt: "Be concise.")
      ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      request = Mock.get_last_request()
      first = List.first(request.messages)
      assert first.role == "system"
      assert first.content == "Be concise."
    end

    test "does not duplicate a system message when the caller already supplied one" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      provider = ExLLMProvider.new(system_prompt: "Be concise.")

      messages = [
        msg_system("Caller system prompt."),
        msg_user("hello")
      ]

      ExAgent.LlmProvider.chat(provider, messages, [])

      request = Mock.get_last_request()
      system_messages = Enum.filter(request.messages, &(&1.role == "system"))
      assert length(system_messages) == 1
      assert hd(system_messages).content == "Caller system prompt."
    end

    test "returns {:error, reason} on ExLLM failure" do
      Mock.set_error({:api_error, "boom"})

      provider = ExLLMProvider.new()
      result = ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      assert {:error, {:api_error, "boom"}} = result
    end

    test "does not prepend system message when system_prompt is nil" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      provider = ExLLMProvider.new(system_prompt: nil)
      ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      request = Mock.get_last_request()
      assert length(request.messages) == 1
      assert hd(request.messages).role == "user"
    end

    test "returns {:tool_call, name, args} when response has tool_calls" do
      Mock.set_response(%{
        content: nil,
        model: "mock-model",
        tool_calls: [%{"name" => "create_task", "arguments" => %{"name" => "My Task"}}]
      })

      provider = ExLLMProvider.new()
      result = ExAgent.LlmProvider.chat(provider, [msg_user("create a task")], [])

      assert {:tool_call, "create_task", %{"name" => "My Task"}} = result
    end

    test "returns {:tool_call, name, args} when response has function_call" do
      Mock.set_response(%{
        content: nil,
        model: "mock-model",
        function_call: %{"name" => "assign_user", "arguments" => %{"task_gid" => "123"}}
      })

      provider = ExLLMProvider.new()
      result = ExAgent.LlmProvider.chat(provider, [msg_user("assign it")], [])

      assert {:tool_call, "assign_user", %{"task_gid" => "123"}} = result
    end

    test "parses JSON string arguments from tool_calls" do
      Mock.set_response(%{
        content: nil,
        model: "mock-model",
        tool_calls: [
          %{"name" => "add_tags", "arguments" => Jason.encode!(%{"tag_gid" => "t-1"})}
        ]
      })

      provider = ExLLMProvider.new()
      result = ExAgent.LlmProvider.chat(provider, [msg_user("tag it")], [])

      assert {:tool_call, "add_tags", %{"tag_gid" => "t-1"}} = result
    end

    test "passes tools as functions option to ExLLM" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      tool = %ExAgent.Tool{
        name: "test_tool",
        description: "A test tool",
        parameters: %{"type" => "object"},
        function: fn _args -> {:ok, "done"} end
      }

      provider = ExLLMProvider.new(tools: [tool])
      ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      request = Mock.get_last_request()
      assert Keyword.has_key?(request.options, :functions)
      [func] = Keyword.get(request.options, :functions)
      assert func.name == "test_tool"
      assert func.description == "A test tool"
    end

    test "does not pass functions option when tools list is empty" do
      Mock.set_response(%{content: "ok", model: "mock-model"})

      provider = ExLLMProvider.new(tools: [])
      ExAgent.LlmProvider.chat(provider, [msg_user("hello")], [])

      request = Mock.get_last_request()
      refute Keyword.has_key?(request.options, :functions)
    end
  end
end
