defmodule Elder.Asana.TaskBuilderTest do
  use ExUnit.Case, async: true

  alias Elder.Asana.TaskBuilder
  alias Elder.Asana.TaskDraft

  defp skill_run(opts \\ []) do
    %{
      user_input: Keyword.get(opts, :user_input, "Redesign the onboarding flow"),
      llm_output:
        Keyword.get(
          opts,
          :llm_output,
          ~S({"name":"Onboarding redesign","html_notes":"<body><p>Details.</p></body>"})
        )
    }
  end

  defp valid_target do
    %{workspace_gid: "ws-abc", project_gid: "proj-def", section_gid: "sect-ghi"}
  end

  describe "build/2" do
    test "returns ok with api-ready map for valid skill run and target" do
      assert {:ok, map} = TaskBuilder.build(skill_run(), valid_target())

      assert %{"data" => data} = map
      assert data["name"] == "Onboarding redesign"
      assert data["workspace"] == "ws-abc"
    end

    test "returns error when workspace_gid is missing" do
      target = %{workspace_gid: nil, project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :missing_workspace} = TaskBuilder.build(skill_run(), target)
    end

    test "returns error when section_gid is missing" do
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: nil}

      assert {:error, :missing_section} = TaskBuilder.build(skill_run(), target)
    end
  end

  describe "build_from_draft/2" do
    defp valid_draft do
      %TaskDraft{
        name: "Audit log feature",
        html_notes: "<body><p>Build the audit log page.</p></body>",
        due_on: "2026-09-01",
        assignee_email: "dev@company.com"
      }
    end

    test "returns ok with api-ready map for valid draft and target" do
      assert {:ok, map} = TaskBuilder.build_from_draft(valid_draft(), valid_target())

      assert %{"data" => data} = map
      assert data["name"] == "Audit log feature"
      assert data["workspace"] == "ws-abc"
      assert data["html_notes"] == "<body><p>Build the audit log page.</p></body>"
    end

    test "returns error when draft name is blank" do
      draft = %TaskDraft{
        name: nil,
        html_notes: "<body>x</body>",
        due_on: nil,
        assignee_email: nil
      }

      assert {:error, :missing_name} = TaskBuilder.build_from_draft(draft, valid_target())
    end

    test "returns error when project_gid is missing" do
      target = %{workspace_gid: "ws-1", project_gid: nil, section_gid: "sect-1"}

      assert {:error, :missing_project} = TaskBuilder.build_from_draft(valid_draft(), target)
    end
  end
end
