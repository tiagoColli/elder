defmodule Elder.Skills.QueryTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Skills.Query
  alias Elder.Skills.Schemas.SkillRun

  describe "list_runs_for_user/1" do
    test "returns skill runs for the given user ordered newest first" do
      user = insert(:user)

      older_run = insert(:skill_run, user: user)
      newer_run = insert(:skill_run, user: user)

      now = DateTime.truncate(DateTime.utc_now(), :second)
      old_time = DateTime.add(now, -120, :second)

      older_query = from(r in SkillRun, where: r.id == ^older_run.id)
      Repo.update_all(older_query, set: [inserted_at: old_time])

      newer_query = from(r in SkillRun, where: r.id == ^newer_run.id)
      Repo.update_all(newer_query, set: [inserted_at: now])

      result = Query.list_runs_for_user(user.id)

      assert [%{id: first_id}, %{id: second_id}] = result
      assert first_id == newer_run.id
      assert second_id == older_run.id
    end

    test "returns empty list when user has no runs" do
      user = insert(:user)

      assert [] = Query.list_runs_for_user(user.id)
    end

    test "does not return runs belonging to another user" do
      user = insert(:user)
      other_user = insert(:user)

      insert(:skill_run, user: other_user)

      assert [] = Query.list_runs_for_user(user.id)
    end
  end
end
