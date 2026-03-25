defmodule Canopy.Adapters.Gemini do
  @moduledoc """
  Gemini adapter — calls Google's Gemini API via `Req` HTTP client.

  Uses the `gemini-pro` model by default via the `generateContent` REST endpoint.
  Streaming is emulated by reading the full response and emitting output + completed events.

  ## Setup

  Set your API key in one of the following ways (in priority order):

  1. Agent config: `config["api_key"]`
  2. Application env: `config :canopy, :gemini_api_key, "..."`
  3. Environment variable: `GEMINI_API_KEY`

  ## Config keys

  - `"api_key"` — Google AI API key (required if env not set)
  - `"model"` — Gemini model to use (default: `"gemini-pro"`)
  - `"max_output_tokens"` — token limit for response (default: 8192)

  ## Installing Gemini API access

      # Get a key at https://aistudio.google.com/app/apikey
      export GEMINI_API_KEY="your-key-here"
  """

  @behaviour Canopy.Adapter

  require Logger

  @default_model "gemini-pro"
  @api_base "https://generativelanguage.googleapis.com/v1beta/models"
  @default_max_tokens 8192

  @impl true
  def type, do: "gemini"

  @impl true
  def name, do: "Gemini"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:text_generation, :multimodal, :code_generation, :analysis]

  @impl true
  def health do
    if resolve_api_key(%{}),
      do: :ok,
      else: {:error, "GEMINI_API_KEY not configured"}
  end

  @impl true
  def start(config) do
    case resolve_api_key(config) do
      nil ->
        {:error, :missing_api_key}

      api_key ->
        {:ok,
         %{
           api_key: api_key,
           model: config["model"] || @default_model,
           max_output_tokens: config["max_output_tokens"] || @default_max_tokens
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."

    case resolve_api_key(params) do
      nil ->
        missing_key_stream()

      api_key ->
        model = params["model"] || @default_model
        max_tokens = params["max_output_tokens"] || @default_max_tokens
        call_gemini_stream(api_key, model, prompt, max_tokens)
    end
  end

  @impl true
  def send_message(%{api_key: api_key, model: model, max_output_tokens: max_tokens}, message) do
    call_gemini_stream(api_key, model, message, max_tokens)
  end

  # -- Private --

  defp resolve_api_key(config) do
    config["api_key"] ||
      Application.get_env(:canopy, :gemini_api_key) ||
      System.get_env("GEMINI_API_KEY")
  end

  defp call_gemini_stream(api_key, model, prompt, max_tokens) do
    url = "#{@api_base}/#{model}:generateContent?key=#{api_key}"

    body = %{
      contents: [
        %{
          parts: [%{text: prompt}]
        }
      ],
      generationConfig: %{
        maxOutputTokens: max_tokens
      }
    }

    Stream.resource(
      fn -> :pending end,
      fn
        :pending ->
          case Req.post(url, json: body, receive_timeout: 120_000) do
            {:ok, %{status: 200, body: resp}} ->
              {text, input_tokens, output_tokens} = extract_gemini_response(resp)

              events = [
                %{
                  event_type: "run.output",
                  data: %{"text" => text},
                  tokens_input: input_tokens,
                  tokens_output: output_tokens
                },
                %{
                  event_type: "run.completed",
                  data: %{"finish_reason" => extract_finish_reason(resp)},
                  tokens_input: 0,
                  tokens_output: 0
                }
              ]

              {events, :done}

            {:ok, %{status: 400, body: body}} ->
              error = get_in(body, ["error", "message"]) || "Bad request"

              {[%{event_type: "run.failed", data: %{"error" => error, "code" => 400}, tokens: 0}],
               :done}

            {:ok, %{status: 401, body: _body}} ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"error" => "Invalid or expired Gemini API key", "code" => 401},
                   tokens: 0
                 }
               ], :done}

            {:ok, %{status: 429, body: _body}} ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"error" => "Gemini API rate limit exceeded", "code" => 429},
                   tokens: 0
                 }
               ], :done}

            {:ok, %{status: status, body: resp_body}} ->
              error = get_in(resp_body, ["error", "message"]) || "Unexpected status #{status}"

              {[
                 %{
                   event_type: "run.failed",
                   data: %{"error" => error, "code" => status},
                   tokens: 0
                 }
               ], :done}

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

  defp extract_gemini_response(%{"candidates" => [candidate | _]} = resp) do
    text =
      candidate
      |> get_in(["content", "parts"])
      |> List.wrap()
      |> Enum.map_join("", fn part -> part["text"] || "" end)

    usage = resp["usageMetadata"] || %{}
    input_tokens = usage["promptTokenCount"] || 0
    output_tokens = usage["candidatesTokenCount"] || 0

    {text, input_tokens, output_tokens}
  end

  defp extract_gemini_response(_resp), do: {"", 0, 0}

  defp extract_finish_reason(%{"candidates" => [candidate | _]}) do
    candidate["finishReason"] || "STOP"
  end

  defp extract_finish_reason(_), do: "STOP"

  defp missing_key_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "Gemini API key not configured",
              "adapter" => type(),
              "hint" =>
                "Set GEMINI_API_KEY env var, or add api_key to agent config. Get a key at https://aistudio.google.com/app/apikey"
            },
            tokens: 0
          }

          {[event], :done}

        :done ->
          {:halt, :done}
      end,
      fn _ -> :ok end
    )
  end
end
