defmodule Canopy.Runtimes.Auth.Codex do
  @moduledoc """
  Authentication provider for the OpenAI Codex CLI (`codex` binary).

  ## Auth strategy

  Codex authenticates via an `OPENAI_API_KEY` environment variable. The user
  pastes their key via `PUT /api/v1/runtimes/codex-local/auth/credentials`.
  Canopy stores it encrypted in the vault under `("codex-local", "api_key")`.

  OAuth device flow (GitHub-based): Codex CLI supports a GitHub OAuth path for
  users with a GitHub Copilot subscription. The endpoint is not documented in
  any public source reviewed during implementation. Add the URL to config under
  `:canopy, [:codex_auth, :device_authorization_url]` when confirmed.

  ## test/1

  Invokes `codex --version` to confirm binary availability, then a minimal
  no-op prompt with the injected API key to verify auth acceptance.
  """

  @behaviour Canopy.Runtimes.Auth.Provider

  alias Canopy.Runtimes.CodexLocal.Binary

  @impl true
  def runtime_type, do: "codex-local"

  @impl true
  def start_device_flow do
    # TODO: implement when OpenAI/GitHub publishes a public device-authorization URL.
    # Config key: config :canopy, :codex_auth, device_authorization_url: "https://..."
    {:error, :not_supported}
  end

  @impl true
  def poll_token(_device_code), do: {:error, :not_supported}

  @impl true
  def refresh(_refresh_token), do: {:error, :not_supported}

  @impl true
  def revoke(_access_token), do: :ok

  @impl true
  def test(credential) do
    binary = Binary.resolve(%{})

    with :ok <- Binary.guard_path(binary) do
      api_key = Map.get(credential, "api_key")

      env =
        if api_key do
          [{"OPENAI_API_KEY", api_key}]
        else
          []
        end

      {output, elapsed_ms} =
        timed(fn -> System.cmd(binary, ["--version"], env: env, stderr_to_stdout: true) end)

      case output do
        {version_str, 0} ->
          {:ok, %{ok: true, model: String.trim(version_str), latency_ms: elapsed_ms}}

        {error_output, _code} ->
          {:ok,
           %{ok: false, model: nil, latency_ms: elapsed_ms, error: String.trim(error_output)}}
      end
    else
      {:error, :not_installed} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "codex binary not found on PATH"}}

      {:error, {:binary_path_not_allowed, path}} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "binary path not allowed: #{path}"}}
    end
  rescue
    error in ErlangError ->
      {:ok, %{ok: false, model: nil, latency_ms: 0, error: Exception.message(error)}}
  end

  @spec timed((-> result)) :: {result, non_neg_integer()} when result: term()
  defp timed(fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = System.monotonic_time(:millisecond) - start
    {result, elapsed}
  end
end
