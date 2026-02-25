defmodule Elder.Accounts.Query do
  @moduledoc """
  Read queries for user accounts. Composable query functions follow the queryable-in/queryable-out pattern.
  """

  import Ecto.Query

  alias Elder.Accounts.Schemas.User
  alias Elder.Repo

  @spec get_user(integer()) :: User.t() | nil
  def get_user(id), do: Repo.get(User, id)

  @spec get_user_by(keyword() | map()) :: User.t() | nil
  def get_user_by(clauses), do: Repo.get_by(User, clauses)

  @spec base :: Ecto.Queryable.t()
  def base, do: User

  @spec by_google_uid(Ecto.Queryable.t(), String.t()) :: Ecto.Query.t()
  def by_google_uid(queryable \\ base(), google_uid) do
    where(queryable, [u], u.google_uid == ^google_uid)
  end
end
