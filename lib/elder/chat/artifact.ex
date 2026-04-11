defmodule Elder.Chat.Artifact do
  @moduledoc """
  Behaviour for typed message attachments in a conversation.

  Feature modules implement `to_transcript/1` and `type_label/0` to
  participate in LLM transcript formatting.
  """

  @type t :: struct()

  @callback to_transcript(t()) :: String.t() | nil
  @callback type_label() :: String.t()
end
