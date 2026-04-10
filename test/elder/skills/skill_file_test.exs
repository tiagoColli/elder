defmodule Elder.Skills.SkillFileTest do
  use ExUnit.Case, async: true

  alias Elder.Skills.SkillFile

  describe "read!/1" do
    test "returns a skill map with all expected keys for a known slug" do
      skill = SkillFile.read!("create-asana-task")

      assert %{
               slug: "create-asana-task",
               name: _name,
               description: _desc,
               version: _version,
               system_prompt: _prompt,
               review_slug: _review_slug,
               output_format: _format
             } = skill
    end

    test "slug field matches the requested slug" do
      skill = SkillFile.read!("create-asana-task")

      assert skill.slug == "create-asana-task"
    end

    test "parses output_format as atom when present" do
      skill = SkillFile.read!("create-asana-task")

      assert skill.output_format == :structured_asana_task
    end

    test "sets review_slug when review frontmatter is present" do
      skill = SkillFile.read!("create-asana-task")

      assert skill.review_slug == "create-asana-task-review"
    end

    test "review_slug is nil when review frontmatter is absent" do
      skill = SkillFile.read!("create-asana-task-review")

      assert skill.review_slug == nil
    end

    test "output_format is nil when output_format frontmatter is absent" do
      skill = SkillFile.read!("create-asana-task-review")

      assert skill.output_format == nil
    end

    test "system_prompt is a non-empty string" do
      skill = SkillFile.read!("create-asana-task")

      assert is_binary(skill.system_prompt)
      assert byte_size(skill.system_prompt) > 0
    end

    test "system_prompt includes included dependency content when includes is set" do
      skill = SkillFile.read!("create-asana-task")

      assert String.contains?(skill.system_prompt, "---")
    end

    test "raises when skill slug does not exist" do
      assert_raise RuntimeError, ~r/Skill not found/, fn ->
        SkillFile.read!("nonexistent-skill-xyz")
      end
    end
  end

  describe "list!/0" do
    test "returns a non-empty list of skill maps" do
      skills = SkillFile.list!()

      assert is_list(skills)
      assert skills != []
    end

    test "each skill has the expected keys" do
      skills = SkillFile.list!()

      Enum.each(skills, fn skill ->
        assert Map.has_key?(skill, :slug)
        assert Map.has_key?(skill, :name)
        assert Map.has_key?(skill, :system_prompt)
        assert Map.has_key?(skill, :review_slug)
        assert Map.has_key?(skill, :output_format)
      end)
    end

    test "does not include skills under standards/ prefix" do
      slugs = Enum.map(SkillFile.list!(), & &1.slug)

      refute Enum.any?(slugs, &String.starts_with?(&1, "standards/"))
    end

    test "includes create-asana-task and create-asana-task-review" do
      slugs = Enum.map(SkillFile.list!(), & &1.slug)

      assert "create-asana-task" in slugs
      assert "create-asana-task-review" in slugs
    end
  end
end
