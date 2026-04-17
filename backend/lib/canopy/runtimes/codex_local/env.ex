defmodule Canopy.Runtimes.CodexLocal.Env do
  @moduledoc """
  Environment variable construction for the Codex Local adapter.

  Builds the `env` list passed to the `codex` Port. All Canopy-injected
  variables use the `CANOPY_` prefix so the running agent process can
  identify its host.

  ## Injected variables

  | Variable                 | Source                                | Always? |
  |--------------------------|---------------------------------------|---------|
  | `CANOPY_SESSION_ID`      | Generated or provided `session_id`    | yes     |
  | `CANOPY_API_URL`         | `:canopy, :api_url` app config        | yes     |
  | `CODEX_HOME`             | `context["codex_home"]` or default    | yes     |
  | `CANOPY_TASK_ID`         | `context["task_id"]`                  | optional|
  | `CANOPY_WAKE_REASON`     | `context["wake_reason"]`              | optional|
  | `CANOPY_WORKSPACE_CWD`   | `context["cwd"]`                      | optional|
  | `OPENAI_API_KEY`         | `context["openai_api_key"]`           | optional|
  """

  @doc """
  Builds the environment variable list for a `codex` Port.

  Returns `{:ok, env}` where `env` is a list of `{charlist_key, charlist_value}`
  tuples, as required by `:erlang.open_port/2`.
  """
  @spec build(map(), String.t()) :: {:ok, [{charlist(), charlist()}]}
  def build(context, session_id) do
    task_id = Map.get(context, "task_id", "") |> to_string() |> String.trim()
    wake_reason = Map.get(context, "wake_reason", "") |> to_string() |> String.trim()
    workspace_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()
    openai_api_key = Map.get(context, "openai_api_key", "") |> to_string() |> String.trim()
    codex_home = resolve_codex_home(context)
    api_url = Application.get_env(:canopy, :api_url, "http://localhost:4000") |> to_string()

    base = [
      {"CANOPY_SESSION_ID", session_id},
      {"CANOPY_API_URL", api_url},
      {"CODEX_HOME", codex_home}
    ]

    optional = [
      if(task_id != "", do: {"CANOPY_TASK_ID", task_id}),
      if(wake_reason != "", do: {"CANOPY_WAKE_REASON", wake_reason}),
      if(workspace_cwd != "", do: {"CANOPY_WORKSPACE_CWD", workspace_cwd}),
      if(openai_api_key != "", do: {"OPENAI_API_KEY", openai_api_key})
    ]

    env =
      (base ++ Enum.reject(optional, &is_nil/1))
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    {:ok, env}
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
