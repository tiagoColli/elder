defmodule Elder.LLM do
  @moduledoc """
  Public context for LLM interactions.

  Routes skill execution to streaming, interview, or structured generation paths.
  """

  alias Elder.LLM.ContextBuilder

  require Logger

  @llm_client Application.compile_env(:elder, :llm_client, Elder.LLM.Client)

  @doc """
  Starts a streaming LLM text generation run for the given skill and input.

  Dispatches `{:llm_token, chunk}` messages to `caller` during generation,
  followed by `{:llm_done, meta}` on success or `{:llm_error, reason}` on failure.

  ## Params
    - `skill` - skill map with at minimum `:system_prompt`
    - `user_input` - user input string
    - `opts` - keyword options; `:caller` (pid) required

  ## Returns
    - `:ok` — run dispatched asynchronously
  """
  @spec stream_run(map(), String.t(), keyword()) :: :ok
  def stream_run(skill, user_input, opts) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
    slug = Map.get(skill, :slug, "unknown")

    Logger.info("LLM | stream_run | skill:#{slug} model:#{model} | ok",
      feature: "LLM",
      step: "stream_run",
      cid: slug
    )

    context = ContextBuilder.build(skill, user_input)
    @llm_client.stream(context, model, opts)
  end

  @doc """
  Starts an interview-style LLM run over a conversation history.

  Dispatches `{:interview_done, {:ok, text}}` or `{:interview_done, {:error, reason}}`
  to `caller` on completion.

  ## Params
    - `review_skill` - review skill map with `:system_prompt`
    - `conversation` - list of LLM message maps
    - `opts` - keyword options; `:caller` (pid) required

  ## Returns
    - `:ok` — run dispatched asynchronously
  """
  @spec interview_run(map(), list(), keyword()) :: :ok
  def interview_run(review_skill, conversation, opts) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
    slug = Map.get(review_skill, :slug, "unknown")

    Logger.info("LLM | interview_run | skill:#{slug} model:#{model} | ok",
      feature: "LLM",
      step: "interview_run",
      cid: slug
    )

    context = ContextBuilder.build_conversation(review_skill, conversation)
    @llm_client.call(context, model, opts)
  end

  @doc """
  Starts a structured object generation run for the given skill and input.

  Dispatches `{:llm_object_done, {:ok, %{object: map(), cost_usd: float(), model: String.t()}}}`
  or `{:llm_object_done, {:error, reason}}` to `caller` on completion.

  ## Params
    - `skill` - skill map with at minimum `:system_prompt`
    - `user_input` - user input string
    - `schema` - JSON Schema map defining the expected object shape
    - `opts` - keyword options; `:caller` (pid) required; `:user_name` and `:inject_context` optional

  ## Returns
    - `:ok` — run dispatched asynchronously
  """
  @spec structured_run(map(), String.t(), map(), keyword()) :: :ok
  def structured_run(skill, user_input, schema, opts) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
    slug = Map.get(skill, :slug, "unknown")
    {build_opts, client_opts} = Keyword.split(opts, [:inject_context, :user_name])

    Logger.info("LLM | structured_run | skill:#{slug} model:#{model} | ok",
      feature: "LLM",
      step: "structured_run",
      cid: slug
    )

    context =
      ContextBuilder.build(skill, user_input, Keyword.put_new(build_opts, :inject_context, true))

    @llm_client.generate_object(context, schema, model, client_opts)
  end
end
