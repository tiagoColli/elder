defmodule Elder.Schemas.InterviewResponseTest do
  use ExUnit.Case, async: true

  alias Elder.Schemas.InterviewResponse

  defp cast_and_validate(params) do
    %InterviewResponse{}
    |> Instructor.cast_all(params)
    |> InterviewResponse.validate_changeset()
    |> Ecto.Changeset.apply_action(:validate)
  end

  describe "valid responses" do
    test "continue with all fields" do
      params = %{
        "status" => "continue",
        "assistant_message" => "What is the task name?",
        "question" => "Could you provide the task name?",
        "suggestions" => [
          %{"label" => "Bug fix", "value" => "bug fix"},
          %{"label" => "Feature", "value" => "feature"}
        ],
        "draft" => %{
          "name" => "Fix login",
          "description" => "Fix the login page",
          "due_on" => "2026-05-01",
          "responsible_email" => "dev@example.com",
          "skipped_fields" => []
        }
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.status == :continue
      assert response.assistant_message == "What is the task name?"
      assert response.question == "Could you provide the task name?"
      assert length(response.suggestions) == 2
      assert response.draft.name == "Fix login"
    end

    test "ready with complete draft" do
      params = %{
        "status" => "ready",
        "assistant_message" => "Your task is ready.",
        "suggestions" => [],
        "draft" => %{
          "name" => "Deploy v2",
          "description" => "Deploy version 2 to production",
          "due_on" => "2026-06-01",
          "responsible_email" => "ops@example.com",
          "skipped_fields" => []
        }
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.status == :ready
      assert response.question == nil
    end

    test "empty suggestions" do
      params = %{
        "status" => "continue",
        "assistant_message" => "Tell me more.",
        "question" => "What's the priority?",
        "suggestions" => [],
        "draft" => %{
          "name" => nil,
          "description" => nil,
          "due_on" => nil,
          "responsible_email" => nil
        }
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.suggestions == []
    end

    test "draft with skipped_fields" do
      params = %{
        "status" => "ready",
        "assistant_message" => "Done.",
        "suggestions" => [],
        "draft" => %{
          "name" => "Task A",
          "description" => nil,
          "due_on" => nil,
          "responsible_email" => nil,
          "skipped_fields" => ["due_on", "description"]
        }
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.draft.skipped_fields == ["due_on", "description"]
    end

    test "draft with nil optional fields" do
      params = %{
        "status" => "continue",
        "assistant_message" => "Let's start.",
        "question" => "What should we name the task?",
        "suggestions" => [],
        "draft" => %{
          "name" => nil,
          "description" => nil,
          "due_on" => nil,
          "responsible_email" => nil
        }
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.draft.name == nil
      assert response.draft.description == nil
    end

    test "partial draft with only name" do
      params = %{
        "status" => "continue",
        "assistant_message" => "Got it, what else?",
        "question" => "What's the description?",
        "suggestions" => [],
        "draft" => %{"name" => "My task"}
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert response.draft.name == "My task"
      assert response.draft.description == nil
      assert response.draft.skipped_fields == []
    end
  end

  describe "validation errors" do
    test "missing assistant_message" do
      params = %{
        "status" => "continue",
        "question" => "What?",
        "suggestions" => [],
        "draft" => %{"name" => "Task"}
      }

      assert {:error, changeset} = cast_and_validate(params)
      assert %{assistant_message: ["can't be blank"]} = errors_on(changeset)
    end

    test "missing draft" do
      params = %{
        "status" => "continue",
        "assistant_message" => "Hello",
        "question" => "What?",
        "suggestions" => []
      }

      assert {:error, changeset} = cast_and_validate(params)
      assert %{draft: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid status" do
      params = %{
        "status" => "maybe",
        "assistant_message" => "Hmm.",
        "suggestions" => [],
        "draft" => %{"name" => "Task"}
      }

      assert {:error, changeset} = cast_and_validate(params)
      assert %{status: [_msg]} = errors_on(changeset)
    end
  end

  describe "edge-case validation" do
    test "missing status field" do
      params = %{
        "assistant_message" => "Hi",
        "suggestions" => [],
        "draft" => %{"name" => "Task"}
      }

      assert {:error, changeset} = cast_and_validate(params)
      assert %{status: [_msg]} = errors_on(changeset)
    end

    test "empty params" do
      assert {:error, changeset} = cast_and_validate(%{})
      assert errors_on(changeset) != %{}
    end
  end

  describe "suggestions cap" do
    test "caps at 3 when more are provided" do
      suggestions =
        for i <- 1..5, do: %{"label" => "Option #{i}", "value" => "opt_#{i}"}

      params = %{
        "status" => "continue",
        "assistant_message" => "Pick one.",
        "question" => "Which option?",
        "suggestions" => suggestions,
        "draft" => %{"name" => "Task"}
      }

      assert {:ok, %InterviewResponse{} = response} = cast_and_validate(params)
      assert length(response.suggestions) == 3
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _match, key ->
        atom_key = String.to_existing_atom(key)
        to_string(Keyword.get(opts, atom_key, key))
      end)
    end)
  end
end
