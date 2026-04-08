defmodule Elder.Asana do
  @moduledoc """
  Public facade for the Asana integration.

  Delegates task creation and workspace/project/section listing to the configured client.
  """

  alias Elder.Asana.TaskBuilder

  @compile {:no_warn_undefined, Elder.Asana.ClientMock}
  @client Application.compile_env(:elder, :asana_client, Elder.Asana.Client)

  @doc "Builds and creates an Asana task from a skill run and target selection."
  @spec create_task(struct(), map()) ::
          {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}
  def create_task(skill_run, target) do
    payload = TaskBuilder.build(skill_run, target)
    @client.create_task(payload)
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
end
