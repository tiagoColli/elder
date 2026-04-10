defmodule Elder.Asana.Payloads.CreateTaskPayloadTest do
  use ExUnit.Case, async: true

  alias Elder.Asana.Payloads.CreateTaskPayload
  alias Elder.Asana.TaskDraft

  defp skill_run(opts \\ []) do
    %{
      user_input: Keyword.get(opts, :user_input, "Create a social media campaign brief"),
      llm_output:
        Keyword.get(
          opts,
          :llm_output,
          ~S({"name":"Q4 Campaign Brief","html_notes":"<body><p>Campaign details.</p></body>"})
        )
    }
  end

  defp valid_target do
    %{workspace_gid: "ws-123", project_gid: "proj-456", section_gid: "sect-789"}
  end

  describe "build/2" do
    test "returns ok payload with all fields from llm_output JSON" do
      run =
        skill_run(
          llm_output:
            ~S({"name":"Product launch brief","html_notes":"<body><p>Details.</p></body>","due_on":"2026-06-01","assignee_email":"owner@company.com"})
        )

      assert {:ok, %CreateTaskPayload{} = payload} = CreateTaskPayload.build(run, valid_target())
      assert payload.name == "Product launch brief"
      assert payload.html_notes == "<body><p>Details.</p></body>"
      assert payload.due_on == "2026-06-01"
      assert payload.assignee_email == "owner@company.com"
      assert payload.workspace_gid == "ws-123"
      assert payload.project_gid == "proj-456"
      assert payload.section_gid == "sect-789"
    end

    test "falls back to user_input as name when parsed JSON has no name field" do
      run =
        skill_run(
          user_input: "Handover task for engineering team",
          llm_output: ~S({"html_notes":"<body><p>Notes here.</p></body>"})
        )

      assert {:ok, payload} = CreateTaskPayload.build(run, valid_target())
      assert payload.name == "Handover task for engineering team"
    end

    test "parses JSON wrapped in a markdown code fence" do
      run =
        skill_run(
          llm_output: """
          ```json
          {"name":"Fenced task","html_notes":"<body>ok</body>"}
          ```
          """
        )

      assert {:ok, payload} = CreateTaskPayload.build(run, valid_target())
      assert payload.name == "Fenced task"
    end

    test "truncates name from JSON to 100 characters" do
      long_name = String.duplicate("n", 110)

      run =
        skill_run(
          llm_output: Jason.encode!(%{"name" => long_name, "html_notes" => "<body>x</body>"})
        )

      assert {:ok, payload} = CreateTaskPayload.build(run, valid_target())
      assert String.length(payload.name) == 100
    end

    test "returns nil for due_on when JSON field is empty string" do
      run =
        skill_run(
          llm_output:
            ~S({"name":"Task","html_notes":"<body>x</body>","due_on":"","assignee_email":null})
        )

      assert {:ok, payload} = CreateTaskPayload.build(run, valid_target())
      assert payload.due_on == nil
    end

    test "returns error when name is missing from both JSON and user_input" do
      run = skill_run(user_input: "", llm_output: ~S({"html_notes":"<body>x</body>"}))

      assert {:error, :missing_name} = CreateTaskPayload.build(run, valid_target())
    end

    test "returns error when workspace_gid is nil" do
      target = %{workspace_gid: nil, project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :missing_workspace} = CreateTaskPayload.build(skill_run(), target)
    end

    test "returns error when workspace_gid is empty string" do
      target = %{workspace_gid: "", project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :missing_workspace} = CreateTaskPayload.build(skill_run(), target)
    end

    test "returns error when project_gid is nil" do
      target = %{workspace_gid: "ws-1", project_gid: nil, section_gid: "sect-1"}

      assert {:error, :missing_project} = CreateTaskPayload.build(skill_run(), target)
    end

    test "returns error when section_gid is nil" do
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: nil}

      assert {:error, :missing_section} = CreateTaskPayload.build(skill_run(), target)
    end
  end

  describe "from_draft/2" do
    defp valid_draft(opts \\ []) do
      %TaskDraft{
        name: Keyword.get(opts, :name, "Audit log page implementation"),
        html_notes: "<body><p>Build a read-only audit log page.</p></body>",
        due_on: Keyword.get(opts, :due_on, nil),
        assignee_email: Keyword.get(opts, :assignee_email, nil)
      }
    end

    test "returns ok payload from a full draft and target" do
      draft = valid_draft(due_on: "2026-07-01", assignee_email: "dev@company.com")

      assert {:ok, %CreateTaskPayload{} = payload} =
               CreateTaskPayload.from_draft(draft, valid_target())

      assert payload.name == "Audit log page implementation"
      assert payload.html_notes == "<body><p>Build a read-only audit log page.</p></body>"
      assert payload.due_on == "2026-07-01"
      assert payload.assignee_email == "dev@company.com"
      assert payload.workspace_gid == "ws-123"
    end

    test "truncates draft name exceeding 100 characters" do
      draft = valid_draft(name: String.duplicate("t", 105))

      assert {:ok, payload} = CreateTaskPayload.from_draft(draft, valid_target())
      assert String.length(payload.name) == 100
    end

    test "returns error when draft name is nil" do
      draft = %TaskDraft{
        name: nil,
        html_notes: "<body>x</body>",
        due_on: nil,
        assignee_email: nil
      }

      assert {:error, :missing_name} = CreateTaskPayload.from_draft(draft, valid_target())
    end

    test "returns error when draft name is empty string" do
      draft = %TaskDraft{name: "", html_notes: "<body>x</body>", due_on: nil, assignee_email: nil}

      assert {:error, :missing_name} = CreateTaskPayload.from_draft(draft, valid_target())
    end

    test "returns error when workspace_gid is nil" do
      target = %{workspace_gid: nil, project_gid: "proj-1", section_gid: "sect-1"}

      assert {:error, :missing_workspace} = CreateTaskPayload.from_draft(valid_draft(), target)
    end

    test "returns error when project_gid is blank" do
      target = %{workspace_gid: "ws-1", project_gid: "", section_gid: "sect-1"}

      assert {:error, :missing_project} = CreateTaskPayload.from_draft(valid_draft(), target)
    end

    test "returns error when section_gid is nil" do
      target = %{workspace_gid: "ws-1", project_gid: "proj-1", section_gid: nil}

      assert {:error, :missing_section} = CreateTaskPayload.from_draft(valid_draft(), target)
    end
  end

  describe "to_api_map/1" do
    defp base_payload(overrides \\ %{}) do
      Map.merge(
        %CreateTaskPayload{
          name: "Restructure onboarding flow",
          workspace_gid: "ws-111",
          project_gid: "proj-222",
          section_gid: "sect-333",
          html_notes: nil,
          due_on: nil,
          assignee_email: nil
        },
        overrides
      )
    end

    test "wraps result under data key with required base fields" do
      result = CreateTaskPayload.to_api_map(base_payload())

      assert %{"data" => data} = result
      assert data["name"] == "Restructure onboarding flow"
      assert data["workspace"] == "ws-111"
      assert data["projects"] == ["proj-222"]
      assert data["memberships"] == [%{"project" => "proj-222", "section" => "sect-333"}]
    end

    test "includes html_notes when present" do
      payload = base_payload(%{html_notes: "<body><p>Notes here.</p></body>"})

      assert %{"data" => data} = CreateTaskPayload.to_api_map(payload)
      assert data["html_notes"] == "<body><p>Notes here.</p></body>"
    end

    test "excludes html_notes when nil" do
      result = CreateTaskPayload.to_api_map(base_payload())

      refute Map.has_key?(result["data"], "html_notes")
    end

    test "excludes html_notes when empty string" do
      payload = base_payload(%{html_notes: ""})
      result = CreateTaskPayload.to_api_map(payload)

      refute Map.has_key?(result["data"], "html_notes")
    end

    test "includes due_on when set" do
      payload = base_payload(%{due_on: "2026-08-20"})

      assert %{"data" => data} = CreateTaskPayload.to_api_map(payload)
      assert data["due_on"] == "2026-08-20"
    end

    test "excludes due_on when nil" do
      result = CreateTaskPayload.to_api_map(base_payload())

      refute Map.has_key?(result["data"], "due_on")
    end

    test "includes assignee when email is set" do
      payload = base_payload(%{assignee_email: "assignee@company.com"})

      assert %{"data" => data} = CreateTaskPayload.to_api_map(payload)
      assert data["assignee"] == "assignee@company.com"
    end

    test "excludes assignee when email is nil" do
      result = CreateTaskPayload.to_api_map(base_payload())

      refute Map.has_key?(result["data"], "assignee")
    end
  end
end
