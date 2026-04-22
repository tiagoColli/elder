defmodule Elder.ExAgent.Tools.AddTags do
  @moduledoc """
  ExAgent tool that adds a tag to an existing Asana task.

  Wraps `Elder.Asana.Client.add_tag_to_task/2`.
  """

  @compile {:no_warn_undefined, Elder.Asana.ClientMock}
  @client Application.compile_env(:elder, :asana_client, Elder.Asana.Client)

  @doc "Returns the ExAgent tool definition for adding tags to Asana tasks."
  @spec tool() :: ExAgent.Tool.t()
  def tool do
    %ExAgent.Tool{
      name: "add_tags",
      description:
        "Add a tag to an existing Asana task. " <>
          "Both the task and the tag must already exist.",
      parameters: %{
        "type" => "object",
        "properties" => %{
          "task_gid" => %{"type" => "string", "description" => "GID of the task"},
          "tag_gid" => %{"type" => "string", "description" => "GID of the tag to add"}
        },
        "required" => ["task_gid", "tag_gid"]
      },
      function: &execute/1
    }
  end

  @doc """
  Adds a tag to an Asana task.

  ## Params
    - `args` — map with `"task_gid"` and `"tag_gid"` strings

  ## Returns
    - `{:ok, confirmation}` on success
    - `{:error, reason}` on Asana API failure
  """
  @spec execute(map()) :: {:ok, String.t()} | {:error, term()}
  def execute(%{"task_gid" => task_gid, "tag_gid" => tag_gid}) do
    case @client.add_tag_to_task(task_gid, tag_gid) do
      :ok ->
        {:ok, "Added tag #{tag_gid} to task #{task_gid}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
