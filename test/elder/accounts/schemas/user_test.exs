defmodule Elder.Accounts.Schemas.UserTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Accounts.Schemas.User

  describe "changeset/2" do
    test "valid with all fields" do
      attrs = params_for(:user)
      changeset = User.changeset(%User{}, attrs)

      assert changeset.valid?
    end

    test "valid without optional fields" do
      attrs = params_for(:user, name: nil, avatar_url: nil)
      changeset = User.changeset(%User{}, attrs)

      assert changeset.valid?
    end

    test "invalid without email" do
      attrs = params_for(:user, email: nil)
      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without google_uid" do
      attrs = params_for(:user, google_uid: nil)
      changeset = User.changeset(%User{}, attrs)

      refute changeset.valid?
      assert %{google_uid: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique email" do
      user = insert(:user)
      attrs = params_for(:user, email: user.email)

      {:error, changeset} =
        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "enforces unique google_uid" do
      user = insert(:user)
      attrs = params_for(:user, google_uid: user.google_uid)

      {:error, changeset} =
        %User{}
        |> User.changeset(attrs)
        |> Repo.insert()

      assert %{google_uid: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
