defmodule Elder.AsanaTest do
  use ExUnit.Case, async: true

  import Mox

  alias Elder.Asana
  alias Elder.Asana.TaskDraft

  setup :verify_on_exit!

  defp skill_run do
    %{
      user_input: "Create a brief for the Q4 product launch campaign",
      llm_output:
        ~S({"name":"Q4 Product Launch","html_notes":"<body><p>Campaign details.</p></body>"})
    }
  end

  defp valid_target do
    %{workspace_gid: "ws-111", project_gid: "proj-222", section_gid: "sect-333"}
  end

  describe "create_task/2" do
    test "builds payload and delegates to the client, returning task info" do
      stub(Elder.Asana.ClientMock, :create_task, fn _payload ->
        {:ok, %{task_gid: "task-999", task_url: "https://app.asana.com/0/proj/task-999"}}
      end)

      assert {:ok, %{task_gid: "task-999", task_url: "https://app.asana.com/0/proj/task-999"}} =
               Asana.create_task(skill_run(), valid_target())
    end

    test "passes the built payload with correct workspace to the client" do
      test_pid = self()

      stub(Elder.Asana.ClientMock, :create_task, fn payload ->
        send(test_pid, {:captured_payload, payload})
        {:ok, %{task_gid: "t1", task_url: "https://app.asana.com/t1"}}
      end)

      Asana.create_task(skill_run(), valid_target())

      assert_receive {:captured_payload, payload}
      assert get_in(payload, ["data", "workspace"]) == "ws-111"
    end

    test "returns payload error when workspace_gid is missing" do
      target = %{workspace_gid: nil, project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, {:payload_error, :missing_workspace}} =
               Asana.create_task(skill_run(), target)
    end

    test "returns payload error when section_gid is missing" do
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: nil}

      assert {:error, {:payload_error, :missing_section}} =
               Asana.create_task(skill_run(), target)
    end

    test "propagates client error response" do
      stub(Elder.Asana.ClientMock, :create_task, fn _payload ->
        {:error, {:asana_api_error, 403, %{"errors" => [%{"message" => "Forbidden"}]}}}
      end)

      assert {:error, {:asana_api_error, 403, _details}} =
               Asana.create_task(skill_run(), valid_target())
    end
  end

  describe "create_task_from_draft/2" do
    defp valid_draft do
      %TaskDraft{
        name: "Handover documentation for engineering",
        html_notes: "<body><p>Document the handover process.</p></body>",
        due_on: nil,
        assignee_email: nil
      }
    end

    test "builds payload from draft and delegates to the client" do
      stub(Elder.Asana.ClientMock, :create_task, fn _payload ->
        {:ok, %{task_gid: "task-draft-1", task_url: "https://app.asana.com/0/proj/draft-1"}}
      end)

      assert {:ok, %{task_gid: "task-draft-1"}} =
               Asana.create_task_from_draft(valid_draft(), valid_target())
    end

    test "returns payload error when draft name is blank" do
      draft = %TaskDraft{
        name: nil,
        html_notes: "<body>x</body>",
        due_on: nil,
        assignee_email: nil
      }

      assert {:error, {:payload_error, :missing_name}} =
               Asana.create_task_from_draft(draft, valid_target())
    end

    test "returns payload error when project_gid is missing" do
      target = %{workspace_gid: "ws-1", project_gid: nil, section_gid: "sect-1"}

      assert {:error, {:payload_error, :missing_project}} =
               Asana.create_task_from_draft(valid_draft(), target)
    end
  end

  describe "list_workspaces/0" do
    test "returns workspace list from the client" do
      workspaces = [%{gid: "ws-1", name: "Acme Corp"}, %{gid: "ws-2", name: "Design Team"}]
      stub(Elder.Asana.ClientMock, :list_workspaces, fn -> {:ok, workspaces} end)

      assert {:ok, ^workspaces} = Asana.list_workspaces()
    end

    test "propagates client error" do
      stub(Elder.Asana.ClientMock, :list_workspaces, fn ->
        {:error, {:asana_api_error, 401, %{}}}
      end)

      assert {:error, {:asana_api_error, 401, _details}} = Asana.list_workspaces()
    end
  end

  describe "list_projects/1" do
    test "returns project list for the given workspace" do
      projects = [%{gid: "proj-1", name: "Marketing Q4"}, %{gid: "proj-2", name: "Engineering"}]
      stub(Elder.Asana.ClientMock, :list_projects, fn _workspace_gid -> {:ok, projects} end)

      assert {:ok, ^projects} = Asana.list_projects("ws-111")
    end

    test "propagates client error" do
      stub(Elder.Asana.ClientMock, :list_projects, fn _gid ->
        {:error, {:asana_api_error, 404, %{}}}
      end)

      assert {:error, {:asana_api_error, 404, _details}} = Asana.list_projects("ws-111")
    end
  end

  describe "list_sections/1" do
    test "returns sections list for the given project" do
      sections = [%{gid: "sect-1", name: "To Do"}, %{gid: "sect-2", name: "In Progress"}]
      stub(Elder.Asana.ClientMock, :list_sections, fn _project_gid -> {:ok, sections} end)

      assert {:ok, ^sections} = Asana.list_sections("proj-222")
    end

    test "propagates client error" do
      stub(Elder.Asana.ClientMock, :list_sections, fn _gid ->
        {:error, {:network_error, :econnrefused}}
      end)

      assert {:error, {:network_error, :econnrefused}} = Asana.list_sections("proj-222")
    end
  end
end
