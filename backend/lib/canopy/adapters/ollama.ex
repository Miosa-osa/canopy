defmodule Canopy.Adapters.Ollama do
  @moduledoc """
  Ollama adapter — calls the local Ollama HTTP API for LLM inference.

  Unlike other adapters, this does NOT spawn a CLI process. It communicates
  with the Ollama daemon via `POST http://localhost:11434/api/chat` using
  streaming NDJSON (one JSON object per line, `"done": false` until final).

  ## Setup

      brew install ollama
      ollama serve          # start the daemon
      ollama pull llama3    # pull a model

  Verify it's running:

      curl http://localhost:11434/api/tags

  ## Config keys

  - `"model"` — Ollama model name (default: `"llama3"`)
  - `"base_url"` — Ollama base URL (default: `"http://localhost:11434"`)
  - `"options"` — map of Ollama model options (temperature, top_p, etc., optional)
  - `"system"` — system prompt (optional)

  ## Health

  Health check calls `GET /api/tags`. If Ollama is not running, `health/0`
  returns `{:error, "Ollama daemon not reachable at ..."}`.
  """

  @behaviour Canopy.Adapter

  require Logger

  @default_base_url "http://localhost:11434"
  @default_model "llama3"
  @receive_timeout 300_000

  @impl true
  def type, do: "ollama"

  @impl true
  def name, do: "Ollama"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit]

  @impl true
  def health do
    base_url = Application.get_env(:canopy, :ollama_base_url, @default_base_url)

    case Req.get("#{base_url}/api/tags", receive_timeout: 5_000) do
      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status}} ->
        {:error, "Ollama daemon returned HTTP #{status} at #{base_url}"}

      {:error, reason} ->
        {:error, "Ollama daemon not reachable at #{base_url}: #{inspect(reason)}"}
    end
  end

  @impl true
  def start(config) do
    {:ok,
     %{
       base_url: config["base_url"] || @default_base_url,
       model: config["model"] || @default_model,
       system: config["system"],
       options: config["options"] || %{}
     }}
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    base_url = params["base_url"] || @default_base_url
    model = params["model"] || @default_model
    prompt = params["context"] || "Perform your scheduled task."
    system = params["system"]
    options = params["options"] || %{}

    messages = build_messages(system, prompt)
    stream_ollama(base_url, model, messages, options)
  end

  @impl true
  def send_message(%{base_url: base_url, model: model, system: system, options: options}, message) do
    messages = build_messages(system, message)
    stream_ollama(base_url, model, messages, options)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp build_messages(nil, user_prompt) do
    [%{"role" => "user", "content" => user_prompt}]
  end

  defp build_messages(system_prompt, user_prompt) do
    [
      %{"role" => "system", "content" => system_prompt},
      %{"role" => "user", "content" => user_prompt}
    ]
  end

  defp stream_ollama(base_url, model, messages, options) do
    url = "#{base_url}/api/chat"

    body =
      %{
        "model" => model,
        "messages" => messages,
        "stream" => true
      }
      |> maybe_put_options(options)

    Stream.resource(
      fn -> {url, body, ""} end,
      fn
        :done ->
          {:halt, :done}

        {url, body, ""} ->
          case Req.post(url,
                 json: body,
                 receive_timeout: @receive_timeout,
                 into: :self
               ) do
            {:ok, response} ->
              {[], {:streaming, response, ""}}

            {:error, reason} ->
              event = %{
                event_type: "run.failed",
                data: %{"error" => inspect(reason), "adapter" => type()},
                tokens: 0
              }

              {[event], :done}
          end

        {:streaming, response, buffer} ->
          receive do
            {ref, data} when is_reference(ref) ->
              case data do
                {:data, chunk} ->
                  combined = buffer <> chunk
                  {events, remaining} = parse_ndjson_chunk(combined)
                  {events, {:streaming, response, remaining}}

                :done ->
                  {[%{event_type: "run.completed", data: %{}, tokens: 0}], :done}

                {:error, reason} ->
                  event = %{
                    event_type: "run.failed",
                    data: %{"error" => inspect(reason)},
                    tokens: 0
                  }

                  {[event], :done}
              end
          after
            @receive_timeout ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"error" => "Ollama stream timeout"},
                   tokens: 0
                 }
               ], :done}
          end
      end,
      fn _ -> :ok end
    )
  end

  # Parse newline-delimited JSON chunks from the Ollama streaming response.
  # Each line is a JSON object: {"model":"...","message":{"role":"assistant","content":"..."},"done":false}
  # The final line has "done":true and includes eval_count (token usage).
  defp parse_ndjson_chunk(buffer) do
    lines = String.split(buffer, "\n")
    {complete_lines, [partial]} = Enum.split(lines, length(lines) - 1)

    events =
      complete_lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.flat_map(fn line ->
        case Jason.decode(line) do
          {:ok, %{"done" => true} = obj} ->
            tokens_output = obj["eval_count"] || 0
            tokens_input = obj["prompt_eval_count"] || 0

            [
              %{
                event_type: "run.completed",
                data: %{"model" => obj["model"]},
                tokens_input: tokens_input,
                tokens_output: tokens_output,
                tokens: tokens_input + tokens_output
              }
            ]

          {:ok, %{"done" => false, "message" => %{"content" => content}}} ->
            [%{event_type: "run.output", data: %{"text" => content}, tokens: 0}]

          {:ok, %{"error" => err}} ->
            [%{event_type: "run.failed", data: %{"error" => err}, tokens: 0}]

          _ ->
            []
        end
      end)

    {events, partial}
  end

  defp maybe_put_options(body, opts) when map_size(opts) == 0, do: body
  defp maybe_put_options(body, opts), do: Map.put(body, "options", opts)
end
