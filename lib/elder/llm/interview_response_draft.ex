defmodule Elder.LLM.InterviewResponseDraft do
  @moduledoc """
  Task-shaped fields extracted from an LLM interview reply JSON `draft` object.

  Populated by `Elder.LLM.InterviewResponse.parse/1`; not persisted as its own entity.
  """

  defstruct [:title, :responsible, :description, :due_date]

  @type t :: %__MODULE__{
          title: String.t() | nil,
          responsible: String.t() | nil,
          description: String.t() | nil,
          due_date: String.t() | nil
        }
end
