defmodule Elder.Accounts do
  @moduledoc """
  Public API for user accounts.

  Delegates reads to `Elder.Accounts.Query` and writes to `Elder.Accounts.Write`.
  """

  alias Elder.Accounts.Schemas.User

  @doc "Fetches a user by primary key. Returns `nil` if not found."
  @spec get_user(integer()) :: User.t() | nil
  defdelegate get_user(id), to: Elder.Accounts.Query

  @doc "Finds an existing user by Google UID or creates one. Updates name/avatar on each login."
  @spec find_or_create_user(Ueberauth.Auth.t()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  defdelegate find_or_create_user(auth), to: Elder.Accounts.Write
end
