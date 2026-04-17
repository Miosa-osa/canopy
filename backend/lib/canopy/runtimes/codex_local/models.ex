defmodule Canopy.Runtimes.CodexLocal.Models do
  @moduledoc """
  Canonical Codex model metadata — context windows and capabilities.

  Model IDs verified against Paperclip's `index.ts` and `codex-args.ts`
  (packages/adapters/codex-local/src/index.ts, April 2026).

  Two entry points:

  - `list/0` — returns the full model catalogue as a list of maps.
  - `detect/0` — reads `~/.codex/config.json` to discover which model the
    user has configured locally.
  """

  @default_model "gpt-5.3-codex"

  @doc """
  Returns the static Codex model catalogue.

  Each model map includes: `id`, `label`, `capabilities`.
  Codex does not publicly document per-model pricing via the CLI, so
  cost fields are omitted. Context windows are approximations from
  OpenAI documentation (April 2026).
  """
  @spec list() :: {:ok, [map()]}
  def list do
    models = [
      %{
        id: "gpt-5.4",
        label: "gpt-5.4",
        context_window: 128_000,
        capabilities: ["streaming", "fast_mode"]
      },
      %{
        id: "gpt-5.3-codex",
        label: "gpt-5.3-codex",
        context_window: 128_000,
        capabilities: ["streaming"]
      },
      %{
        id: "gpt-5.3-codex-spark",
        label: "gpt-5.3-codex-spark",
        context_window: 128_000,
        capabilities: ["streaming"]
      },
      %{
        id: "gpt-5",
        label: "gpt-5",
        context_window: 128_000,
        capabilities: ["streaming"]
      },
      %{
        id: "o3",
        label: "o3",
        context_window: 200_000,
        capabilities: ["streaming", "reasoning"]
      },
      %{
        id: "o4-mini",
        label: "o4-mini",
        context_window: 200_000,
        capabilities: ["streaming", "reasoning"]
      },
      %{
        id: "gpt-5-mini",
        label: "gpt-5-mini",
        context_window: 128_000,
        capabilities: ["streaming"]
      },
      %{
        id: "gpt-5-nano",
        label: "gpt-5-nano",
        context_window: 128_000,
        capabilities: ["streaming"]
      },
      %{
        id: "o3-mini",
        label: "o3-mini",
        context_window: 200_000,
        capabilities: ["streaming", "reasoning"]
      },
      %{
        id: "codex-mini-latest",
        label: "Codex Mini",
        context_window: 128_000,
        capabilities: ["streaming"]
      }
    ]

    {:ok, models}
  end

  @doc """
  Detects the locally configured Codex model from `~/.codex/config.json`.

  Returns `{:ok, model_info}` when the file exists and contains a `"model"` key,
  or `{:error, :not_detected}` otherwise.

  The returned map includes: `model`, `provider`, `source`, and `candidates`.
  Falls back to `#{@default_model}` as the default model when no config is found.
  """
  @spec detect() :: {:ok, map()} | {:error, :not_detected}
  def detect do
    home = System.get_env("HOME", "")
    codex_home = resolve_codex_home(home)
    config_path = Path.join(codex_home, "config.json")

    with true <- File.exists?(config_path),
         {:ok, raw} <- File.read(config_path),
         {:ok, data} <- Jason.decode(raw),
         model when is_binary(model) and model != "" <- get_in(data, ["model"]) do
      {:ok,
       %{
         model: model,
         provider: "openai",
         source: config_path,
         candidates: [model]
       }}
    else
      _other -> {:error, :not_detected}
    end
  end

  # Resolves the effective CODEX_HOME directory.
  # Respects the CODEX_HOME env var; falls back to ~/.codex.
  @spec resolve_codex_home(String.t()) :: Path.t()
  defp resolve_codex_home(home) do
    case System.get_env("CODEX_HOME") do
      codex_home when is_binary(codex_home) and codex_home != "" ->
        String.trim(codex_home)

      _other ->
        Path.join(home, ".codex")
    end
  end
end
