defmodule Elder.Schemas.InterviewResponse do
  @moduledoc """
  Ecto embedded schema for structured LLM interview replies.

  Used as `response_model:` with ExLLM's Instructor integration — Instructor
  generates a JSON Schema from these fields and validates/retries on malformed output.

  Replaces the regex-based `Elder.LLM.InterviewResponse` (152 LOC) parser.
  """

  use Ecto.Schema
  use Instructor

  import Ecto.Changeset

  @max_suggestions 3

  defmodule Suggestion do
    @moduledoc false
    use Ecto.Schema

    @type t :: %__MODULE__{}

    @primary_key false
    embedded_schema do
      field :label, :string
      field :value, :string
    end
  end

  defmodule Draft do
    @moduledoc false
    use Ecto.Schema

    @type t :: %__MODULE__{}

    @primary_key false
    embedded_schema do
      field :name, :string
      field :description, :string
      field :due_on, :string
      field :responsible_email, :string
      field :skipped_fields, {:array, :string}, default: []
    end
  end

  @llm_doc """
  Structured interview response. Return status "continue" with a follow-up
  question while gathering info, or "ready" when the task draft is complete.
  """

  @type t :: %__MODULE__{
          status: :continue | :ready | nil,
          assistant_message: String.t() | nil,
          question: String.t() | nil,
          suggestions: [%Suggestion{}],
          draft: %Draft{} | nil
        }

  @primary_key false
  embedded_schema do
    field :status, Ecto.Enum, values: [:continue, :ready]
    field :assistant_message, :string
    field :question, :string
    embeds_many :suggestions, Suggestion
    embeds_one :draft, Draft
  end

  @impl Instructor.Validator
  def validate_changeset(changeset) do
    changeset
    |> validate_required([:status, :assistant_message])
    |> validate_draft_present()
    |> cap_suggestions()
  end

  defp validate_draft_present(changeset) do
    if get_field(changeset, :draft) == nil do
      add_error(changeset, :draft, "can't be blank")
    else
      changeset
    end
  end

  defp cap_suggestions(changeset) do
    case get_field(changeset, :suggestions) do
      suggestions when is_list(suggestions) and length(suggestions) > @max_suggestions ->
        put_embed(changeset, :suggestions, Enum.take(suggestions, @max_suggestions))

      _ok ->
        changeset
    end
  end
end
