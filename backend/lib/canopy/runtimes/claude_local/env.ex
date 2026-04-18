defmodule Canopy.Runtimes.ClaudeLocal.Env do
  @moduledoc """
  Environment variable construction for the Claude Local adapter.

  Builds the `env` list passed to the `claude` Port.  All variables use the
  `CANOPY_` prefix so the running agent process can identify its host.

  ## Injected variables

  | Variable                    | Source                                | Always? |
  |-----------------------------|---------------------------------------|---------|
  | `CANOPY_SESSION_ID`         | Generated or provided `session_id`    | yes     |
  | `CANOPY_API_URL`            | `:canopy, :api_url` app config        | yes     |
  | `CLAUDECODE`                | Empty string (nesting guard)          | yes     |
  | `CLAUDE_CODE_ENTRYPOINT`    | Empty string (nesting guard)          | yes     |
  | `CLAUDE_CODE_SESSION`       | Empty string (nesting guard)          | yes     |
  | `ANTHROPIC_API_KEY`         | `Canopy.Vault.get("claude-local", "api_key")` | optional|
  | `CANOPY_TASK_ID`            | `context["task_id"]`                  | optional|
  | `CANOPY_WAKE_REASON`        | `context["wake_reason"]`              | optional|
  | `CANOPY_WORKSPACE_CWD`      | `context["cwd"]`                      | optional|
  | `CANOPY_MIOSA_SANDBOX_URL`  | `context["miosa_sandbox_url"]`        | optional|

  The three nesting-guard variables (`CLAUDECODE`, `CLAUDE_CODE_ENTRYPOINT`,
  `CLAUDE_CODE_SESSION`) are set to empty strings to prevent recursive
  `claude` invocations inside the spawned process from inheriting the parent's
  session context.

  The `ANTHROPIC_API_KEY` is looked up from the vault at execute time. If no
  key is stored, the variable is omitted so that the `claude` binary falls back
  to its own stored credentials (e.g. `claude auth login`).
  """

  alias Canopy.Vault

  @doc """
  Builds the environment variable list for a `claude` Port.

  Returns `{:ok, env}` where `env` is a list of `{charlist_key, charlist_value}`
  tuples, as required by `:erlang.open_port/2`.
  """
  @spec build(map(), String.t()) :: {:ok, [{charlist(), charlist()}]}
  def build(context, session_id) do
    task_id = Map.get(context, "task_id", "") |> to_string() |> String.trim()
    wake_reason = Map.get(context, "wake_reason", "") |> to_string() |> String.trim()
    workspace_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()
    sandbox_url = Map.get(context, "miosa_sandbox_url", "") |> to_string() |> String.trim()
    api_url = Application.get_env(:canopy, :api_url, "http://localhost:4000") |> to_string()

    api_key =
      case Vault.get("claude-local", "api_key") do
        {:ok, key} -> key
        {:error, :not_found} -> nil
      end

    base = [
      {"CANOPY_SESSION_ID", session_id},
      {"CANOPY_API_URL", api_url},
      # Nesting guard — prevent recursive claude invocations inside this process
      {"CLAUDECODE", ""},
      {"CLAUDE_CODE_ENTRYPOINT", ""},
      {"CLAUDE_CODE_SESSION", ""}
    ]

    optional = [
      if(api_key, do: {"ANTHROPIC_API_KEY", api_key}),
      if(task_id != "", do: {"CANOPY_TASK_ID", task_id}),
      if(wake_reason != "", do: {"CANOPY_WAKE_REASON", wake_reason}),
      if(workspace_cwd != "", do: {"CANOPY_WORKSPACE_CWD", workspace_cwd}),
      if(sandbox_url != "", do: {"CANOPY_MIOSA_SANDBOX_URL", sandbox_url})
    ]

    env =
      (base ++ Enum.reject(optional, &is_nil/1))
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    {:ok, env}
  end
end
