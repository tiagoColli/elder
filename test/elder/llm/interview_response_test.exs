defmodule Elder.LLM.InterviewResponseTest do
  use ExUnit.Case, async: true

  alias Elder.LLM.InterviewResponse

  test "parse/1 decodes minimal continue payload" do
    json = ~S"""
    {"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Olá","question":"Qual o título?"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.status == :continue
    assert parsed.draft.name == nil
    assert parsed.assistant_message == "Olá"
    assert parsed.question == "Qual o título?"
    assert parsed.suggestions == []
  end

  test "parse/1 extracts JSON from markdown fence" do
    raw = """
    Here is the JSON:

    ```json
    {"status":"ready","draft":{"name":"X","responsible_email":"Y","description":"Z","due_on":"2026-05-01"},"assistant_message":"Pronto."}
    ```
    """

    assert {:ok, parsed} = InterviewResponse.parse(raw)
    assert parsed.status == :ready
    assert parsed.draft.name == "X"
  end

  test "parse/1 returns error for non-JSON string" do
    assert {:error, :invalid_interview_json} = InterviewResponse.parse("not json at all")
  end

  test "parse/1 returns error for unknown status" do
    json = ~S"""
    {"status":"maybe","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"}
    """

    assert {:error, :invalid_interview_status} = InterviewResponse.parse(json)
  end

  test "parse/1 accepts ready with nil question and empty suggestions" do
    json = ~S"""
    {"status":"ready","draft":{"name":"T","responsible_email":"R","description":"D","due_on":"2026-01-01"},"assistant_message":"Done"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.status == :ready
    assert parsed.question == nil
    assert parsed.suggestions == []
  end

  test "parse/1 maps root skipped_fields onto draft" do
    json = ~S"""
    {"status":"ready","draft":{"name":"T","responsible_email":null,"description":"D","due_on":null},"skipped_fields":["due_on","responsible_email"],"assistant_message":"Done"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.draft.skipped_fields == ["due_on", "responsible_email"]
  end

  test "parse/1 truncates suggestions to at most 3" do
    json = ~S"""
    {"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi","suggestions":[{"label":"A","value":"a"},{"label":"B","value":"b"},{"label":"C","value":"c"},{"label":"D","value":"d"}]}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert length(parsed.suggestions) == 3
    assert Enum.map(parsed.suggestions, & &1.label) == ["A", "B", "C"]
  end

  describe "parse/1 first-{ to last-} heuristic" do
    test "still succeeds when `{` appears only inside quoted JSON values" do
      json =
        ~S({"status":"continue","draft":{"name":"prefix { suffix","responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.draft.name == "prefix { suffix"
    end

    test "fails when non-JSON prose contains `{` before the real object" do
      json =
        ~S({"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"})

      raw = "Note: use { curly } wisely " <> json

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(raw)
    end
  end

  describe "parse/1 missing required keys" do
    test "returns error when status key is absent" do
      json =
        ~S({"draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end

    test "returns error when draft key is absent" do
      json = ~S({"status":"continue","assistant_message":"Hi"})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end

    test "returns error when assistant_message key is absent" do
      json =
        ~S({"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null}})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end

    test "returns error when draft is missing a required inner key" do
      json =
        ~S({"status":"continue","draft":{"name":null,"description":null,"due_on":null},"assistant_message":"Hi"})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end
  end

  describe "parse/1 invalid field types" do
    test "returns error when draft is a string instead of object" do
      json = ~S({"status":"continue","draft":"not an object","assistant_message":"Hi"})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end

    test "returns error when assistant_message is not a string" do
      json =
        ~S({"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":42})

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(json)
    end
  end

  describe "parse/1 suggestions edge cases" do
    test "returns empty list when suggestions is not a list" do
      json =
        ~S({"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi","suggestions":"bad"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.suggestions == []
    end

    test "keeps only valid suggestion items when list has mixed valid and invalid entries" do
      json =
        ~S({"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi","suggestions":[{"label":"Skip","value":"skip"},{"invalid":true},{"label":"Other","value":"other"}]})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert length(parsed.suggestions) == 2
      assert Enum.map(parsed.suggestions, & &1.label) == ["Skip", "Other"]
    end
  end

  describe "parse/1 skipped_fields edge cases" do
    test "returns empty list when skipped_fields is not a list" do
      json =
        ~S({"status":"ready","draft":{"name":"T","responsible_email":null,"description":"D","due_on":null},"skipped_fields":"bad","assistant_message":"Done"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.draft.skipped_fields == []
    end

    test "filters out non-string entries in skipped_fields" do
      json =
        ~S({"status":"ready","draft":{"name":"T","responsible_email":null,"description":"D","due_on":null},"skipped_fields":["due_on",42,null,"responsible_email"],"assistant_message":"Done"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.draft.skipped_fields == ["due_on", "responsible_email"]
    end
  end

  describe "parse/1 optional fields" do
    test "optional_string returns nil for non-string values in draft" do
      json =
        ~S({"status":"continue","draft":{"name":123,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.draft.name == nil
    end
  end
end
