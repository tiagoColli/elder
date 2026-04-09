defmodule Elder.LLM.InterviewResponse do
  @moduledoc """
  Domain value and parser for structured interview replies from the LLM.

  Decodes JSON (optionally inside a markdown `json` fence) into an
  `Elder.LLM.InterviewResponse` struct; nested task fields use
  `Elder.LLM.InterviewResponseDraft`. The public API is `parse/1`.
  """

  alias Elder.LLM.InterviewResponseDraft

  defstruct [:status, :draft, :assistant_message, :question, :suggestions]

  @type suggestion :: %{label: String.t(), value: String.t()}

  @type t :: %__MODULE__{
          status: :continue | :ready,
          draft: InterviewResponseDraft.t(),
          assistant_message: String.t(),
          question: String.t() | nil,
          suggestions: [suggestion()]
        }

  @max_suggestions 3

  @doc """
  Parses a structured JSON interview reply from raw LLM text.

  Expects a single JSON object. If the text is wrapped in a markdown `json` code
  fence, the inner body is used. Otherwise, the substring from the first `{` to
  the last `}` is decoded. That heuristic assumes one top-level object; nested
  braces inside JSON strings can break extraction, so prompts should keep output simple.

  The `suggestions` list is capped at three items; additional entries are dropped.

  ## Returns

    * `{:ok, %#{inspect(__MODULE__)}{}}` on success
    * `{:error, :invalid_interview_json}` when the payload cannot be extracted or decoded,
      required keys are missing, or field types are wrong
    * `{:error, :invalid_interview_status}` when `status` is not `"continue"` or `"ready"`
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, atom()}
  def parse(text) when is_binary(text) do
    with {:ok, json_str} <- extract_json(text),
         {:ok, map} <- decode_json(json_str) do
      build_struct(map)
    end
  end

  defp extract_json(text) do
    trimmed = String.trim(text)

    case Regex.run(~r/```json\s*([\s\S]*?)```/i, trimmed) do
      [_fence, inner] -> {:ok, String.trim(inner)}
      nil -> brace_delimited_json(trimmed)
    end
  end

  defp brace_delimited_json(s) do
    with {start, _open_len} <- :binary.match(s, "{"),
         chunk <- binary_part(s, start, byte_size(s) - start),
         {from_end, _close_len} <- :binary.match(String.reverse(chunk), "}"),
         len <- byte_size(chunk) - from_end do
      {:ok, binary_part(chunk, 0, len)}
    else
      _no_braces -> {:error, :invalid_interview_json}
    end
  end

  defp decode_json(json_str) do
    case Jason.decode(json_str) do
      {:ok, map} when is_map(map) -> {:ok, map}
      _invalid_json -> {:error, :invalid_interview_json}
    end
  end

  defp build_struct(map) when is_map(map) do
    required = ["status", "draft", "assistant_message"]

    with true <- Enum.all?(required, &Map.has_key?(map, &1)),
         {:ok, status} <- parse_status(map["status"]),
         {:ok, draft} <- parse_draft(map["draft"]),
         {:ok, assistant_message} <- require_string(map["assistant_message"]) do
      {:ok,
       %__MODULE__{
         status: status,
         draft: draft,
         assistant_message: assistant_message,
         question: optional_string(map["question"]),
         suggestions: parse_suggestions(Map.get(map, "suggestions", []))
       }}
    else
      false -> {:error, :invalid_interview_json}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_status("continue"), do: {:ok, :continue}
  defp parse_status("ready"), do: {:ok, :ready}
  defp parse_status(_invalid_status), do: {:error, :invalid_interview_status}

  defp parse_draft(draft) when is_map(draft) do
    keys = ["title", "responsible", "description", "due_date"]

    if Enum.all?(keys, &Map.has_key?(draft, &1)) do
      {:ok,
       %InterviewResponseDraft{
         title: optional_string(draft["title"]),
         responsible: optional_string(draft["responsible"]),
         description: optional_string(draft["description"]),
         due_date: optional_string(draft["due_date"])
       }}
    else
      {:error, :invalid_interview_json}
    end
  end

  defp parse_draft(_invalid), do: {:error, :invalid_interview_json}

  defp require_string(s) when is_binary(s), do: {:ok, s}
  defp require_string(_not_binary), do: {:error, :invalid_interview_json}

  defp optional_string(nil), do: nil
  defp optional_string(s) when is_binary(s), do: s
  defp optional_string(_not_string), do: nil

  defp parse_suggestions(list) when is_list(list) do
    list
    |> Enum.flat_map(fn
      %{"label" => l, "value" => v} when is_binary(l) and is_binary(v) -> [%{label: l, value: v}]
      _not_suggestion -> []
    end)
    |> Enum.take(@max_suggestions)
  end

  defp parse_suggestions(_not_list), do: []
end
