defmodule Elder.LLM.ClientBehaviour do
  @moduledoc """
  Behaviour defining the LLM client contract for streaming and text generation.
  """

  @callback stream(context :: term(), model :: String.t(), opts :: keyword()) :: :ok

  @callback call(context :: term(), model :: String.t(), opts :: keyword()) :: :ok

  @callback generate_object(
              context :: term(),
              schema :: map(),
              model :: String.t(),
              opts :: keyword()
            ) :: :ok
end
