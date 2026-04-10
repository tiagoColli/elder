defmodule Elder.LLM do
  @moduledoc """
  Public facade for the LLM integration.

  Resolves the model, builds context from the skill and user input, and starts an async stream.
  """

  alias Elder.LLM.ContextBuilder

  @llm_client Application.compile_env(:elder, :llm_client, Elder.LLM.Client)

  @doc """
  Streams an LLM response for a skill, broadcasting tokens to a PubSub topic.

  Broadcasts `:llm_token`, `:llm_done`, or `:llm_error` messages to `pubsub_topic`.
  """
  @spec stream_run(map(), String.t(), String.t()) :: :ok
  def stream_run(skill, user_input, pubsub_topic) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
    context = ContextBuilder.build(skill, user_input)
    @llm_client.stream(context, model, pubsub_topic)
  end

  @doc """
  Runs a synchronous interview LLM call for a review skill, broadcasting `{:interview_done, result}` to the topic.

  `conversation` is a list of `%{role: :user | :assistant, text: String.t()}` maps.
  Broadcasts `{:interview_done, {:ok, text}}` or `{:interview_done, {:error, reason}}`.
  """
  @spec interview_run(map(), [%{role: atom(), text: String.t()}], String.t()) :: :ok
  def interview_run(review_skill, conversation, pubsub_topic) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"
    context = ContextBuilder.build_conversation(review_skill, conversation)
    @llm_client.call(context, model, pubsub_topic)
  end

  @doc """
  Generates a structured object from a skill run, broadcasting the result to a PubSub topic.

  `schema` is a JSON Schema map describing the expected object shape; the caller provides it.
  `opts` are forwarded to `ContextBuilder.build/3` for context injection (e.g. `user_name: "Alice"`).
  Broadcasts `{:llm_object_done, {:ok, %{object: map, cost_usd: float, model: String.t()}}}` or
  `{:llm_object_done, {:error, reason}}`.
  """
  @spec structured_run(map(), String.t(), map(), String.t(), keyword()) :: :ok
  def structured_run(skill, user_input, schema, pubsub_topic, opts \\ []) do
    model = Application.get_env(:elder, Elder.LLM)[:model] || "google:gemini-2.5-flash"

    context =
      ContextBuilder.build(skill, user_input, Keyword.put_new(opts, :inject_context, true))

    @llm_client.generate_object(context, schema, model, pubsub_topic)
  end
end
