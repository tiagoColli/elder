defmodule Elder.Skills.Write do
  @moduledoc """
  Write operations for the Skills context.
  """

  alias Elder.Repo
  alias Elder.Skills.Schemas.SkillRun

  @doc """
  Persists a completed skill run.

  Accepts a plain attrs map. The `:model` key (e.g. `"google:gemini-2.5-flash"`)
  is split into separate `:provider` and `:model` fields before insertion.

  Returns `{:ok, %SkillRun{}}` or `{:error, %Ecto.Changeset{}}`.
  """
  @spec save_run(map()) :: {:ok, SkillRun.t()} | {:error, Ecto.Changeset.t()}
  def save_run(attrs) do
    {provider, model} = parse_model(Map.get(attrs, :model, ""))

    attrs =
      attrs
      |> Map.put(:provider, provider)
      |> Map.put(:model, model)

    %SkillRun{}
    |> SkillRun.changeset(attrs)
    |> Repo.insert()
  end

  defp parse_model(model_string) do
    case String.split(model_string, ":", parts: 2) do
      [provider, model] -> {provider, model}
      [model] -> {"unknown", model}
    end
  end
end
