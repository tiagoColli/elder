defmodule Elder.Accounts.QueryTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Accounts.Query

  describe "get_user/1" do
    test "returns user by id" do
      user = insert(:user)
      assert %{id: id} = Query.get_user(user.id)
      assert id == user.id
    end

    test "returns nil for non-existent id" do
      assert Query.get_user(-1) == nil
    end
  end

  describe "get_user_by/1" do
    test "returns user matching clauses" do
      user = insert(:user)
      assert %{id: id} = Query.get_user_by(google_uid: user.google_uid)
      assert id == user.id
    end

    test "returns nil when no match" do
      assert Query.get_user_by(google_uid: "nonexistent") == nil
    end
  end

  describe "by_google_uid/2" do
    test "composes a query filtering by google_uid" do
      user = insert(:user)
      insert(:user)

      result = Repo.one(Query.by_google_uid(user.google_uid))

      assert result.id == user.id
    end

    test "accepts a custom queryable" do
      user = insert(:user)

      result =
        Query.base()
        |> Query.by_google_uid(user.google_uid)
        |> Repo.one()

      assert result.id == user.id
    end

    test "returns nil when google_uid does not match" do
      insert(:user)

      result = Repo.one(Query.by_google_uid("nonexistent"))

      assert result == nil
    end
  end
end
