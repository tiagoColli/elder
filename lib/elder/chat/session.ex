defmodule Elder.Chat.Session do
  @moduledoc """
  Manages a multi-turn LLM chat session lifecycle.

  Coordinates conversation state, LLM interview calls, and response handling
  across start → continue → handle_response → finish steps.
  """

  alias Elder.Chat.Conversation
  alias Elder.Chat.Message

  require Logger

  @typedoc "Possible states a session can be in."
  @type status :: :awaiting_llm | :awaiting_user | :completed | :failed

  @typedoc "Data returned when the interview should continue."
  @type continue_data :: %{
          text: String.t(),
          question: String.t() | nil,
          suggestions: [Message.suggestion()],
          artifacts: [struct()]
        }

  @typedoc "Result returned by a response handler callback."
  @type handler_result ::
          {:continue, continue_data()}
          | {:ready, %{artifacts: [struct()]}}
          | {:error, term()}

  @typedoc "A function that parses a raw LLM text response into a `handler_result`."
  @type response_handler :: (String.t() -> handler_result())

  @typedoc "A chat session."
  @type t :: %__MODULE__{
          id: String.t(),
          conversation: Conversation.t(),
          status: status(),
          review_skill: map(),
          caller: pid(),
          response_handler: response_handler(),
          error: term() | nil
        }

  @enforce_keys [:id, :conversation, :review_skill, :caller, :response_handler]
  defstruct [
    :id,
    :conversation,
    :review_skill,
    :caller,
    :response_handler,
    :error,
    status: :awaiting_llm
  ]

  @doc """
  Creates a new session and fires the first LLM interview call.

  Builds a conversation from `user_prompt`, creates the session struct, and
  dispatches an async `interview_run` to `caller`.

  ## Params
    - `review_skill` - review skill map with `:system_prompt`
    - `user_prompt` - the user's opening message
    - `response_handler` - function to parse raw LLM responses
    - `opts` - keyword options; `:caller` (pid) required

  ## Returns
    - `{:ok, t()}` on success
    - `{:error, reason}` if conversation initialisation fails
  """
  @spec start(map(), String.t(), response_handler(), keyword()) :: {:ok, t()} | {:error, term()}
  def start(review_skill, user_prompt, response_handler, opts \\ []) do
    caller = Keyword.fetch!(opts, :caller)

    with {:ok, conversation} <- Conversation.new(),
         {:ok, conversation} <- Conversation.add_user_message(conversation, user_prompt) do
      session = %__MODULE__{
        id: Ecto.UUID.generate(),
        conversation: conversation,
        review_skill: review_skill,
        caller: caller,
        response_handler: response_handler
      }

      Logger.info("Chat Session | start | session:#{session.id} | ok",
        feature: "Chat Session",
        step: "start",
        cid: session.id
      )

      messages = Conversation.to_llm_messages(conversation)
      :ok = Elder.LLM.interview_run(review_skill, messages, caller: caller)

      {:ok, session}
    end
  end

  @doc """
  Adds a user reply to the session and fires the next LLM call.

  ## Returns
    - `{:ok, t()}` with the updated session (status `:awaiting_llm`)
    - `{:error, :not_awaiting_user}` if the session is not in `:awaiting_user` state
    - `{:error, reason}` if adding the message fails
  """
  @spec continue(t(), String.t()) :: {:ok, t()} | {:error, :not_awaiting_user | term()}
  def continue(%__MODULE__{status: :awaiting_user} = session, user_text) do
    case Conversation.add_user_message(session.conversation, user_text) do
      {:ok, conversation} ->
        messages = Conversation.to_llm_messages(conversation)

        Logger.info("Chat Session | continue | session:#{session.id} | ok",
          feature: "Chat Session",
          step: "continue",
          cid: session.id
        )

        :ok = Elder.LLM.interview_run(session.review_skill, messages, caller: session.caller)

        {:ok, %{session | conversation: conversation, status: :awaiting_llm}}

      {:error, _reason} = error ->
        error
    end
  end

  def continue(%__MODULE__{}, _user_text), do: {:error, :not_awaiting_user}

  @doc """
  Processes a raw LLM response text using the session's response handler.

  ## Returns
    - `{:ok, t(), :continue}` when the interview should continue (status `:awaiting_user`)
    - `{:ok, t(), :ready}` when the interview is complete (status `:awaiting_user`)
    - `{:error, t(), reason}` on handler failure (session moved to `:failed`)
    - `{:error, t(), :not_awaiting_llm}` if the session is not in `:awaiting_llm` state
  """
  @spec handle_response(t(), String.t()) ::
          {:ok, t(), :continue | :ready} | {:error, t(), term()}
  def handle_response(%__MODULE__{status: :awaiting_llm} = session, raw_text) do
    case session.response_handler.(raw_text) do
      {:continue, data} ->
        {:ok, conversation} =
          Conversation.add_assistant_message(session.conversation, data.text,
            question: data.question,
            suggestions: data.suggestions,
            artifacts: data.artifacts
          )

        Logger.info("Chat Session | handle_response | session:#{session.id} | continue",
          feature: "Chat Session",
          step: "handle_response",
          cid: session.id
        )

        {:ok, %{session | conversation: conversation, status: :awaiting_user}, :continue}

      {:ready, data} ->
        artifacts = Map.get(data, :artifacts, [])

        {:ok, conversation} =
          Conversation.add_assistant_message(
            session.conversation,
            Map.get(data, :text, "Ready."),
            artifacts: artifacts
          )

        Logger.info("Chat Session | handle_response | session:#{session.id} | ready",
          feature: "Chat Session",
          step: "handle_response",
          cid: session.id
        )

        {:ok, %{session | conversation: conversation, status: :awaiting_user}, :ready}

      {:error, reason} ->
        Logger.error("Chat Session | handle_response | session:#{session.id} | error:handler",
          feature: "Chat Session",
          step: "handle_response",
          cid: session.id,
          reason: reason
        )

        {:ok, failed_session} = handle_error(session, reason)
        {:error, failed_session, reason}
    end
  end

  def handle_response(%__MODULE__{} = session, _raw_text) do
    {:error, session, :not_awaiting_llm}
  end

  @doc """
  Records an error on the session and transitions it to `:failed` state.

  ## Returns
    - `{:ok, t()}` with the updated session (status `:failed`)
  """
  @spec handle_error(t(), term()) :: {:ok, t()}
  def handle_error(%__MODULE__{} = session, reason) do
    Logger.warning("Chat Session | handle_error | session:#{session.id} | error:session_failed",
      feature: "Chat Session",
      step: "handle_error",
      cid: session.id,
      reason: reason
    )

    case Conversation.fail(session.conversation) do
      {:ok, conversation} ->
        {:ok, %{session | conversation: conversation, status: :failed, error: reason}}

      {:error, :already_finished} ->
        {:ok, %{session | status: :failed, error: reason}}
    end
  end

  @doc """
  Completes the session and returns the conversation transcript.

  ## Returns
    - `{:ok, t(), transcript}` with the completed session (status `:completed`) and transcript string
    - `{:error, :not_awaiting_user}` if the session is not in `:awaiting_user` state
    - `{:error, reason}` if conversation completion fails
  """
  @spec finish(t()) :: {:ok, t(), String.t()} | {:error, :not_awaiting_user | term()}
  def finish(%__MODULE__{status: :awaiting_user} = session) do
    case Conversation.complete(session.conversation) do
      {:ok, conversation} ->
        transcript = Conversation.to_transcript(conversation)

        Logger.info("Chat Session | finish | session:#{session.id} | ok",
          feature: "Chat Session",
          step: "finish",
          cid: session.id
        )

        {:ok, %{session | conversation: conversation, status: :completed}, transcript}

      {:error, _reason} = error ->
        error
    end
  end

  def finish(%__MODULE__{}), do: {:error, :not_awaiting_user}

  @doc """
  Returns the list of messages in the session's conversation.
  """
  @spec messages(t()) :: [Message.t()]
  def messages(%__MODULE__{conversation: conv}), do: Conversation.messages(conv)

  @doc """
  Returns the session's `Conversation` struct.
  """
  @spec conversation(t()) :: Conversation.t()
  def conversation(%__MODULE__{conversation: conv}), do: conv

  @doc """
  Returns `true` if the session is waiting for a user reply.
  """
  @spec awaiting_user?(t()) :: boolean()
  def awaiting_user?(%__MODULE__{status: :awaiting_user}), do: true
  def awaiting_user?(%__MODULE__{}), do: false
end
