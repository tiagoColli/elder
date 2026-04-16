defmodule Elder.Asana.Artifacts.Draft do
  @moduledoc """
  Structured Asana task draft built during an interview conversation.
  """

  @type t :: %__MODULE__{
          name: String.t() | nil,
          description: String.t() | nil,
          responsible_email: String.t() | nil,
          due_on: String.t() | nil,
          skipped_fields: [String.t()]
        }

  defstruct [:name, :description, :responsible_email, :due_on, skipped_fields: []]

  @spec to_transcript(t()) :: String.t() | nil
  def to_transcript(%__MODULE__{} = d) do
    fields =
      [
        {:name, d.name},
        {:responsible_email, d.responsible_email},
        {:description, d.description},
        {:due_on, d.due_on}
      ]
      |> Enum.filter(fn {_k, v} -> is_binary(v) and v != "" end)
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)

    skipped =
      case d.skipped_fields do
        [] -> []
        list -> ["skipped_fields: " <> Enum.join(list, ", ")]
      end

    case fields ++ skipped do
      [] -> nil
      parts -> "Draft — " <> Enum.join(parts, " | ")
    end
  end

  @spec type_label() :: String.t()
  def type_label, do: "draft"
end
