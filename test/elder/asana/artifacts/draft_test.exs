defmodule Elder.Asana.Artifacts.DraftTest do
  use ExUnit.Case, async: true

  alias Elder.Asana.Artifacts.Draft

  describe "to_transcript/1" do
    test "returns formatted transcript with all fields populated" do
      draft = %Draft{
        name: "Q4 Product Launch",
        description: "Full campaign brief for the product launch",
        responsible_email: "marketing@company.com",
        due_on: "2026-06-15"
      }

      result = Draft.to_transcript(draft)

      assert result =~ "Draft —"
      assert result =~ "name: Q4 Product Launch"
      assert result =~ "responsible_email: marketing@company.com"
      assert result =~ "description: Full campaign brief for the product launch"
      assert result =~ "due_on: 2026-06-15"
    end

    test "omits nil fields from transcript" do
      draft = %Draft{
        name: "Task with owner",
        responsible_email: "owner@company.com",
        description: nil,
        due_on: nil
      }

      result = Draft.to_transcript(draft)

      assert result =~ "name: Task with owner"
      assert result =~ "responsible_email: owner@company.com"
      refute result =~ "description:"
      refute result =~ "due_on:"
    end

    test "omits empty string fields from transcript" do
      draft = %Draft{
        name: "Minimal task",
        description: "",
        responsible_email: "",
        due_on: ""
      }

      result = Draft.to_transcript(draft)

      assert result =~ "name: Minimal task"
      refute result =~ "responsible_email:"
      refute result =~ "description:"
      refute result =~ "due_on:"
    end

    test "includes skipped_fields when present" do
      draft = %Draft{
        name: "Task with skips",
        description: "Some description",
        skipped_fields: ["due_on", "responsible_email"]
      }

      result = Draft.to_transcript(draft)

      assert result =~ "skipped_fields: due_on, responsible_email"
    end

    test "omits skipped_fields section when list is empty" do
      draft = %Draft{
        name: "Complete task",
        description: "Full description",
        skipped_fields: []
      }

      result = Draft.to_transcript(draft)

      refute result =~ "skipped_fields"
    end

    test "returns nil when all fields are nil or empty" do
      draft = %Draft{
        name: nil,
        description: nil,
        responsible_email: nil,
        due_on: nil,
        skipped_fields: []
      }

      assert Draft.to_transcript(draft) == nil
    end

    test "returns transcript with only skipped_fields when other fields are nil" do
      draft = %Draft{
        name: nil,
        description: nil,
        responsible_email: nil,
        due_on: nil,
        skipped_fields: ["name", "description"]
      }

      result = Draft.to_transcript(draft)

      assert result == "Draft — skipped_fields: name, description"
    end

    test "joins fields with pipe separator" do
      draft = %Draft{
        name: "Campaign",
        description: "Brief description",
        responsible_email: nil,
        due_on: nil
      }

      result = Draft.to_transcript(draft)

      assert result =~ " | "
      assert result == "Draft — name: Campaign | description: Brief description"
    end
  end

  describe "type_label/0" do
    test "returns draft" do
      assert Draft.type_label() == "draft"
    end
  end
end
