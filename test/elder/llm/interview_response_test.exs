defmodule Elder.LLM.InterviewResponseTest do
  use ExUnit.Case, async: true

  alias Elder.LLM.InterviewResponse

  test "parse/1 decodes minimal continue payload" do
    json = ~S"""
    {"status":"continue","draft":{"title":null,"responsible":null,"description":null,"due_date":null},"assistant_message":"Olá","question":"Qual o título?"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.status == :continue
    assert parsed.draft.title == nil
    assert parsed.assistant_message == "Olá"
    assert parsed.question == "Qual o título?"
    assert parsed.suggestions == []
  end

  test "parse/1 extracts JSON from markdown fence" do
    raw = """
    Here is the JSON:

    ```json
    {"status":"ready","draft":{"title":"X","responsible":"Y","description":"Z","due_date":"2026-05-01"},"assistant_message":"Pronto."}
    ```
    """

    assert {:ok, parsed} = InterviewResponse.parse(raw)
    assert parsed.status == :ready
    assert parsed.draft.title == "X"
  end

  test "parse/1 returns error for non-JSON string" do
    assert {:error, :invalid_interview_json} = InterviewResponse.parse("not json at all")
  end

  test "parse/1 returns error for unknown status" do
    json = ~S"""
    {"status":"maybe","draft":{"title":null,"responsible":null,"description":null,"due_date":null},"assistant_message":"Hi"}
    """

    assert {:error, :invalid_interview_status} = InterviewResponse.parse(json)
  end

  test "parse/1 accepts ready with nil question and empty suggestions" do
    json = ~S"""
    {"status":"ready","draft":{"title":"T","responsible":"R","description":"D","due_date":"2026-01-01"},"assistant_message":"Done"}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert parsed.status == :ready
    assert parsed.question == nil
    assert parsed.suggestions == []
  end

  test "parse/1 truncates suggestions to at most 3" do
    json = ~S"""
    {"status":"continue","draft":{"title":null,"responsible":null,"description":null,"due_date":null},"assistant_message":"Hi","suggestions":[{"label":"A","value":"a"},{"label":"B","value":"b"},{"label":"C","value":"c"},{"label":"D","value":"d"}]}
    """

    assert {:ok, parsed} = InterviewResponse.parse(json)
    assert length(parsed.suggestions) == 3
    assert Enum.map(parsed.suggestions, & &1.label) == ["A", "B", "C"]
  end

  describe "parse/1 first-{ to last-} heuristic" do
    test "still succeeds when `{` appears only inside quoted JSON values" do
      json =
        ~S({"status":"continue","draft":{"title":"prefix { suffix","responsible":null,"description":null,"due_date":null},"assistant_message":"Hi"})

      assert {:ok, parsed} = InterviewResponse.parse(json)
      assert parsed.draft.title == "prefix { suffix"
    end

    test "fails when non-JSON prose contains `{` before the real object" do
      json =
        ~S({"status":"continue","draft":{"title":null,"responsible":null,"description":null,"due_date":null},"assistant_message":"Hi"})

      raw = "Note: use { curly } wisely " <> json

      assert {:error, :invalid_interview_json} = InterviewResponse.parse(raw)
    end
  end
end
