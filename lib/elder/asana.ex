defmodule Elder.Asana do
  @moduledoc """
  Public facade for the Asana integration.

  Delegates task creation and workspace/project/section listing to the configured client.
  """

  alias Elder.Asana.TaskBuilder
  alias Elder.Asana.TaskDraft

  @compile {:no_warn_undefined, Elder.Asana.ClientMock}
  @client Application.compile_env(:elder, :asana_client, Elder.Asana.Client)

  @doc "Builds and creates an Asana task from a skill run and target selection."
  @spec create_task(struct(), map()) ::
          {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}
  def create_task(skill_run, target) do
    case TaskBuilder.build(skill_run, target) do
      {:ok, payload} -> @client.create_task(payload)
      {:error, reason} -> {:error, {:payload_error, reason}}
    end
  end

  @doc "Builds and creates an Asana task from a TaskDraft and target selection."
  @spec create_task_from_draft(TaskDraft.t(), map()) ::
          {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}
  def create_task_from_draft(%TaskDraft{} = draft, target) do
    case TaskBuilder.build_from_draft(draft, target) do
      {:ok, payload} -> @client.create_task(payload)
      {:error, reason} -> {:error, {:payload_error, reason}}
    end
  end

  @doc "Lists all Asana workspaces accessible by the configured PAT."
  @spec list_workspaces() :: {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_workspaces, do: @client.list_workspaces()

  @doc "Lists non-archived projects in a workspace."
  @spec list_projects(String.t()) ::
          {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_projects(workspace_gid), do: @client.list_projects(workspace_gid)

  @doc "Lists sections within a project."
  @spec list_sections(String.t()) ::
          {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_sections(project_gid), do: @client.list_sections(project_gid)

  @doc "Updates an existing Asana task's fields (e.g. assignee)."
  @spec update_task(String.t(), map()) :: {:ok, %{task_gid: String.t()}} | {:error, term()}
  def update_task(task_gid, fields), do: @client.update_task(task_gid, fields)

  @doc "Adds a tag to an existing Asana task."
  @spec add_tag_to_task(String.t(), String.t()) :: :ok | {:error, term()}
  def add_tag_to_task(task_gid, tag_gid), do: @client.add_tag_to_task(task_gid, tag_gid)
end
