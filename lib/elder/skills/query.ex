defmodule Elder.Skills.Query do
  @moduledoc """
  Composable read queries for the Skills context.
  """

  import Ecto.Query

  alias Elder.Repo
  alias Elder.Skills.Schemas.SkillRun

  @doc "Returns all skill runs for a given user, newest first."
  @spec list_runs_for_user(integer()) :: [SkillRun.t()]
  def list_runs_for_user(user_id) do
    SkillRun
    |> where([r], r.user_id == ^user_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end
end
