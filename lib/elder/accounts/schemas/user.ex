defmodule Elder.Accounts.Schemas.User do
  @moduledoc """
  Ecto schema for the `users` table.

  Stores identity data sourced from Google OAuth (email, name, avatar, UID).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :name, :string
    field :avatar_url, :string
    field :google_uid, :string

    timestamps(type: :utc_datetime)
  end

  @doc "Casts and validates user attributes. Requires `:email` and `:google_uid`."
  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :avatar_url, :google_uid])
    |> validate_required([:email, :google_uid])
    |> unique_constraint(:google_uid)
    |> unique_constraint(:email)
  end
end
