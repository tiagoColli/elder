defmodule Elder.Chat.Conversation do
  @moduledoc """
  Manages the lifecycle of a multi-turn conversation.

  Pure data structure: creates messages, tracks turns and status,
  and formats history for LLM consumption. No IO or side effects.
  """

  alias Elder.Chat.Message

  @type status :: :active | :completed | :failed | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          status: status(),
          started_at: DateTime.t(),
          finished_at: DateTime.t() | nil,
          turn_count: non_neg_integer(),
          messages: [Message.t()],
          context: map()
        }

  @enforce_keys [:id, :started_at]
  defstruct [
    :id,
    :started_at,
    status: :active,
    finished_at: nil,
    turn_count: 0,
    messages: [],
    context: %{}
  ]

  @terminal_statuses [:completed, :failed, :cancelled]

  @doc """
  Creates a new active conversation with a generated id and timestamp.

  Accepts `:context` keyword option to set caller-provided data.

  ## Examples

      iex> {:ok, conv} = Elder.Chat.Conversation.new()
      iex> conv.status
      :active

      Elder.Chat.Conversation.new(context: %{skill_slug: "create-task"})
      # => {:ok, %Conversation{status: :active, context: %{skill_slug: "create-task"}}}
  """
  @spec new(keyword()) :: {:ok, t()}
  def new(opts \\ []) do
    {:ok,
     %__MODULE__{
       id: Ecto.UUID.generate(),
       started_at: DateTime.utc_now(),
       context: Keyword.get(opts, :context, %{})
     }}
  end

  @doc """
  Appends a user message and increments the turn count.

  Returns `{:error, :conversation_finished}` if the conversation is terminal,
  or `{:error, :empty_text}` if the text is blank.
  """
  @spec add_user_message(t(), String.t()) ::
          {:ok, t()} | {:error, :conversation_finished | :empty_text}
  def add_user_message(%__MODULE__{status: status}, _text) when status in @terminal_statuses do
    {:error, :conversation_finished}
  end

  def add_user_message(%__MODULE__{} = conv, text) do
    case Message.new_user(text) do
      {:ok, msg} ->
        {:ok, %{conv | messages: [msg | conv.messages], turn_count: conv.turn_count + 1}}

      error ->
        error
    end
  end

  @doc """
  Appends an assistant message with optional question, suggestions, and artifacts.

  Returns `{:error, :conversation_finished}` if the conversation is terminal,
  or `{:error, :empty_text}` if the text is blank.
  """
  @spec add_assistant_message(t(), String.t(), keyword()) ::
          {:ok, t()} | {:error, :conversation_finished | :empty_text}
  def add_assistant_message(conv, text, opts \\ [])

  def add_assistant_message(%__MODULE__{status: status}, _text, _opts)
      when status in @terminal_statuses do
    {:error, :conversation_finished}
  end

  def add_assistant_message(%__MODULE__{} = conv, text, opts) do
    case Message.new_assistant(text, opts) do
      {:ok, msg} ->
        {:ok, %{conv | messages: [msg | conv.messages]}}

      error ->
        error
    end
  end

  @doc """
  Appends a system message without incrementing the turn count.

  Returns `{:error, :conversation_finished}` if the conversation is terminal,
  or `{:error, :empty_text}` if the text is blank.
  """
  @spec add_system_message(t(), String.t()) ::
          {:ok, t()} | {:error, :conversation_finished | :empty_text}
  def add_system_message(%__MODULE__{status: status}, _text)
      when status in @terminal_statuses do
    {:error, :conversation_finished}
  end

  def add_system_message(%__MODULE__{} = conv, text) do
    case Message.new_system(text) do
      {:ok, msg} ->
        {:ok, %{conv | messages: [msg | conv.messages]}}

      error ->
        error
    end
  end

  @doc "Marks the conversation as completed. Returns `{:error, :already_finished}` if terminal."
  @spec complete(t()) :: {:ok, t()} | {:error, :already_finished}
  def complete(%__MODULE__{status: status}) when status in @terminal_statuses do
    {:error, :already_finished}
  end

  def complete(%__MODULE__{} = conv) do
    {:ok, %{conv | status: :completed, finished_at: DateTime.utc_now()}}
  end

  @doc "Marks the conversation as failed. Returns `{:error, :already_finished}` if terminal."
  @spec fail(t()) :: {:ok, t()} | {:error, :already_finished}
  def fail(%__MODULE__{status: status}) when status in @terminal_statuses do
    {:error, :already_finished}
  end

  def fail(%__MODULE__{} = conv) do
    {:ok, %{conv | status: :failed, finished_at: DateTime.utc_now()}}
  end

  @doc "Marks the conversation as cancelled. Returns `{:error, :already_finished}` if terminal."
  @spec cancel(t()) :: {:ok, t()} | {:error, :already_finished}
  def cancel(%__MODULE__{status: status}) when status in @terminal_statuses do
    {:error, :already_finished}
  end

  def cancel(%__MODULE__{} = conv) do
    {:ok, %{conv | status: :cancelled, finished_at: DateTime.utc_now()}}
  end

  @doc "Returns whether the conversation is in `:active` status."
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: :active}), do: true
  def active?(%__MODULE__{}), do: false

  @doc "Returns all messages in chronological order."
  @spec messages(t()) :: [Message.t()]
  def messages(%__MODULE__{messages: msgs}), do: Enum.reverse(msgs)

  @doc "Returns the most recent message, or `nil` if empty."
  @spec last_message(t()) :: Message.t() | nil
  def last_message(%__MODULE__{messages: []}), do: nil
  def last_message(%__MODULE__{messages: [latest | _rest]}), do: latest

  @doc "Filters messages by the given role."
  @spec messages_by_role(t(), :system | :user | :assistant) :: [Message.t()]
  def messages_by_role(%__MODULE__{messages: msgs}, role)
      when role in [:system, :user, :assistant] do
    msgs
    |> Enum.reverse()
    |> Enum.filter(&(&1.role == role))
  end

  @doc "Formats messages for LLM consumption, appending artifact transcripts and questions."
  @spec to_llm_messages(t()) :: [%{role: atom(), text: String.t()}]
  def to_llm_messages(%__MODULE__{messages: msgs}) do
    msgs
    |> Enum.reverse()
    |> Enum.map(fn msg ->
      text = build_message_text(msg)
      %{role: msg.role, text: text}
    end)
  end

  @doc "Returns a plain-text transcript of the full conversation history."
  @spec to_transcript(t()) :: String.t()
  def to_transcript(%__MODULE__{messages: msgs}) do
    Enum.map_join(Enum.reverse(msgs), "\n\n", fn
      %Message{role: :system, text: text} ->
        "System: #{text}"

      %Message{role: :user, text: text} ->
        "User: #{text}"

      %Message{role: :assistant} = msg ->
        build_assistant_transcript_line(msg)
    end)
  end

  defp build_message_text(%Message{} = msg) do
    base =
      Enum.reduce(msg.artifacts, msg.text, fn artifact, acc ->
        case artifact.__struct__.to_transcript(artifact) do
          nil -> acc
          line -> acc <> "\n" <> line
        end
      end)

    case msg.question do
      q when is_binary(q) and q != "" -> base <> "\nQuestion: " <> q
      _no_question -> base
    end
  end

  defp build_assistant_transcript_line(%Message{} = msg) do
    base =
      Enum.reduce(msg.artifacts, "Assistant: #{msg.text}", fn artifact, acc ->
        case artifact.__struct__.to_transcript(artifact) do
          nil -> acc
          line -> acc <> "\n" <> line
        end
      end)

    case msg.question do
      q when is_binary(q) and q != "" -> base <> "\nQuestion: " <> q
      _no_question -> base
    end
  end
end
