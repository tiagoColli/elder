defmodule Elder.ExAgent.Tools.CreateTask do
  @moduledoc """
  ExAgent tool that creates an Asana task from structured parameters.

  Wraps `Elder.Asana.create_task_from_draft/2`, building a `TaskDraft`
  from the LLM-provided arguments and forwarding to the Asana facade.
  """

  alias Elder.Asana.TaskDraft

  @doc "Returns the ExAgent tool definition for creating Asana tasks."
  @spec tool() :: ExAgent.Tool.t()
  def tool do
    %ExAgent.Tool{
      name: "create_task",
      description:
        "Create a new Asana task in the specified workspace, project, and section. " <>
          "Returns the task GID and permalink URL on success.",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string", "description" => "Task title (max 100 chars)"},
          "html_notes" => %{
            "type" => "string",
            "description" => "Task body as <body>HTML</body>"
          },
          "due_on" => %{"type" => "string", "description" => "Due date YYYY-MM-DD or null"},
          "assignee_email" => %{
            "type" => "string",
            "description" => "Assignee email or null"
          },
          "workspace_gid" => %{"type" => "string", "description" => "Asana workspace GID"},
          "project_gid" => %{"type" => "string", "description" => "Asana project GID"},
          "section_gid" => %{"type" => "string", "description" => "Asana section GID"}
        },
        "required" => ["name", "html_notes", "workspace_gid", "project_gid", "section_gid"]
      },
      function: &execute/1
    }
  end

  @doc """
  Creates an Asana task from structured LLM arguments.

  ## Params
    - `args` — map with `"name"`, `"html_notes"`, `"workspace_gid"`,
      `"project_gid"`, `"section_gid"`, and optional `"due_on"`, `"assignee_email"`

  ## Returns
    - `{:ok, confirmation}` with task URL and GID on success
    - `{:error, reason}` on payload validation or Asana API failure
  """
  @spec execute(map()) :: {:ok, String.t()} | {:error, term()}
  def execute(args) do
    draft = %TaskDraft{
      name: args["name"],
      html_notes: args["html_notes"],
      due_on: args["due_on"],
      assignee_email: args["assignee_email"]
    }

    target = %{
      workspace_gid: args["workspace_gid"],
      project_gid: args["project_gid"],
      section_gid: args["section_gid"]
    }

    case Elder.Asana.create_task_from_draft(draft, target) do
      {:ok, %{task_gid: gid, task_url: url}} ->
        {:ok, "Task created: #{url} (GID: #{gid})"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
