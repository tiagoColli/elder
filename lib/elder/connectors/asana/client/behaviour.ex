defmodule Elder.Asana.ClientBehaviour do
  @moduledoc """
  Behaviour contract for the Asana API client.
  """

  @callback create_task(payload :: map()) ::
              {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}

  @callback list_workspaces() ::
              {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}

  @callback list_projects(workspace_gid :: String.t()) ::
              {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}

  @callback list_sections(project_gid :: String.t()) ::
              {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}

  @callback update_task(task_gid :: String.t(), fields :: map()) ::
              {:ok, %{task_gid: String.t()}} | {:error, term()}

  @callback add_tag_to_task(task_gid :: String.t(), tag_gid :: String.t()) ::
              :ok | {:error, term()}
end
