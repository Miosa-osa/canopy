defmodule Canopy.Adapters.HTTP do
  @moduledoc "HTTP adapter — POST task to external API, poll for result."
  @behaviour Canopy.Adapter

  @impl true
  def type, do: "http"

  @impl true
  def name, do: "HTTP API"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat]

  @impl true
  def health, do: :ok

  @impl true
  def start(config) do
    url = config["url"] || raise "HTTP adapter requires 'url' in config"
    {:ok, %{url: url, headers: config["headers"] || %{}, method: config["method"] || "POST"}}
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    url = params["url"] || raise "HTTP adapter requires url"
    headers = params["headers"] || %{}
    body = %{message: params["context"] || "", model: params["model"]}

    Stream.resource(
      fn -> :pending end,
      fn
        :pending ->
          case Req.post(url,
                 json: body,
                 headers: Map.to_list(headers),
                 receive_timeout: 120_000
               ) do
            {:ok, %{status: s, body: resp}} when s in 200..299 ->
              events = [
                %{event_type: "run.output", data: %{"response" => resp}, tokens: 0},
                %{event_type: "run.completed", data: %{"status" => s}, tokens: 0}
              ]

              {events, :done}

            {:ok, %{status: s, body: resp}} ->
              {[%{event_type: "run.failed", data: %{"status" => s, "body" => resp}, tokens: 0}],
               :done}

            {:error, reason} ->
              {[%{event_type: "run.failed", data: %{"error" => inspect(reason)}, tokens: 0}],
               :done}
          end

        :done ->
          {:halt, :done}
      end,
      fn _ -> :ok end
    )
  end

  @impl true
  def send_message(session, message) do
    execute_heartbeat(Map.merge(session, %{"context" => message}))
  end
end
