defmodule Canopy.Skills do
  @moduledoc """
  Public API for Canopy skill management.

  A skill is a folder of markdown files (CLAUDE.md / HEARTBEAT.md / SOUL.md /
  TOOLS.md) injected into the agent's system prompt via `--append-system-prompt-file`
  before each heartbeat. The content-addressed bundle key (SHA256) prevents
  re-injection when nothing has changed — the primary token-saving optimization
  from the Paperclip dossier.

  On session resume: if `prompt_bundle_key` matches the stored key, skill injection
  is skipped entirely, saving 5–10K tokens per heartbeat.

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 2 scope.
  """

  @doc "Lists all available skills."
  @spec list() :: {:ok, [map()]} | {:error, :not_implemented}
  def list do
    {:error, :not_implemented}
  end

  @doc "Retrieves a skill by name."
  @spec get(String.t()) :: {:ok, map()} | {:error, :not_found | :not_implemented}
  def get(_name) do
    {:error, :not_implemented}
  end

  @doc """
  Computes the SHA256 bundle key for the given set of skill names.

  The key is derived from the combined content of all skill markdown files
  in the specified set. Identical content = identical key = skip re-injection.
  """
  @spec bundle_key([String.t()]) :: {:ok, String.t()} | {:error, :not_implemented}
  def bundle_key(_skill_names) do
    {:error, :not_implemented}
  end
end
