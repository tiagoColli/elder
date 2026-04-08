defmodule Elder.Repo.Migrations.CreateSkillRuns do
  use Ecto.Migration

  def change do
    create table(:skill_runs) do
      add :skill_slug, :string, null: false
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :user_input, :text, null: false
      add :llm_output, :text
      add :status, :string, null: false, default: "pending"
      add :provider, :string
      add :model, :string
      add :cost_usd, :decimal

      timestamps(type: :utc_datetime)
    end

    create index(:skill_runs, [:user_id])
    create index(:skill_runs, [:skill_slug])
  end
end
