defmodule Elder.Asana.Payloads.CreateTaskPayload do
  @moduledoc """
  Struct and builder for the Asana create-task API payload.
  """

  alias Elder.Asana.TaskDraft

  @max_name_length 100

  defstruct [
    :name,
    :workspace_gid,
    :project_gid,
    :section_gid,
    :html_notes,
    :due_on,
    :assignee_email
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          workspace_gid: String.t(),
          project_gid: String.t(),
          section_gid: String.t(),
          html_notes: String.t() | nil,
          due_on: String.t() | nil,
          assignee_email: String.t() | nil
        }

  @doc "Builds a CreateTaskPayload from a skill run and Asana target selectors."
  @spec build(struct(), map()) ::
          {:ok, t()}
          | {:error, :missing_name | :missing_workspace | :missing_project | :missing_section}
  def build(skill_run, target) do
    parsed = parse_output(skill_run.llm_output)
    name = task_name(parsed, skill_run)

    cond do
      name == "" ->
        {:error, :missing_name}

      blank?(target.workspace_gid) ->
        {:error, :missing_workspace}

      blank?(target.project_gid) ->
        {:error, :missing_project}

      blank?(target.section_gid) ->
        {:error, :missing_section}

      true ->
        {:ok,
         %__MODULE__{
           name: name,
           workspace_gid: target.workspace_gid,
           project_gid: target.project_gid,
           section_gid: target.section_gid,
           html_notes: task_html_notes(parsed, skill_run),
           due_on: optional_string(parsed["due_on"]),
           assignee_email: optional_string(parsed["assignee_email"])
         }}
    end
  end

  @doc "Builds a CreateTaskPayload from a TaskDraft and Asana target selectors."
  @spec from_draft(TaskDraft.t(), map()) ::
          {:ok, t()}
          | {:error, :missing_name | :missing_workspace | :missing_project | :missing_section}
  def from_draft(%TaskDraft{} = draft, target) do
    cond do
      blank?(draft.name) ->
        {:error, :missing_name}

      blank?(target.workspace_gid) ->
        {:error, :missing_workspace}

      blank?(target.project_gid) ->
        {:error, :missing_project}

      blank?(target.section_gid) ->
        {:error, :missing_section}

      true ->
        {:ok,
         %__MODULE__{
           name: String.slice(draft.name, 0, @max_name_length),
           workspace_gid: target.workspace_gid,
           project_gid: target.project_gid,
           section_gid: target.section_gid,
           html_notes: draft.html_notes,
           due_on: draft.due_on,
           assignee_email: draft.assignee_email
         }}
    end
  end

  @doc "Converts a CreateTaskPayload struct to the Asana API JSON map format."
  @spec to_api_map(t()) :: map()
  def to_api_map(%__MODULE__{} = payload) do
    %{
      "name" => payload.name,
      "workspace" => payload.workspace_gid,
      "projects" => [payload.project_gid],
      "memberships" => [%{"project" => payload.project_gid, "section" => payload.section_gid}]
    }
    |> maybe_put_html_notes(payload)
    |> maybe_put_due_on(payload)
    |> maybe_put_assignee(payload)
    |> then(&%{"data" => &1})
  end

  defp parse_output(llm_output) when is_binary(llm_output) do
    stripped = strip_code_fence(llm_output)

    case Jason.decode(stripped) do
      {:ok, map} when is_map(map) -> map
      _result -> %{}
    end
  end

  defp parse_output(_llm_output), do: %{}

  defp strip_code_fence(text) do
    text
    |> String.trim()
    |> String.replace(~r/\A```(?:json)?\s*/s, "")
    |> String.replace(~r/\s*```\z/s, "")
    |> String.trim()
  end

  defp task_name(%{"name" => name}, _skill_run) when is_binary(name) and byte_size(name) > 0 do
    String.slice(name, 0, @max_name_length)
  end

  defp task_name(_parsed, skill_run) do
    String.slice(skill_run.user_input, 0, @max_name_length)
  end

  defp task_html_notes(%{"html_notes" => html}, _skill_run) when is_binary(html) do
    String.trim(html)
  end

  defp task_html_notes(_parsed, skill_run) do
    case skill_run.llm_output do
      html when is_binary(html) -> String.trim(html)
      nil -> ""
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

  defp optional_string(value) when is_binary(value) and byte_size(value) > 0, do: value
  defp optional_string(_value), do: nil

  defp maybe_put_html_notes(map, %{html_notes: html})
       when is_binary(html) and byte_size(html) > 0 do
    Map.put(map, "html_notes", html)
  end

  defp maybe_put_html_notes(map, _payload), do: map

  defp maybe_put_due_on(map, %{due_on: due_on})
       when is_binary(due_on) and byte_size(due_on) > 0 do
    Map.put(map, "due_on", due_on)
  end

  defp maybe_put_due_on(map, _payload), do: map

  defp maybe_put_assignee(map, %{assignee_email: email})
       when is_binary(email) and byte_size(email) > 0 do
    Map.put(map, "assignee", email)
  end

  defp maybe_put_assignee(map, _payload), do: map
end
