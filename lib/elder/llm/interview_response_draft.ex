defmodule Elder.LLM.InterviewResponseDraft do
  @moduledoc """
  Task-shaped fields extracted from an LLM interview reply JSON `draft` object.

  Not persisted as its own entity. GID values come from the UI, not the LLM.
  `skipped_fields` lists optional fields the user skipped.
  """

  defstruct [
    :name,
    :description,
    :due_on,
    :responsible_email,
    skipped_fields: []
  ]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t() | nil,
          due_on: String.t() | nil,
          responsible_email: String.t() | nil,
          skipped_fields: [String.t()]
        }
end
