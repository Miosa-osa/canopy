defmodule Canopy.Runtimes.GeminiLocal.Models do
  @moduledoc """
  Canonical Gemini model metadata — context windows, costs, capabilities.

  Model IDs and labels sourced from Google Gemini API docs (April 2026).

  The default model is `"auto"` — the Gemini CLI selects the best model for
  the task when no explicit model is configured.

  Two entry points:

  - `list/0` — returns the full model catalogue as a list of maps.
  - `detect/0` — reads `~/.config/gemini/settings.json` (or
    `~/.gemini/settings.json`) to discover the locally configured model.
  """

  @default_model "auto"

  @doc "Returns the default Gemini model ID (`\"auto\"`)."
  @spec default_model() :: String.t()
  def default_model, do: @default_model

  @doc """
  Returns the static Gemini model catalogue.

  Each model map includes: `id`, `label`, `context_window`,
  `cost_per_1m_input_usd`, `cost_per_1m_output_usd`, and `capabilities`.
  Context windows and pricing from Google AI Studio docs (April 2026).
  """
  @spec list() :: {:ok, [map()]}
  def list do
    models = [
      %{
        id: "auto",
        label: "Auto (CLI selects)",
        context_window: 1_000_000,
        cost_per_1m_input_usd: nil,
        cost_per_1m_output_usd: nil,
        capabilities: ["streaming", "tool_calls", "thinking"]
      },
      %{
        id: "gemini-2.5-pro",
        label: "Gemini 2.5 Pro",
        context_window: 1_048_576,
        cost_per_1m_input_usd: 1.25,
        cost_per_1m_output_usd: 10.0,
        capabilities: ["streaming", "tool_calls", "thinking"]
      },
      %{
        id: "gemini-2.5-flash",
        label: "Gemini 2.5 Flash",
        context_window: 1_048_576,
        cost_per_1m_input_usd: 0.3,
        cost_per_1m_output_usd: 2.5,
        capabilities: ["streaming", "tool_calls", "thinking"]
      },
      %{
        id: "gemini-2.5-flash-lite",
        label: "Gemini 2.5 Flash Lite",
        context_window: 1_048_576,
        cost_per_1m_input_usd: 0.1,
        cost_per_1m_output_usd: 0.4,
        capabilities: ["streaming", "tool_calls"]
      },
      %{
        id: "gemini-2.0-flash",
        label: "Gemini 2.0 Flash",
        context_window: 1_048_576,
        cost_per_1m_input_usd: 0.1,
        cost_per_1m_output_usd: 0.4,
        capabilities: ["streaming", "tool_calls"]
      },
      %{
        id: "gemini-2.0-flash-lite",
        label: "Gemini 2.0 Flash Lite",
        context_window: 1_048_576,
        cost_per_1m_input_usd: 0.075,
        cost_per_1m_output_usd: 0.3,
        capabilities: ["streaming", "tool_calls"]
      }
    ]

    {:ok, models}
  end

  @doc """
  Detects the locally configured Gemini model from CLI settings files.

  Tries, in order:
  1. `~/.config/gemini/settings.json` (XDG config path)
  2. `~/.gemini/settings.json` (legacy path)

  Returns `{:ok, model_info}` when the file exists and contains a `"model"` key,
  or `{:error, :not_detected}` otherwise.

  The returned map includes: `model`, `provider`, `source`, and `candidates`.
  """
  @spec detect() :: {:ok, map()} | {:error, :not_detected}
  def detect do
    home = System.get_env("HOME", "")
    candidates = settings_candidates(home)

    Enum.find_value(candidates, {:error, :not_detected}, fn path ->
      case read_model_from_settings(path) do
        {:ok, model} ->
          {:ok,
           %{
             model: model,
             provider: "google",
             source: path,
             candidates: candidates
           }}

        :error ->
          nil
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec settings_candidates(String.t()) :: [Path.t()]
  defp settings_candidates(home) do
    [
      Path.join([home, ".config", "gemini", "settings.json"]),
      Path.join([home, ".gemini", "settings.json"])
    ]
  end

  @spec read_model_from_settings(Path.t()) :: {:ok, String.t()} | :error
  defp read_model_from_settings(path) do
    with true <- File.exists?(path),
         {:ok, raw} <- File.read(path),
         {:ok, data} <- Jason.decode(raw),
         model when is_binary(model) and model != "" <- get_in(data, ["model"]) do
      {:ok, model}
    else
      _other -> :error
    end
  end
end
