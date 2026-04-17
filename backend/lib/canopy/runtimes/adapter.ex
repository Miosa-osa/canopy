defmodule Canopy.Runtimes.Adapter do
  @moduledoc """
  Behaviour contract for all Canopy runtime adapters.

  Derived from the Paperclip `ServerAdapterModule` interface (packages/adapter-utils/src/types.ts).
  Every AI runtime that Canopy manages — Claude Code, Codex, Gemini, Cursor, OpenCode,
  Aider, Windsurf, Pi, Hermes — must implement this behaviour.

  Design principles:
  - Use `capabilities/0` returning a `MapSet` of atoms rather than boolean flag proliferation.
    This prevents the 7-flag problem documented in the Paperclip dossier.
  - All callbacks return tagged tuples — no exceptions propagate through the adapter boundary.
  - `test_environment/1` is the preflight gate run before saving a runtime config.
  - `get_config_schema/0` returns a declarative form spec; the UI renders it without
    per-adapter frontend code (Paperclip pattern).
  - `get_quota_windows/0` queries the provider's live usage API for the runtime card display.
  - `detect_model/0` reads local config (e.g., ~/.claude/settings.json) to discover the
    active model without requiring manual user input.
  - `execute/1` runs the subprocess and returns a structured result. The Rust sidecar
    owns the PTY; this callback provides the args and env vars.
  """

  @type capability ::
          :session_resume
          | :quota_windows
          | :model_detection
          | :config_schema
          | :skill_injection
          | :local_agent_jwt

  @type environment_check_level :: :info | :warn | :error

  @type environment_check :: %{
          level: environment_check_level(),
          message: String.t()
        }

  @type quota_window :: %{
          label: String.t(),
          used_percent: float(),
          resets_at: DateTime.t() | nil,
          value_label: String.t()
        }

  @type config_field_type :: :text | :select | :toggle | :number | :combobox

  @type config_field :: %{
          key: String.t(),
          label: String.t(),
          type: config_field_type(),
          required: boolean(),
          options: [String.t()] | nil,
          placeholder: String.t() | nil
        }

  # ---------------------------------------------------------------------------
  # Required callbacks
  # ---------------------------------------------------------------------------

  @doc "Returns a unique string identifier for this runtime type (e.g. \"claude-local\")."
  @callback type() :: String.t()

  @doc "Returns the set of optional capabilities this adapter supports."
  @callback capabilities() :: MapSet.t(capability())

  @doc """
  Runs preflight environment checks before saving an agent config.

  Returns a list of structured checks at info/warn/error levels. The UI
  surfaces these inline on the runtime configuration form. A result with any
  `:error` level check must block the save.
  """
  @callback test_environment(context :: map()) ::
              {:ok, [environment_check()]} | {:error, term()}

  @doc """
  Reads local config files to detect the currently configured model.

  For example, the Claude adapter reads `~/.claude/settings.json`.
  Returns `{:error, :not_detected}` when no model is discoverable.
  """
  @callback detect_model() :: {:ok, map()} | {:error, :not_detected}

  @doc "Lists all models available for this runtime (may hit a provider API)."
  @callback list_models() :: {:ok, [map()]} | {:error, term()}

  @doc """
  Returns a declarative config schema for this adapter.

  The UI renders these fields dynamically without per-adapter Svelte components.
  This is the Paperclip `AdapterConfigSchema` pattern.
  """
  @callback get_config_schema() :: {:ok, [config_field()]}

  @doc """
  Fetches live quota windows from the provider's usage API.

  Returns structured windows with used percentages and reset times. Powers the
  quota gauge on the runtime card. Not all adapters support this — check
  `capabilities/0` for `:quota_windows` before calling.
  """
  @callback get_quota_windows() :: {:ok, [quota_window()]} | {:error, term()}

  @doc """
  Builds the execution context for a session.

  Returns a `session_ref` map containing the CLI args, environment variables,
  and session resume parameters. The actual subprocess is owned by the Rust
  sidecar PTY layer; this callback constructs the launch specification.
  """
  @callback execute(context :: map()) :: {:ok, session_ref :: map()} | {:error, term()}

  # ---------------------------------------------------------------------------
  # Optional callbacks
  # ---------------------------------------------------------------------------

  @doc "Lists skills materialized for this adapter. Optional — check :skill_injection capability."
  @callback list_skills(context :: map()) ::
              {:ok, [map()]} | {:error, term()}

  @doc "Syncs a desired skill set for this adapter. Optional."
  @callback sync_skills(context :: map(), desired_skills :: [String.t()]) ::
              {:ok, map()} | {:error, term()}

  @optional_callbacks list_skills: 1, sync_skills: 2
end
