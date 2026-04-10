defmodule Elder.LLM.ClientBehaviour do
  @moduledoc """
  Behaviour contract for the LLM client (streaming and interview calls).
  """

  @callback stream(context :: term(), model :: String.t(), pubsub_topic :: String.t()) :: :ok

  @callback call(context :: term(), model :: String.t(), pubsub_topic :: String.t()) :: :ok

  @callback generate_object(
              context :: term(),
              schema :: map(),
              model :: String.t(),
              pubsub_topic :: String.t()
            ) :: :ok
end
