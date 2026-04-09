defmodule Elder.LLM.Client do
  @moduledoc """
  Streams LLM responses asynchronously, broadcasting tokens via PubSub.

  Implements `Elder.LLM.ClientBehaviour` using ReqLLM.
  """

  @behaviour Elder.LLM.ClientBehaviour

  alias Phoenix.PubSub

  require Logger

  @doc "Starts an async LLM stream, broadcasting `:llm_token`, `:llm_done`, or `:llm_error` to the topic."
  @spec stream(term(), String.t(), String.t()) :: :ok
  def stream(context, model, pubsub_topic) do
    Logger.info("Skills Platform | llm_stream_start | topic:#{pubsub_topic} | ok",
      feature: "Skills Platform",
      step: "llm_stream_start",
      cid: pubsub_topic
    )

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      run_stream(context, model, pubsub_topic)
    end)

    :ok
  end

  @doc "Runs a non-streaming LLM request asynchronously, broadcasting `{:interview_done, result}` to the topic."
  @spec call(term(), String.t(), String.t()) :: :ok
  def call(context, model, pubsub_topic) do
    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      result =
        case ReqLLM.generate_text(model, context) do
          {:ok, response} -> {:ok, ReqLLM.Response.text(response)}
          {:error, reason} -> {:error, reason}
        end

      PubSub.broadcast(Elder.PubSub, pubsub_topic, {:interview_done, result})
    end)

    :ok
  end

  defp run_stream(context, model, pubsub_topic) do
    case ReqLLM.stream_text(model, context) do
      {:ok, stream_response} ->
        handle_stream(stream_response, model, pubsub_topic)

      {:error, reason} ->
        Logger.error("Skills Platform | llm_stream | topic:#{pubsub_topic} | error:stream",
          feature: "Skills Platform",
          step: "llm_stream",
          cid: pubsub_topic,
          reason: :stream_error
        )

        PubSub.broadcast(Elder.PubSub, pubsub_topic, {:llm_error, reason})
    end
  end

  defp handle_stream(stream_response, model, pubsub_topic) do
    result =
      ReqLLM.StreamResponse.process_stream(stream_response,
        on_result: fn chunk ->
          PubSub.broadcast(Elder.PubSub, pubsub_topic, {:llm_token, chunk})
        end
      )

    case result do
      {:ok, response} ->
        usage = ReqLLM.Response.usage(response) || %{}
        cost = Map.get(usage, :total_cost, 0.0)

        Logger.info(
          "Skills Platform | llm_stream_done | topic:#{pubsub_topic} | ok",
          feature: "Skills Platform",
          step: "llm_stream_done",
          cid: pubsub_topic,
          ms: cost
        )

        PubSub.broadcast(Elder.PubSub, pubsub_topic, {
          :llm_done,
          %{
            output: ReqLLM.Response.text(response),
            cost_usd: cost,
            model: model
          }
        })

      {:error, reason} ->
        Logger.error(
          "Skills Platform | llm_stream_process | topic:#{pubsub_topic} | error:process",
          feature: "Skills Platform",
          step: "llm_stream_process",
          cid: pubsub_topic,
          reason: :process_error
        )

        PubSub.broadcast(Elder.PubSub, pubsub_topic, {:llm_error, reason})
    end
  end
end
