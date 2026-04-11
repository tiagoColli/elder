defmodule Elder.Asana.ResponseHandlerTest do
  use ExUnit.Case, async: true

  alias Elder.Asana.Artifacts.Draft
  alias Elder.Asana.ResponseHandler

  describe "handle/1 [READY] sentinel" do
    test "returns ready with empty artifacts for exact sentinel" do
      assert {:ready, %{artifacts: []}} = ResponseHandler.handle("[READY]")
    end

    test "returns ready with empty artifacts when sentinel has surrounding whitespace" do
      assert {:ready, %{artifacts: []}} = ResponseHandler.handle("  [READY]  \n")
    end
  end

  describe "handle/1 continue status" do
    test "returns continue with text, question, suggestions and draft artifact" do
      json = ~S"""
      {"status":"continue","draft":{"name":"Q4 Campaign","responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Got the title.","question":"Who should own it?","suggestions":[]}
      """

      assert {:continue, data} = ResponseHandler.handle(json)
      assert data.text == "Got the title."
      assert data.question == "Who should own it?"
      assert data.suggestions == []
      assert [%Draft{name: "Q4 Campaign"}] = data.artifacts
    end

    test "includes suggestions in continue response" do
      json = ~S"""
      {"status":"continue","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Who owns this?","suggestions":[{"label":"I will own it","value":"I'll take ownership."},{"label":"Skip for now","value":"skip"}]}
      """

      assert {:continue, data} = ResponseHandler.handle(json)
      assert length(data.suggestions) == 2
      assert Enum.map(data.suggestions, & &1.label) == ["I will own it", "Skip for now"]
    end
  end

  describe "handle/1 ready status" do
    test "returns ready with text and draft artifact" do
      json = ~S"""
      {"status":"ready","draft":{"name":"Annual Report Task","responsible_email":"owner@company.com","description":"Full annual report","due_on":"2026-06-01"},"skipped_fields":[],"assistant_message":"All set, ready to create."}
      """

      assert {:ready, data} = ResponseHandler.handle(json)
      assert data.text == "All set, ready to create."

      assert [%Draft{name: "Annual Report Task", responsible_email: "owner@company.com"}] =
               data.artifacts
    end

    test "maps all draft fields from response onto the Draft struct" do
      json = ~S"""
      {"status":"ready","draft":{"name":"Launch Campaign","responsible_email":"maria@company.com","description":"Full campaign details","due_on":"2026-12-31"},"skipped_fields":["due_on"],"assistant_message":"Done."}
      """

      assert {:ready, data} = ResponseHandler.handle(json)
      [draft] = data.artifacts
      assert draft.name == "Launch Campaign"
      assert draft.responsible_email == "maria@company.com"
      assert draft.description == "Full campaign details"
      assert draft.due_on == "2026-12-31"
      assert draft.skipped_fields == ["due_on"]
    end

    test "includes draft in ready artifacts even when optional draft fields are nil" do
      json = ~S"""
      {"status":"ready","draft":{"name":"Minimal Task","responsible_email":null,"description":null,"due_on":null},"skipped_fields":[],"assistant_message":"Ready."}
      """

      assert {:ready, data} = ResponseHandler.handle(json)
      assert [%Draft{name: "Minimal Task", description: nil}] = data.artifacts
    end
  end

  describe "handle/1 error paths" do
    test "returns error when raw text is not valid JSON" do
      assert {:error, :invalid_interview_json} = ResponseHandler.handle("not json")
    end

    test "returns error for unknown status in otherwise valid JSON" do
      json = ~S"""
      {"status":"pending","draft":{"name":null,"responsible_email":null,"description":null,"due_on":null},"assistant_message":"Hi"}
      """

      assert {:error, :invalid_interview_status} = ResponseHandler.handle(json)
    end

    test "returns error when required draft keys are absent" do
      json = ~S({"status":"continue","draft":{"name":null},"assistant_message":"Hi"})

      assert {:error, :invalid_interview_json} = ResponseHandler.handle(json)
    end
  end
end
