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
end
