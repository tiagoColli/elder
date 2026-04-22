defmodule Elder.ExAgent.ToolsTest do
  use ExUnit.Case, async: false

  import Mox

  alias Elder.Asana.ClientMock
  alias Elder.ExAgent.Tools.AddTags
  alias Elder.ExAgent.Tools.AssignUser
  alias Elder.ExAgent.Tools.CreateTask

  setup :verify_on_exit!

  describe "CreateTask.tool/0" do
    test "returns a valid ExAgent.Tool struct" do
      tool = CreateTask.tool()

      assert %ExAgent.Tool{} = tool
      assert tool.name == "create_task"
      assert is_binary(tool.description)
      assert is_function(tool.function, 1)

      assert tool.parameters["required"] == [
               "name",
               "html_notes",
               "workspace_gid",
               "project_gid",
               "section_gid"
             ]
    end
  end

  describe "CreateTask.execute/1" do
    test "creates task and returns success string" do
      expect(ClientMock, :create_task, fn payload ->
        assert %{"data" => data} = payload
        assert data["name"] == "Test task"
        {:ok, %{task_gid: "gid-1", task_url: "https://app.asana.com/0/1/2"}}
      end)

      args = %{
        "name" => "Test task",
        "html_notes" => "<body><p>Notes</p></body>",
        "workspace_gid" => "ws-1",
        "project_gid" => "proj-1",
        "section_gid" => "sect-1"
      }

      assert {:ok, result} = CreateTask.execute(args)
      assert result =~ "Task created"
      assert result =~ "gid-1"
    end

    test "propagates Asana API errors" do
      expect(ClientMock, :create_task, fn _payload ->
        {:error, {:asana_api_error, 400, %{}}}
      end)

      args = %{
        "name" => "Test task",
        "html_notes" => "<body>x</body>",
        "workspace_gid" => "ws-1",
        "project_gid" => "proj-1",
        "section_gid" => "sect-1"
      }

      assert {:error, {:asana_api_error, 400, _body}} = CreateTask.execute(args)
    end

    test "returns payload error for missing workspace" do
      args = %{
        "name" => "Task",
        "html_notes" => "<body>x</body>",
        "workspace_gid" => nil,
        "project_gid" => "proj-1",
        "section_gid" => "sect-1"
      }

      assert {:error, {:payload_error, :missing_workspace}} = CreateTask.execute(args)
    end
  end

  describe "AssignUser.tool/0" do
    test "returns a valid ExAgent.Tool struct" do
      tool = AssignUser.tool()

      assert %ExAgent.Tool{} = tool
      assert tool.name == "assign_user"
      assert is_binary(tool.description)
      assert is_function(tool.function, 1)
      assert tool.parameters["required"] == ["task_gid", "assignee"]
    end
  end

  describe "AssignUser.execute/1" do
    test "assigns user and returns success string" do
      expect(ClientMock, :update_task, fn "task-1", %{"assignee" => "dev@co.com"} ->
        {:ok, %{task_gid: "task-1"}}
      end)

      assert {:ok, result} =
               AssignUser.execute(%{"task_gid" => "task-1", "assignee" => "dev@co.com"})

      assert result =~ "Assigned dev@co.com to task task-1"
    end

    test "propagates errors from client" do
      expect(ClientMock, :update_task, fn _gid, _fields ->
        {:error, {:asana_api_error, 403, %{}}}
      end)

      assert {:error, {:asana_api_error, 403, _body}} =
               AssignUser.execute(%{"task_gid" => "task-1", "assignee" => "bad"})
    end
  end

  describe "AddTags.tool/0" do
    test "returns a valid ExAgent.Tool struct" do
      tool = AddTags.tool()

      assert %ExAgent.Tool{} = tool
      assert tool.name == "add_tags"
      assert is_binary(tool.description)
      assert is_function(tool.function, 1)
      assert tool.parameters["required"] == ["task_gid", "tag_gid"]
    end
  end

  describe "AddTags.execute/1" do
    test "adds tag and returns success string" do
      expect(ClientMock, :add_tag_to_task, fn "task-1", "tag-99" -> :ok end)

      assert {:ok, result} = AddTags.execute(%{"task_gid" => "task-1", "tag_gid" => "tag-99"})
      assert result =~ "Added tag tag-99 to task task-1"
    end

    test "propagates errors from client" do
      expect(ClientMock, :add_tag_to_task, fn _gid, _tag ->
        {:error, {:asana_api_error, 404, %{}}}
      end)

      assert {:error, {:asana_api_error, 404, _body}} =
               AddTags.execute(%{"task_gid" => "task-1", "tag_gid" => "bad"})
    end
  end
end
