defmodule Elder.Skills.Schemas.SkillRunTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Skills.Schemas.SkillRun

  describe "changeset/2" do
    test "valid with required and optional fields" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Write a brief for the new product launch campaign",
        status: :done,
        llm_output: "<body><h1>Task</h1></body>",
        provider: "google",
        model: "gemini-2.5-flash",
        cost_usd: Decimal.new("0.0023")
      }

      changeset = SkillRun.changeset(%SkillRun{}, attrs)

      assert changeset.valid?
    end

    test "valid without optional fields" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Generate a task description for the new onboarding flow",
        status: :pending
      }

      changeset = SkillRun.changeset(%SkillRun{}, attrs)

      assert changeset.valid?
    end

    test "invalid without skill_slug" do
      user = insert(:user)

      attrs = %{user_id: user.id, user_input: "Some brief input", status: :pending}
      changeset = SkillRun.changeset(%SkillRun{}, attrs)

      refute changeset.valid?
      assert %{skill_slug: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without user_input" do
      user = insert(:user)

      attrs = %{skill_slug: "create-asana-task", user_id: user.id, status: :pending}
      changeset = SkillRun.changeset(%SkillRun{}, attrs)

      refute changeset.valid?
      assert %{user_input: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid when user_input is an empty string" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "",
        status: :pending
      }

      changeset = SkillRun.changeset(%SkillRun{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset)[:user_input]
    end

    test "defaults status to :pending when not provided" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Build a task description for the marketing brief"
      }

      {:ok, run} =
        %SkillRun{}
        |> SkillRun.changeset(attrs)
        |> Repo.insert()

      assert run.status == :pending
    end

    test "returns assoc constraint error when user does not exist" do
      attrs = %{
        skill_slug: "create-asana-task",
        user_id: -1,
        user_input: "Build a task description for the marketing brief",
        status: :pending
      }

      {:error, changeset} =
        %SkillRun{}
        |> SkillRun.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end
  end
end
