defmodule Canopy.Runtimes.GeminiLocal.Env do
  @moduledoc """
  Environment variable construction for the Gemini Local adapter.

  Builds the `env` list passed to the `gemini` Port. All Canopy-injected
  variables use the `CANOPY_` prefix so the running agent process can identify
  its host environment.

  ## Injected variables

  | Variable               | Source                                         | Always? |
  |------------------------|------------------------------------------------|---------|
  | `CANOPY_SESSION_ID`    | Generated or provided `session_id`             | yes     |
  | `CANOPY_API_URL`       | `:canopy, :api_url` app config                 | yes     |
  | `GEMINI_API_KEY`       | Vault `("gemini-local", "api_key")`            | optional|
  | `GOOGLE_API_KEY`       | Vault `("gemini-local", "api_key")` (alias)    | optional|
  | `CANOPY_TASK_ID`       | `context["task_id"]`                           | optional|
  | `CANOPY_WAKE_REASON`   | `context["wake_reason"]`                       | optional|
  | `CANOPY_WORKSPACE_CWD` | `context["cwd"]`                               | optional|

  `GEMINI_API_KEY` and `GOOGLE_API_KEY` are set to the same vault value when
  present — the Gemini CLI accepts both. When no key is stored, the CLI uses
  its own stored credentials from `gemini auth login`.
  """

  alias Canopy.Vault

  @doc """
  Builds the environment variable list for a `gemini` Port.

  Returns `{:ok, env}` where `env` is a list of `{charlist_key, charlist_value}`
  tuples, as required by `:erlang.open_port/2`.
  """
  @spec build(map(), String.t()) :: {:ok, [{charlist(), charlist()}]}
  def build(context, session_id) do
    task_id = Map.get(context, "task_id", "") |> to_string() |> String.trim()
    wake_reason = Map.get(context, "wake_reason", "") |> to_string() |> String.trim()
    workspace_cwd = Map.get(context, "cwd", "") |> to_string() |> String.trim()
    api_url = Application.get_env(:canopy, :api_url, "http://localhost:4000") |> to_string()

    api_key =
      case Vault.get("gemini-local", "api_key") do
        {:ok, key} -> key
        {:error, :not_found} -> nil
      end

    base = [
      {"CANOPY_SESSION_ID", session_id},
      {"CANOPY_API_URL", api_url}
    ]

    optional = [
      if(api_key, do: {"GEMINI_API_KEY", api_key}),
      if(api_key, do: {"GOOGLE_API_KEY", api_key}),
      if(task_id != "", do: {"CANOPY_TASK_ID", task_id}),
      if(wake_reason != "", do: {"CANOPY_WAKE_REASON", wake_reason}),
      if(workspace_cwd != "", do: {"CANOPY_WORKSPACE_CWD", workspace_cwd})
    ]

    env =
      (base ++ Enum.reject(optional, &is_nil/1))
      |> Enum.map(fn {k, v} -> {to_charlist(k), to_charlist(v)} end)

    {:ok, env}
  end
end
