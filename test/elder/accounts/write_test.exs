defmodule Elder.Accounts.WriteTest do
  use Elder.DataCase, async: true

  import Elder.Factory

  alias Elder.Accounts.Write

  describe "find_or_create_user/1" do
    test "creates a new user from auth data" do
      auth = build(:ueberauth_auth)

      assert {:ok, user} = Write.find_or_create_user(auth)
      assert user.email == auth.info.email
      assert user.name == auth.info.name
      assert user.google_uid == to_string(auth.uid)
      assert user.avatar_url == auth.info.image
      assert user.id
    end

    test "updates existing user on subsequent login" do
      existing = insert(:user)

      auth =
        build(:ueberauth_auth,
          uid: existing.google_uid,
          info: %Ueberauth.Auth.Info{
            email: existing.email,
            name: "Updated Name",
            image: "https://example.com/new-avatar.png"
          }
        )

      assert {:ok, user} = Write.find_or_create_user(auth)
      assert user.id == existing.id
      assert user.name == "Updated Name"
      assert user.avatar_url == "https://example.com/new-avatar.png"
    end

    test "returns error when required fields are missing" do
      auth =
        build(:ueberauth_auth,
          uid: nil,
          info: %Ueberauth.Auth.Info{email: nil, name: nil, image: nil}
        )

      assert {:error, %Ecto.Changeset{}} = Write.find_or_create_user(auth)
    end
  end
end
