defmodule Elder.Accounts.Write do
  @moduledoc """
  Write operations for user accounts. Handles user creation and updates via OAuth data.
  """

  alias Elder.Accounts.Query
  alias Elder.Accounts.Schemas.User
  alias Elder.Repo

  require Logger

  @spec find_or_create_user(Ueberauth.Auth.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_user(%Ueberauth.Auth{} = auth) do
    attrs = extract_user_attrs(auth)

    case Query.get_user_by(google_uid: attrs.google_uid) do
      nil -> create_user(attrs)
      user -> update_user(user, attrs)
    end
  end

  defp create_user(attrs) do
    result =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} ->
        Logger.info("Accounts | create_user | user_id:#{user.id} | ok",
          feature: "Accounts",
          step: "create_user"
        )

      {:error, _changeset} ->
        Logger.error("Accounts | create_user | error:insert_failed",
          feature: "Accounts",
          step: "create_user"
        )
    end

    result
  end

  defp update_user(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  defp extract_user_attrs(%Ueberauth.Auth{uid: uid, info: info}) do
    %{
      google_uid: to_string(uid),
      email: info.email,
      name: info.name,
      avatar_url: info.image
    }
  end
end
