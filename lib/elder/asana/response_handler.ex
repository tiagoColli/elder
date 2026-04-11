defmodule Elder.Asana.ResponseHandler do
  @moduledoc """
  Parses raw LLM text into structured response data for Asana task creation.
  """

  alias Elder.Asana.Artifacts.Draft
  alias Elder.LLM.InterviewResponse
  alias Elder.LLM.InterviewResponseDraft

  @doc """
  Handles a raw LLM response string, returning a typed result tuple.

  ## Returns
    - `{:ready, %{artifacts: []}}` when the response is the literal `[READY]` token
    - `{:continue, %{text, question, suggestions, artifacts}}` when the interview continues
    - `{:ready, %{text, artifacts}}` when the interview is complete with a draft
    - `{:error, reason}` on parse failure
  """
  @spec handle(String.t()) :: {:continue, map()} | {:ready, map()} | {:error, term()}
  def handle(raw_text) do
    if String.trim(raw_text) == "[READY]" do
      {:ready, %{artifacts: []}}
    else
      case InterviewResponse.parse(raw_text) do
        {:ok, %{status: :continue} = parsed} ->
          {:continue,
           %{
             text: parsed.assistant_message,
             question: parsed.question,
             suggestions: parsed.suggestions,
             artifacts: [build_draft(parsed.draft)]
           }}

        {:ok, %{status: :ready} = parsed} ->
          {:ready, %{text: parsed.assistant_message, artifacts: [build_draft(parsed.draft)]}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_draft(%InterviewResponseDraft{} = d) do
    %Draft{
      name: d.name,
      description: d.description,
      responsible_email: d.responsible_email,
      due_on: d.due_on,
      skipped_fields: d.skipped_fields
    }
  end
end
