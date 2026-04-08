defmodule Elder.Asana.TaskBuilder do
  @moduledoc """
  Builds Asana task payloads from skill runs and target selections.
  """

  @max_name_length 100

  @doc "Returns an Asana API-shaped task payload map for the given skill run and target."
  @spec build(struct(), map()) :: map()
  def build(skill_run, target) do
    base = %{
      "name" => task_name(skill_run),
      "notes" => skill_run.llm_output,
      "workspace" => target.workspace_gid
    }

    base_with_project =
      case target.project_gid do
        nil -> base
        gid -> Map.put(base, "projects", [gid])
      end

    payload =
      case {target.project_gid, target.section_gid} do
        {nil, _section_gid} ->
          base_with_project

        {_project_gid, nil} ->
          base_with_project

        {project_gid, section_gid} ->
          Map.put(base_with_project, "memberships", [
            %{"project" => project_gid, "section" => section_gid}
          ])
      end

    %{"data" => payload}
  end

  defp task_name(skill_run) do
    prefix = "Brief: #{skill_run.skill_slug} — "
    max_suffix = max(0, @max_name_length - String.length(prefix))
    prefix <> String.slice(skill_run.user_input, 0, max_suffix)
  end
end
