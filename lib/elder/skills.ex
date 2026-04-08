defmodule Elder.Skills do
  @moduledoc """
  Public facade for the Skills context.

  Skills themselves are file-based (see `Elder.Skills.SkillFile`).
  Skill run persistence is delegated to `Query` and `Write`.
  """

  alias Elder.Skills.Query
  alias Elder.Skills.SkillFile
  alias Elder.Skills.Write

  @doc "Returns all available skills sorted alphabetically by name."
  @spec list_skills() :: [SkillFile.skill()]
  def list_skills do
    Enum.sort_by(SkillFile.list!(), & &1.name)
  end

  @doc "Returns a single skill by slug. Raises if not found."
  @spec get_skill!(String.t()) :: SkillFile.skill()
  def get_skill!(slug), do: SkillFile.read!(slug)

  defdelegate list_runs_for_user(user_id), to: Query
  defdelegate save_run(attrs), to: Write
end
