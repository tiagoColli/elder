defmodule Elder.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :name, :string
      add :avatar_url, :string
      add :google_uid, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:google_uid])
    create unique_index(:users, [:email])
  end
end
