defmodule Canopy.Runtimes.CodexLocal.Env do
  @moduledoc """
  Environment variable construction for the Codex Local adapter.

  Builds the `env` list passed to the `codex` Port. All Canopy-injected
  variables use the `CANOPY_` prefix so the running agent process can
  identify its host.

  ## Injected variables

  | Variable                 | Source                                     | Always? |
  |--------------------------|--------------------------------------------|---------|
  | `CANOPY_SESSION_ID`      | Generated or provided `session_id`         | yes     |
  | `CANOPY_API_URL`         | `:canopy, :api_url` app config             | yes     |
  | `CODEX_HOME`             | `context["codex_home"]` or default         | yes     |
  | `OPENAI_API_KEY`         | Vault `("codex-local", "api_key")`         | optional|
  | `OPENAI_BASE_URL`        | Vault `("codex-local", "base_url")`        | optional|
  | `CANOPY_TASK_ID`         | `context["task_id"]`                       | optional|
  | `CANOPY_WAKE_REASON`     | `context["wake_reason"]`                   | optional|
  | `CANOPY_WORKSPACE_CWD`   | `context["cwd"]`                           | optional|

  `OPENAI_API_KEY` and `OPENAI_BASE_URL` are looked up from the vault at
  execute time. If no key is stored, the variables are omitted so that the
  `codex` binary uses its own credentials.
  """

  alias Canopy.Vault

  @runtime_type "codex-local"

  @doc """
  Builds the environment variable list for a `codex` Port.

  Returns `{:ok, env}` where `env` is a list of `{charlist_key, charlist_value}`
  tuples, as required by `:erlang.open_port/2`.
  """
  @spec build(map(), String.t()) :: {:ok, [{charlist(), charlist()}]}
  def build(context, session_id) do
    api_url = Application.get_env(:canopy, :api_url, "http://localhost:4000") |> to_string()
    codex_home = resolve_codex_home(context)
    {task_id, wake_reason, workspace_cwd} = extract_context_vars(context)
    {api_key, base_url} = vault_credentials()

    base = [
      {"CANOPY_SESSION_ID", session_id},
      {"CANOPY_API_URL", api_url},
      {"CODEX_HOME", codex_home}
    ]

    optional = [
      if(api_key, do: {"OPENAI_API_KEY", api_key}),
      if(base_url, do: {"OPENAI_BASE_URL", base_url}),
      if(task_id != "", do: {"CANOPY_TASK_ID", task_id}),
      if(wake_reason != "", do: {"CANOPY_WAKE_REASON", wake_reason}),
      if(workspace_cwd != "", do: {"CANOPY_WORKSPACE_CWD", workspace_cwd})
    ]

    env =
      (base ++ Enum.reject(optional, &is_nil/1))
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    {:ok, env}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec extract_context_vars(map()) :: {String.t(), String.t(), String.t()}
  defp extract_context_vars(context) do
    task_id = Map.get(context, "task_id", "") |> to_string() |> String.trim()
    wake_reason = Map.get(context, "wake_reason", "") |> to_string() |> String.trim()
    workspace_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()
    {task_id, wake_reason, workspace_cwd}
  end

  @spec vault_credentials() :: {String.t() | nil, String.t() | nil}
  defp vault_credentials do
    api_key =
      case Vault.get(@runtime_type, "api_key") do
        {:ok, key} -> key
        {:error, :not_found} -> nil
      end

    base_url =
      case Vault.get(@runtime_type, "base_url") do
        {:ok, url} -> url
        {:error, :not_found} -> nil
      end

    {api_key, base_url}
  end

  # Resolves the CODEX_HOME to use for the spawned process.
  # Prefers an explicit override in context, then the CODEX_HOME env var,
  # then falls back to ~/.codex.
  @spec resolve_codex_home(map()) :: String.t()
  defp resolve_codex_home(context) do
    configured = Map.get(context, "codex_home", "") |> to_string() |> String.trim()

    if configured != "" do
      configured
    else
      case System.get_env("CODEX_HOME") do
        home when is_binary(home) and home != "" ->
          String.trim(home)

        _other ->
          home = System.get_env("HOME", "")
          Path.join(home, ".codex")
      end
    end
  end
end
