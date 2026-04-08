defmodule Elder.Skills.WriteTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Skills.Write

  describe "save_run/1" do
    test "persists run and splits provider:model format" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Build a task brief for the product launch campaign",
        status: :done,
        model: "google:gemini-2.5-flash",
        llm_output: "<body><h1>Task Description</h1></body>",
        cost_usd: Decimal.new("0.0021")
      }

      assert {:ok, run} = Write.save_run(attrs)
      assert run.skill_slug == "create-asana-task"
      assert run.provider == "google"
      assert run.model == "gemini-2.5-flash"
      assert run.user_id == user.id
      assert run.status == :done
    end

    test "assigns 'unknown' provider when model string has no colon" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Summarise the Q3 marketing brief into a task",
        status: :done,
        model: "gemini-2.5-flash"
      }

      assert {:ok, run} = Write.save_run(attrs)
      assert run.provider == "unknown"
      assert run.model == "gemini-2.5-flash"
    end

    test "assigns 'unknown' provider when model key is absent" do
      user = insert(:user)

      attrs = %{
        skill_slug: "create-asana-task",
        user_id: user.id,
        user_input: "Summarise the Q3 marketing brief into a task",
        status: :done
      }

      assert {:ok, run} = Write.save_run(attrs)
      assert run.provider == "unknown"
    end

    test "returns changeset error when skill_slug is missing" do
      user = insert(:user)

      attrs = %{
        user_id: user.id,
        user_input: "Create a task for the new feature rollout",
        status: :pending
      }

      assert {:error, %Ecto.Changeset{} = cs} = Write.save_run(attrs)
      assert %{skill_slug: ["can't be blank"]} = errors_on(cs)
    end
  end
end
