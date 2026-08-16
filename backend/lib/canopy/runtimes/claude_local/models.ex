defmodule Canopy.Runtimes.ClaudeLocal.Models do
  @moduledoc """
  Canonical Claude model metadata — context windows, costs, capabilities.

  Model IDs, context windows, and pricing sourced from Anthropic docs (April 2026).

  Two entry points:

  - `list/0` — returns the full model catalogue as a list of maps.
  - `detect/0` — reads `~/.claude/settings.json` to discover which model the
    user has configured locally.
  """

  @doc """
  Returns the static Claude model catalogue.

  Each model map includes: `id`, `label`, `context_window`,
  `cost_per_1m_input_usd`, `cost_per_1m_output_usd`, and `capabilities`.
  """
  @spec list() :: {:ok, [map()]}
  def list do
    models = [
      %{
        id: "claude-sonnet-4-6",
        label: "Claude Sonnet 4.6",
        context_window: 200_000,
        cost_per_1m_input_usd: 3.0,
        cost_per_1m_output_usd: 15.0,
        capabilities: ["streaming", "tool_calls", "thinking"]
      },
      %{
        id: "claude-opus-4-7",
        label: "Claude Opus 4.7",
        context_window: 200_000,
        cost_per_1m_input_usd: 15.0,
        cost_per_1m_output_usd: 75.0,
        capabilities: ["streaming", "tool_calls", "thinking"]
      },
      %{
        id: "claude-haiku-4-5",
        label: "Claude Haiku 4.5",
        context_window: 200_000,
        cost_per_1m_input_usd: 0.8,
        cost_per_1m_output_usd: 4.0,
        capabilities: ["streaming", "tool_calls"]
      }
    ]

    {:ok, models}
  end

  @doc """
  Detects the locally configured Claude model from `~/.claude/settings.json`.

  Returns `{:ok, model_info}` when the file exists and contains a `"model"` key,
  or `{:error, :not_detected}` otherwise.

  The returned map includes: `model`, `provider`, `source`, and `candidates`.
  """
  @spec detect() :: {:ok, map()} | {:error, :not_detected}
  def detect do
    home = System.get_env("HOME", "")
    settings_path = Path.join([home, ".claude", "settings.json"])

    with true <- File.exists?(settings_path),
         {:ok, raw} <- File.read(settings_path),
         {:ok, data} <- Jason.decode(raw),
         model when is_binary(model) and model != "" <- get_in(data, ["model"]) do
      {:ok,
       %{
         model: model,
         provider: "anthropic",
         source: settings_path,
         candidates: [model]
       }}
    else
      _other -> {:error, :not_detected}
    end
  end
end
