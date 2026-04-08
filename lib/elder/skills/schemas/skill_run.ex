defmodule Elder.Skills.Schemas.SkillRun do
  @moduledoc """
  Persisted record of a single skill execution.

  Tracks the user input, LLM output, cost, and lifecycle status for each run.
  Skills are file-based and referenced by slug (no FK constraint).
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Elder.Accounts.Schemas.User

  @type t :: %__MODULE__{}

  schema "skill_runs" do
    field :skill_slug, :string
    field :user_input, :string
    field :llm_output, :string
    field :status, Ecto.Enum, values: [:pending, :streaming, :done, :error], default: :pending
    field :provider, :string
    field :model, :string
    field :cost_usd, :decimal

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @required [:skill_slug, :user_id, :user_input, :status]
  @optional [:llm_output, :provider, :model, :cost_usd]

  @doc false
  def changeset(skill_run, attrs) do
    skill_run
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:user_input, min: 1)
    |> assoc_constraint(:user)
  end
end
