defmodule Elder.ExAgent.Tools.AssignUser do
  @moduledoc """
  ExAgent tool that assigns a user to an existing Asana task.

  Wraps `Elder.Asana.Client.update_task/2` with the `assignee` field.
  """

  @compile {:no_warn_undefined, Elder.Asana.ClientMock}
  @client Application.compile_env(:elder, :asana_client, Elder.Asana.Client)

  @doc "Returns the ExAgent tool definition for assigning users to Asana tasks."
  @spec tool() :: ExAgent.Tool.t()
  def tool do
    %ExAgent.Tool{
      name: "assign_user",
      description:
        "Assign a user to an existing Asana task by email or GID. " <>
          "The task must already exist.",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "task_gid" => %{"type" => "string", "description" => "GID of the task to update"},
          "assignee" => %{"type" => "string", "description" => "Email or GID of the assignee"}
        },
        "required" => ["task_gid", "assignee"]
      },
      function: &execute/1
    }
  end

  @doc """
  Assigns a user to an Asana task by email or GID.

  ## Params
    - `args` — map with `"task_gid"` and `"assignee"` (email or GID)

  ## Returns
    - `{:ok, confirmation}` on success
    - `{:error, reason}` on Asana API failure
  """
  @spec execute(map()) :: {:ok, String.t()} | {:error, term()}
  def execute(%{"task_gid" => task_gid, "assignee" => assignee}) do
    case @client.update_task(task_gid, %{"assignee" => assignee}) do
      {:ok, %{task_gid: gid}} ->
        {:ok, "Assigned #{assignee} to task #{gid}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
