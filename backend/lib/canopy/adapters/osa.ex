defmodule Canopy.Adapters.OSA do
  @moduledoc """
  OSA adapter — direct Elixir function calls to the OptimalSystemAgent.

  Connects to a running OSA instance via its HTTP API (localhost:9090 by default).
  Streams SSE events back as adapter events.
  """
  @behaviour Canopy.Adapter

  require Logger

  @default_url "http://127.0.0.1:9090"

  @impl true
  def type, do: "osa"

  @impl true
  def name, do: "OSA Agent"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :web_search, :memory, :delegation]

  @impl true
  def health do
    case Req.get("#{@default_url}/health", receive_timeout: 2_000) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{status: status}} -> {:error, "OSA returned HTTP #{status}"}
      {:error, reason} -> {:error, "OSA not reachable at #{@default_url}: #{inspect(reason)}"}
    end
  end

  @impl true
  def start(config) do
    base_url = config["url"] || @default_url

    case Req.post("#{base_url}/api/v1/sessions",
           json: %{model: config["model"] || "claude-sonnet-4-6"}
         ) do
      {:ok, %{status: status, body: body}} when status in 200..201 ->
        {:ok,
         %{
           session_id: body["session"]["id"],
           base_url: base_url,
           model: config["model"] || "claude-sonnet-4-6"
         }}

      {:ok, %{status: status, body: body}} ->
        {:error, {:osa_error, status, body}}

      {:error, reason} ->
        {:error, {:connection_failed, reason}}
    end
  end

  @impl true
  def stop(%{base_url: base_url, session_id: session_id}) do
    case Req.delete("#{base_url}/api/v1/sessions/#{session_id}") do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def execute_heartbeat(params) do
    base_url = params["url"] || @default_url
    agent_context = params["context"] || "Perform your scheduled heartbeat check."
    model = params["model"] || "claude-sonnet-4-6"

    Stream.resource(
      fn ->
        case Req.post("#{base_url}/api/v1/sessions", json: %{model: model}) do
          {:ok, %{status: s, body: body}} when s in 200..201 ->
            session_id = body["session"]["id"]

            Req.post("#{base_url}/api/v1/sessions/#{session_id}/message",
              json: %{message: agent_context}
            )

            {:ok, task} = start_sse("#{base_url}/api/v1/sessions/#{session_id}/stream")
            {task, session_id, base_url}

          _ ->
            {:error, nil, nil}
        end
      end,
      fn
        {:error, _, _} = state ->
          {:halt, state}

        {task, session_id, base_url} ->
          case receive_sse_event(task, 30_000) do
            {:ok, event} ->
              {[event], {task, session_id, base_url}}

            :done ->
              {:halt, {task, session_id, base_url}}

            {:error, _reason} ->
              {:halt, {task, session_id, base_url}}
          end
      end,
      fn
        {:error, _, _} ->
          :ok

        {_task, session_id, base_url} ->
          Req.delete("#{base_url}/api/v1/sessions/#{session_id}")
          :ok
      end
    )
  end

  @impl true
  def send_message(%{base_url: base_url, session_id: session_id}, message) do
    Req.post("#{base_url}/api/v1/sessions/#{session_id}/message",
      json: %{message: message}
    )

    Stream.resource(
      fn ->
        {:ok, task} = start_sse("#{base_url}/api/v1/sessions/#{session_id}/stream")
        task
      end,
      fn task ->
        case receive_sse_event(task, 30_000) do
          {:ok, event} -> {[event], task}
          :done -> {:halt, task}
          {:error, _} -> {:halt, task}
        end
      end,
      fn _task -> :ok end
    )
  end

  # SSE helpers

  defp start_sse(url) do
    task =
      Task.async(fn ->
        Req.get(url, into: :self, receive_timeout: 120_000)
      end)

    {:ok, task}
  end

  defp receive_sse_event(task, timeout) do
    receive do
      {ref, {:data, data}} when ref == task.ref ->
        case parse_sse(data) do
          %{"event_type" => "done"} -> :done
          event -> {:ok, event}
        end

      {ref, :done} when ref == task.ref ->
        :done
    after
      timeout -> {:error, :timeout}
    end
  end

  defp parse_sse(raw) do
    raw
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ": ", parts: 2) do
        ["event", value] ->
          Map.put(acc, "event_type", String.trim(value))

        ["data", value] ->
          case Jason.decode(String.trim(value)) do
            {:ok, data} -> Map.merge(acc, %{"data" => data})
            _ -> Map.put(acc, "data", %{"raw" => String.trim(value)})
          end

        _ ->
          acc
      end
    end)
  end
end
