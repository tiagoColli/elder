defmodule Elder.LLM.Client do
  @moduledoc """
  Sends LLM requests via `ReqLLM` and dispatches results as messages to the caller process.

  All public functions enqueue a supervised async task and return `:ok` immediately.
  """

  @behaviour Elder.LLM.ClientBehaviour

  require Logger

  @doc """
  Starts an async streaming text generation task.

  Dispatches `{:llm_token, chunk}` messages during generation, followed by
  `{:llm_done, %{output, cost_usd, model}}` on success or `{:llm_error, reason}` on failure.

  ## Params
    - `context` - `ReqLLM.Context` struct
    - `model` - model identifier string
    - `opts` - keyword options; `:caller` (pid) required
  """
  @spec stream(term(), String.t(), keyword()) :: :ok
  def stream(context, model, opts) do
    caller = Keyword.fetch!(opts, :caller)

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      run_stream(context, model, caller)
    end)

    :ok
  end

  @doc """
  Starts an async non-streaming text generation task.

  Dispatches `{:interview_done, {:ok, text}}` or `{:interview_done, {:error, reason}}`
  to `caller` on completion.

  ## Params
    - `context` - `ReqLLM.Context` struct
    - `model` - model identifier string
    - `opts` - keyword options; `:caller` (pid) required
  """
  @spec call(term(), String.t(), keyword()) :: :ok
  def call(context, model, opts) do
    caller = Keyword.fetch!(opts, :caller)

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      result =
        case ReqLLM.generate_text(model, context) do
          {:ok, response} ->
            {:ok, ReqLLM.Response.text(response)}

          {:error, reason} ->
            {:error, reason}
        end

      case result do
        {:ok, _} ->
          Logger.info("LLM Client | call_complete | model:#{model} | ok",
            feature: "LLM Client",
            step: "call_complete",
            cid: model
          )

        {:error, _reason} ->
          Logger.error("LLM Client | call_error | model:#{model} | error:call",
            feature: "LLM Client",
            step: "call_error",
            cid: model
          )
      end

      send(caller, {:interview_done, result})
    end)

    :ok
  end

  @doc """
  Starts an async structured object generation task.

  Dispatches `{:llm_object_done, {:ok, %{object: map(), cost_usd: float(), model: String.t()}}}`
  or `{:llm_object_done, {:error, reason}}` to `caller` on completion.

  ## Params
    - `context` - `ReqLLM.Context` struct
    - `schema` - JSON Schema map defining the expected response shape
    - `model` - model identifier string
    - `opts` - keyword options; `:caller` (pid) required
  """
  @spec generate_object(term(), map(), String.t(), keyword()) :: :ok
  def generate_object(context, schema, model, opts) do
    caller = Keyword.fetch!(opts, :caller)

    Task.Supervisor.start_child(Elder.LLM.TaskSupervisor, fn ->
      result =
        case ReqLLM.generate_object(model, context, schema) do
          {:ok, response} ->
            usage = ReqLLM.Response.usage(response) || %{}
            cost = Map.get(usage, :total_cost, 0.0)

            {:ok,
             %{
               object: ReqLLM.Response.object(response),
               cost_usd: cost,
               model: model
             }}

          {:error, reason} ->
            {:error, reason}
        end

      case result do
        {:ok, %{cost_usd: cost}} ->
          Logger.info(
            "LLM Client | generate_object_complete | model:#{model} | ok cost_usd:#{cost}",
            feature: "LLM Client",
            step: "generate_object_complete",
            cid: model
          )

        {:error, _reason} ->
          Logger.error(
            "LLM Client | generate_object_error | model:#{model} | error:generate",
            feature: "LLM Client",
            step: "generate_object_error",
            cid: model
          )
      end

      send(caller, {:llm_object_done, result})
    end)

    :ok
  end

  defp run_stream(context, model, caller) do
    case ReqLLM.stream_text(model, context) do
      {:ok, stream_response} ->
        handle_stream(stream_response, model, caller)

      {:error, reason} ->
        Logger.error("LLM Client | stream_error | model:#{model} | error:stream",
          feature: "LLM Client",
          step: "stream_error",
          cid: model
        )

        send(caller, {:llm_error, reason})
    end
  end

  defp handle_stream(stream_response, model, caller) do
    result =
      ReqLLM.StreamResponse.process_stream(stream_response,
        on_result: fn chunk ->
          send(caller, {:llm_token, chunk})
        end
      )

    case result do
      {:ok, response} ->
        usage = ReqLLM.Response.usage(response) || %{}
        cost = Map.get(usage, :total_cost, 0.0)

        Logger.info(
          "LLM Client | stream_complete | model:#{model} | ok cost_usd:#{cost}",
          feature: "LLM Client",
          step: "stream_complete",
          cid: model
        )

        send(caller, {
          :llm_done,
          %{
            output: ReqLLM.Response.text(response),
            cost_usd: cost,
            model: model
          }
        })

      {:error, reason} ->
        Logger.error("LLM Client | stream_error | model:#{model} | error:process",
          feature: "LLM Client",
          step: "stream_error",
          cid: model
        )

        send(caller, {:llm_error, reason})
    end
  end
end
