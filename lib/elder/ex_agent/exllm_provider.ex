defmodule Elder.ExAgent.ExLLMProvider do
  @moduledoc """
  Bridge struct that lets ExAgent agents talk to LLMs through ExLLM.

  Holds the minimum config needed to make an `ExLLM.chat/3` call and
  is used via the `ExAgent.LlmProvider` protocol. E2+ will populate
  `tools` with `ExAgent.Tool` structs for the agent tool loop.
  """

  @enforce_keys []
  defstruct provider: nil, model: nil, system_prompt: nil, tools: []

  @type t :: %__MODULE__{
          provider: atom(),
          model: String.t(),
          system_prompt: String.t() | nil,
          tools: [ExAgent.Tool.t()]
        }

  @doc """
  Builds a new provider struct with optional overrides.

  ## Params
    - `opts` — keyword options
      - `:provider` — LLM provider atom (default: app config or `:gemini`)
      - `:model` — model string (default: app config or `"google:gemini-2.5-flash"`)
      - `:system_prompt` — system prompt prepended to messages
      - `:tools` — list of `ExAgent.Tool` structs for function calling

  ## Returns
    - `t()` — the provider struct
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      provider: Keyword.get(opts, :provider, default_provider()),
      model: Keyword.get(opts, :model, default_model()),
      system_prompt: Keyword.get(opts, :system_prompt),
      tools: Keyword.get(opts, :tools, [])
    }
  end

  defp default_provider do
    Application.get_env(:ex_llm, :default_provider, :gemini)
  end

  defp default_model do
    Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
  end
end

defimpl ExAgent.LlmProvider, for: Elder.ExAgent.ExLLMProvider do
  require Logger

  @spec chat(Elder.ExAgent.ExLLMProvider.t(), [ExAgent.Message.t()], keyword()) ::
          {:ok, ExAgent.Message.t()} | {:tool_call, String.t(), map()} | {:error, term()}
  def chat(%Elder.ExAgent.ExLLMProvider{} = provider, messages, _chat_opts) do
    ex_llm_messages =
      messages
      |> maybe_prepend_system(provider.system_prompt)
      |> Enum.map(&to_ex_llm/1)

    chat_opts = maybe_add_functions([model: provider.model], provider.tools)

    case ExLLM.chat(provider.provider, ex_llm_messages, chat_opts) do
      {:ok, response} ->
        Logger.info("ExAgent | chat | provider:#{provider.provider} model:#{provider.model} | ok",
          feature: "ExAgent",
          step: "chat"
        )

        parse_response(response)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(%{tool_calls: [call | _rest]}) when is_map(call) do
    {:tool_call, call["name"] || call[:name], parse_args(call["arguments"] || call[:arguments])}
  end

  defp parse_response(%{function_call: %{"name" => name, "arguments" => args}}) do
    {:tool_call, name, parse_args(args)}
  end

  defp parse_response(%{function_call: %{name: name, arguments: args}}) do
    {:tool_call, name, parse_args(args)}
  end

  defp parse_response(%{content: content}) do
    {:ok,
     %ExAgent.Message{
       role: :assistant,
       content: content || "",
       metadata: %{},
       attachments: []
     }}
  end

  defp parse_args(args) when is_map(args), do: args

  defp parse_args(args) when is_binary(args) do
    case Jason.decode(args) do
      {:ok, decoded} -> decoded
      {:error, _decode_error} -> %{"raw" => args}
    end
  end

  defp parse_args(_other), do: %{}

  defp maybe_add_functions(opts, []), do: opts

  defp maybe_add_functions(opts, tools) do
    functions =
      Enum.map(tools, fn %ExAgent.Tool{name: name, description: desc, parameters: params} ->
        %{name: name, description: desc, parameters: params}
      end)

    Keyword.put(opts, :functions, functions)
  end

  defp maybe_prepend_system(messages, nil), do: messages

  defp maybe_prepend_system([%ExAgent.Message{role: :system} | _rest] = messages, _prompt),
    do: messages

  defp maybe_prepend_system(messages, prompt) do
    [%ExAgent.Message{role: :system, content: prompt, metadata: %{}, attachments: []} | messages]
  end

  defp to_ex_llm(%ExAgent.Message{role: role, content: content}) do
    %{role: Atom.to_string(role), content: content}
  end
end
