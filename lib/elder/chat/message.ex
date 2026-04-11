defmodule Elder.Chat.Message do
  @moduledoc """
  A single immutable turn in a conversation.

  Created via role-specific constructors; never edited after creation.
  """

  @typedoc "A selectable reply option shown to the user as a button or chip."
  @type suggestion :: %{label: String.t(), value: String.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          role: :system | :user | :assistant,
          text: String.t(),
          question: String.t() | nil,
          suggestions: [suggestion()],
          artifacts: [Elder.Chat.Artifact.t()],
          inserted_at: DateTime.t()
        }

  @enforce_keys [:id, :role, :text, :inserted_at]
  defstruct [:id, :role, :text, :question, :inserted_at, suggestions: [], artifacts: []]

  @doc "Creates a user message. Returns `{:error, :empty_text}` for blank input."
  @spec new_user(String.t()) :: {:ok, t()} | {:error, :empty_text}
  def new_user(text) when is_binary(text) and byte_size(text) > 0 do
    {:ok,
     %__MODULE__{
       id: gen_id(),
       role: :user,
       text: text,
       inserted_at: DateTime.utc_now()
     }}
  end

  def new_user(_text), do: {:error, :empty_text}

  @doc """
  Creates an assistant message with optional question, suggestions, and artifacts.

  ## Options
    - `:question` - follow-up question string
    - `:suggestions` - list of `%{label: String.t(), value: String.t()}`
    - `:artifacts` - list of structs implementing `Elder.Chat.Artifact`
  """
  @spec new_assistant(String.t(), keyword()) :: {:ok, t()} | {:error, :empty_text}
  def new_assistant(text, opts \\ [])

  def new_assistant(text, opts) when is_binary(text) and byte_size(text) > 0 do
    {:ok,
     %__MODULE__{
       id: gen_id(),
       role: :assistant,
       text: text,
       question: Keyword.get(opts, :question),
       suggestions: Keyword.get(opts, :suggestions, []),
       artifacts: Keyword.get(opts, :artifacts, []),
       inserted_at: DateTime.utc_now()
     }}
  end

  def new_assistant(_text, _opts), do: {:error, :empty_text}

  @doc "Creates a system message. Returns `{:error, :empty_text}` for blank input."
  @spec new_system(String.t()) :: {:ok, t()} | {:error, :empty_text}
  def new_system(text) when is_binary(text) and byte_size(text) > 0 do
    {:ok,
     %__MODULE__{
       id: gen_id(),
       role: :system,
       text: text,
       inserted_at: DateTime.utc_now()
     }}
  end

  def new_system(_text), do: {:error, :empty_text}

  defp gen_id, do: Ecto.UUID.generate()
end
