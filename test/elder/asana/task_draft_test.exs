defmodule Elder.Asana.TaskDraftTest do
  use ExUnit.Case, async: true

  alias Elder.Asana.TaskDraft

  describe "from_map/1" do
    test "returns ok struct with all optional fields" do
      map = %{
        "name" => "Quarterly campaign planning",
        "html_notes" => "<body><p>Full campaign description.</p></body>",
        "due_on" => "2026-05-15",
        "assignee_email" => "owner@company.com"
      }

      assert {:ok, %TaskDraft{} = draft} = TaskDraft.from_map(map)
      assert draft.name == "Quarterly campaign planning"
      assert draft.html_notes == "<body><p>Full campaign description.</p></body>"
      assert draft.due_on == "2026-05-15"
      assert draft.assignee_email == "owner@company.com"
    end

    test "returns ok with only required fields, optional fields are nil" do
      map = %{
        "name" => "Minimal task brief",
        "html_notes" => "<body><p>Minimal description.</p></body>"
      }

      assert {:ok, %TaskDraft{} = draft} = TaskDraft.from_map(map)
      assert draft.due_on == nil
      assert draft.assignee_email == nil
    end

    test "truncates name longer than 100 characters to exactly 100" do
      long_name = String.duplicate("a", 105)

      assert {:ok, draft} =
               TaskDraft.from_map(%{"name" => long_name, "html_notes" => "<body>x</body>"})

      assert String.length(draft.name) == 100
    end

    test "trims leading and trailing whitespace from html_notes" do
      map = %{"name" => "Task title", "html_notes" => "  <body>trimmed content</body>  "}

      assert {:ok, draft} = TaskDraft.from_map(map)
      assert draft.html_notes == "<body>trimmed content</body>"
    end

    test "returns nil for due_on when empty string" do
      map = %{"name" => "Task", "html_notes" => "<body>x</body>", "due_on" => ""}

      assert {:ok, draft} = TaskDraft.from_map(map)
      assert draft.due_on == nil
    end

    test "returns nil for due_on when explicitly nil" do
      map = %{"name" => "Task", "html_notes" => "<body>x</body>", "due_on" => nil}

      assert {:ok, draft} = TaskDraft.from_map(map)
      assert draft.due_on == nil
    end

    test "returns nil for assignee_email when empty string" do
      map = %{
        "name" => "Task",
        "html_notes" => "<body>x</body>",
        "assignee_email" => ""
      }

      assert {:ok, draft} = TaskDraft.from_map(map)
      assert draft.assignee_email == nil
    end

    test "returns error when name key is missing" do
      assert {:error, :invalid_task_draft} =
               TaskDraft.from_map(%{"html_notes" => "<body>x</body>"})
    end

    test "returns error when name is empty string" do
      assert {:error, :invalid_task_draft} =
               TaskDraft.from_map(%{"name" => "", "html_notes" => "<body>x</body>"})
    end

    test "returns error when html_notes key is missing" do
      assert {:error, :invalid_task_draft} = TaskDraft.from_map(%{"name" => "Task title"})
    end

    test "returns error for non-map input" do
      assert {:error, :invalid_task_draft} = TaskDraft.from_map("not a map")
    end

    test "returns error for nil input" do
      assert {:error, :invalid_task_draft} = TaskDraft.from_map(nil)
    end

    test "returns error for list input" do
      assert {:error, :invalid_task_draft} = TaskDraft.from_map(["name", "html_notes"])
    end
  end

  describe "schema/0" do
    test "returns a map with type object" do
      schema = TaskDraft.schema()

      assert is_map(schema)
      assert schema["type"] == "object"
    end

    test "marks name and html_notes as required" do
      schema = TaskDraft.schema()

      assert "name" in schema["required"]
      assert "html_notes" in schema["required"]
    end

    test "includes all expected property keys" do
      properties = TaskDraft.schema()["properties"]

      assert Map.has_key?(properties, "name")
      assert Map.has_key?(properties, "html_notes")
      assert Map.has_key?(properties, "due_on")
      assert Map.has_key?(properties, "assignee_email")
    end
  end
end
