defmodule Elder.ExAgent.AsanaAgentTest do
  use ExUnit.Case, async: false

  import Mox

  alias Elder.Asana.ClientMock
  alias Elder.ExAgent.AsanaAgent
  alias ExLLM.Providers.Mock

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Mock.reset()
    :ok
  end

  describe "run/2" do
    test "creates task and returns GID + URL on success" do
      expect(ClientMock, :create_task, fn payload ->
        assert %{"data" => data} = payload
        assert data["name"] == "Marketing launch"
        {:ok, %{task_gid: "task-123", task_url: "https://app.asana.com/0/1/task-123"}}
      end)

      call_count = :counters.new(1, [:atomics])

      Mock.set_response_handler(fn _messages, _opts ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count do
          0 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "create_task",
                  "arguments" => %{
                    "name" => "Marketing launch",
                    "html_notes" => "<body>Full brief</body>",
                    "workspace_gid" => "ws-1",
                    "project_gid" => "proj-1",
                    "section_gid" => "sect-1"
                  }
                }
              ]
            }

          _other ->
            %{content: "Done! Task created successfully.", model: "mock-model"}
        end
      end)

      draft_context = %{
        name: "Marketing launch",
        html_notes: "<body>Full brief</body>",
        due_on: nil,
        assignee_email: nil
      }

      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:ok, %{task_gid: "task-123", task_url: url}} = AsanaAgent.run(draft_context, target)
      assert url =~ "task-123"
    end

    test "creates task and assigns user when assignee_email present" do
      expect(ClientMock, :create_task, fn _payload ->
        {:ok, %{task_gid: "task-456", task_url: "https://app.asana.com/0/1/task-456"}}
      end)

      expect(ClientMock, :update_task, fn "task-456", %{"assignee" => "dev@co.com"} ->
        {:ok, %{task_gid: "task-456"}}
      end)

      call_count = :counters.new(1, [:atomics])

      Mock.set_response_handler(fn _messages, _opts ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count do
          0 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "create_task",
                  "arguments" => %{
                    "name" => "Task with assignee",
                    "html_notes" => "<body>Notes</body>",
                    "workspace_gid" => "ws-1",
                    "project_gid" => "proj-1",
                    "section_gid" => "sect-1"
                  }
                }
              ]
            }

          1 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "assign_user",
                  "arguments" => %{
                    "task_gid" => "task-456",
                    "assignee" => "dev@co.com"
                  }
                }
              ]
            }

          _other ->
            %{content: "Task created and assigned.", model: "mock-model"}
        end
      end)

      draft_context = %{
        name: "Task with assignee",
        html_notes: "<body>Notes</body>",
        due_on: nil,
        assignee_email: "dev@co.com"
      }

      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:ok, %{task_gid: "task-456"}} = AsanaAgent.run(draft_context, target)
    end

    test "returns {:error, :no_task_created} when agent produces no tool results" do
      Mock.set_response(%{content: "I cannot create a task.", model: "mock-model"})

      draft_context = %{name: "Test", html_notes: "<body>x</body>"}
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :no_task_created} = AsanaAgent.run(draft_context, target)
    end

    test "returns {:error, reason} when Asana client fails during tool execution" do
      expect(ClientMock, :create_task, fn _payload ->
        {:error, {:asana_api_error, 500, %{}}}
      end)

      call_count = :counters.new(1, [:atomics])

      Mock.set_response_handler(fn _messages, _opts ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count do
          0 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "create_task",
                  "arguments" => %{
                    "name" => "Failing task",
                    "html_notes" => "<body>x</body>",
                    "workspace_gid" => "ws-1",
                    "project_gid" => "proj-1",
                    "section_gid" => "sect-1"
                  }
                }
              ]
            }

          _other ->
            %{content: "The task creation failed.", model: "mock-model"}
        end
      end)

      draft_context = %{name: "Failing task", html_notes: "<body>x</body>"}
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :no_task_created} = AsanaAgent.run(draft_context, target)
    end
  end

  describe "build_user_message/2" do
    test "includes all draft fields and target GIDs" do
      draft_context = %{
        name: "Q4 Campaign",
        html_notes: "<body>Brief</body>",
        due_on: "2026-06-01",
        assignee_email: "owner@co.com"
      }

      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      message = AsanaAgent.build_user_message(draft_context, target)

      assert message =~ "Q4 Campaign"
      assert message =~ "<body>Brief</body>"
      assert message =~ "ws-1"
      assert message =~ "proj-1"
      assert message =~ "sect-1"
      assert message =~ "2026-06-01"
      assert message =~ "owner@co.com"
    end

    test "omits optional fields when nil" do
      draft_context = %{
        name: "Simple task",
        html_notes: "<body>x</body>",
        due_on: nil,
        assignee_email: nil
      }

      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      message = AsanaAgent.build_user_message(draft_context, target)

      assert message =~ "Simple task"
      refute message =~ "due_on"
      refute message =~ "assignee_email"
    end
  end

  describe "system_prompt/0" do
    test "mentions all three tools" do
      prompt = AsanaAgent.system_prompt()

      assert prompt =~ "create_task"
      assert prompt =~ "assign_user"
      assert prompt =~ "add_tags"
    end
  end

  describe "run/3 with PubSub topic" do
    test "broadcasts tool_started and tool_completed events for each tool call" do
      topic = "agent:test-pubsub-#{System.unique_integer([:positive])}"
      Phoenix.PubSub.subscribe(Elder.PubSub, topic)

      expect(ClientMock, :create_task, fn _payload ->
        {:ok, %{task_gid: "task-pub", task_url: "https://app.asana.com/0/1/task-pub"}}
      end)

      call_count = :counters.new(1, [:atomics])

      Mock.set_response_handler(fn _messages, _opts ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count do
          0 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "create_task",
                  "arguments" => %{
                    "name" => "PubSub test",
                    "html_notes" => "<body>notes</body>",
                    "workspace_gid" => "ws-1",
                    "project_gid" => "proj-1",
                    "section_gid" => "sect-1"
                  }
                }
              ]
            }

          _other ->
            %{content: "Done!", model: "mock-model"}
        end
      end)

      draft_context = %{name: "PubSub test", html_notes: "<body>notes</body>"}
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:ok, _result} = AsanaAgent.run(draft_context, target, topic: topic)

      assert_received {:agent_progress, :tool_started, %{tool: "create_task"}}
      assert_received {:agent_progress, :tool_completed, %{tool: "create_task"}}
    end

    test "does not broadcast when no topic is provided" do
      topic = "agent:no-broadcast-#{System.unique_integer([:positive])}"
      Phoenix.PubSub.subscribe(Elder.PubSub, topic)

      expect(ClientMock, :create_task, fn _payload ->
        {:ok, %{task_gid: "task-nb", task_url: "https://app.asana.com/0/1/task-nb"}}
      end)

      call_count = :counters.new(1, [:atomics])

      Mock.set_response_handler(fn _messages, _opts ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)

        case count do
          0 ->
            %{
              content: nil,
              model: "mock-model",
              tool_calls: [
                %{
                  "name" => "create_task",
                  "arguments" => %{
                    "name" => "No broadcast",
                    "html_notes" => "<body>x</body>",
                    "workspace_gid" => "ws-1",
                    "project_gid" => "proj-1",
                    "section_gid" => "sect-1"
                  }
                }
              ]
            }

          _other ->
            %{content: "Done!", model: "mock-model"}
        end
      end)

      draft_context = %{name: "No broadcast", html_notes: "<body>x</body>"}
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:ok, _result} = AsanaAgent.run(draft_context, target)

      refute_received {:agent_progress, _, _}
    end
  end
end
