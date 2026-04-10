defmodule Elder.Asana.TaskBuilder do
  @moduledoc """
  Builds Asana API payloads from skill runs and task drafts.
  """

  alias Elder.Asana.Payloads.CreateTaskPayload
  alias Elder.Asana.TaskDraft

  @doc "Builds an Asana API map from a skill run and target selection."
  @spec build(struct(), map()) :: {:ok, map()} | {:error, atom()}
  def build(skill_run, target) do
    case CreateTaskPayload.build(skill_run, target) do
      {:ok, payload} -> {:ok, CreateTaskPayload.to_api_map(payload)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Builds an Asana API map from a TaskDraft and target selection."
  @spec build_from_draft(TaskDraft.t(), map()) :: {:ok, map()} | {:error, atom()}
  def build_from_draft(%TaskDraft{} = draft, target) do
    case CreateTaskPayload.from_draft(draft, target) do
      {:ok, payload} -> {:ok, CreateTaskPayload.to_api_map(payload)}
      {:error, reason} -> {:error, reason}
    end
  end
end
