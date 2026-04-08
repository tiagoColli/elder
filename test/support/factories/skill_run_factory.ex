defmodule Elder.SkillRunFactory do
  @moduledoc false

  alias Elder.Skills.Schemas.SkillRun

  defmacro __using__(_opts) do
    quote do
      def skill_run_factory do
        %SkillRun{
          skill_slug: "create-asana-task",
          user_input: sequence(:user_input, &"Create task #{&1} for the product launch campaign"),
          status: :done,
          llm_output: "<body><h1>Task Description</h1><p>Detailed task content here.</p></body>",
          provider: "google",
          model: "gemini-2.5-flash",
          cost_usd: Decimal.new("0.0020"),
          user: build(:user)
        }
      end
    end
  end
end
