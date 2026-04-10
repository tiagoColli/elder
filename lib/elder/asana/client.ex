defmodule Elder.Asana.Client do
  @moduledoc """
  HTTP adapter for the Asana REST API v1.0.

  Implements `Elder.Asana.ClientBehaviour` using `Req`.
  """

  @behaviour Elder.Asana.ClientBehaviour

  require Logger

  @base_url "https://app.asana.com/api/1.0"

  @doc "Creates an Asana task from the given API payload."
  @spec create_task(map()) ::
          {:ok, %{task_gid: String.t(), task_url: String.t()}} | {:error, term()}
  def create_task(payload) do
    workspace = get_in(payload, ["data", "workspace"])

    with {:ok, pat} <- fetch_pat(),
         {:ok, %Req.Response{status: 201, body: %{"data" => data}}} <-
           Req.post("#{@base_url}/tasks",
             json: payload,
             headers: [authorization(pat)]
           ) do
      Logger.info("Skills Platform | asana_create_task | workspace:#{workspace} | ok",
        feature: "Skills Platform",
        step: "asana_create_task",
        cid: workspace
      )

      {:ok, %{task_gid: data["gid"], task_url: data["permalink_url"]}}
    else
      {:error, {:missing_config, :asana_pat}} = err ->
        Logger.error(
          "Skills Platform | asana_create_task | workspace:#{workspace} | error:missing_pat",
          feature: "Skills Platform",
          step: "asana_create_task",
          cid: workspace,
          reason: :missing_config
        )

        err

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Skills Platform | asana_create_task | workspace:#{workspace} | error:#{status}",
          feature: "Skills Platform",
          step: "asana_create_task",
          cid: workspace,
          reason: status
        )

        {:error, {:asana_api_error, status, body}}

      {:error, reason} ->
        Logger.error(
          "Skills Platform | asana_create_task | workspace:#{workspace} | error:network",
          feature: "Skills Platform",
          step: "asana_create_task",
          cid: workspace,
          reason: :network_error
        )

        {:error, {:network_error, reason}}
    end
  end

  @doc "Lists all workspaces accessible by the configured PAT."
  @spec list_workspaces() :: {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_workspaces do
    with {:ok, pat} <- fetch_pat(),
         {:ok, %Req.Response{status: 200, body: %{"data" => data}}} <-
           Req.get("#{@base_url}/workspaces",
             params: [limit: 100],
             headers: [authorization(pat)]
           ) do
      workspaces = Enum.map(data, &%{gid: &1["gid"], name: &1["name"]})

      Logger.info(
        "Skills Platform | asana_list_workspaces | all | count:#{length(workspaces)}",
        feature: "Skills Platform",
        step: "asana_list_workspaces",
        cid: "all",
        count: length(workspaces)
      )

      {:ok, workspaces}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Skills Platform | asana_list_workspaces | all | error:#{status}",
          feature: "Skills Platform",
          step: "asana_list_workspaces",
          cid: "all",
          reason: status
        )

        {:error, {:asana_api_error, status, body}}

      {:error, {:missing_config, :asana_pat}} = err ->
        err

      {:error, reason} ->
        Logger.error(
          "Skills Platform | asana_list_workspaces | all | error:network",
          feature: "Skills Platform",
          step: "asana_list_workspaces",
          cid: "all",
          reason: :network_error
        )

        {:error, {:network_error, reason}}
    end
  end

  @doc "Lists non-archived projects in a workspace."
  @spec list_projects(String.t()) ::
          {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_projects(workspace_gid) do
    with {:ok, pat} <- fetch_pat(),
         {:ok, %Req.Response{status: 200, body: %{"data" => data}}} <-
           Req.get("#{@base_url}/projects",
             params: [workspace: workspace_gid, archived: false, limit: 100],
             headers: [authorization(pat)]
           ) do
      projects = Enum.map(data, &%{gid: &1["gid"], name: &1["name"]})

      Logger.info(
        "Skills Platform | asana_list_projects | workspace:#{workspace_gid} | count:#{length(projects)}",
        feature: "Skills Platform",
        step: "asana_list_projects",
        cid: workspace_gid,
        count: length(projects)
      )

      {:ok, projects}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Skills Platform | asana_list_projects | workspace:#{workspace_gid} | error:#{status}",
          feature: "Skills Platform",
          step: "asana_list_projects",
          cid: workspace_gid,
          reason: status
        )

        {:error, {:asana_api_error, status, body}}

      {:error, {:missing_config, :asana_pat}} = err ->
        err

      {:error, reason} ->
        Logger.error(
          "Skills Platform | asana_list_projects | workspace:#{workspace_gid} | error:network",
          feature: "Skills Platform",
          step: "asana_list_projects",
          cid: workspace_gid,
          reason: :network_error
        )

        {:error, {:network_error, reason}}
    end
  end

  @doc "Lists sections within a project."
  @spec list_sections(String.t()) ::
          {:ok, [%{gid: String.t(), name: String.t()}]} | {:error, term()}
  def list_sections(project_gid) do
    with {:ok, pat} <- fetch_pat(),
         {:ok, %Req.Response{status: 200, body: %{"data" => data}}} <-
           Req.get("#{@base_url}/projects/#{project_gid}/sections",
             headers: [authorization(pat)]
           ) do
      sections = Enum.map(data, &%{gid: &1["gid"], name: &1["name"]})

      Logger.info(
        "Skills Platform | asana_list_sections | project:#{project_gid} | count:#{length(sections)}",
        feature: "Skills Platform",
        step: "asana_list_sections",
        cid: project_gid,
        count: length(sections)
      )

      {:ok, sections}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error(
          "Skills Platform | asana_list_sections | project:#{project_gid} | error:#{status}",
          feature: "Skills Platform",
          step: "asana_list_sections",
          cid: project_gid,
          reason: status
        )

        {:error, {:asana_api_error, status, body}}

      {:error, {:missing_config, :asana_pat}} = err ->
        err

      {:error, reason} ->
        Logger.error(
          "Skills Platform | asana_list_sections | project:#{project_gid} | error:network",
          feature: "Skills Platform",
          step: "asana_list_sections",
          cid: project_gid,
          reason: :network_error
        )

        {:error, {:network_error, reason}}
    end
  end

  defp fetch_pat do
    case Application.fetch_env!(:elder, Elder.Asana)[:pat] do
      nil -> {:error, {:missing_config, :asana_pat}}
      pat -> {:ok, pat}
    end
  end

  defp authorization(pat), do: {"authorization", "Bearer #{pat}"}
end
