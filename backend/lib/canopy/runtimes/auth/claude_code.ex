defmodule Canopy.Runtimes.Auth.ClaudeCode do
  @moduledoc """
  Authentication provider for the Claude Code CLI (`claude` binary from Anthropic).

  ## Auth strategy

  Claude Code manages its own OAuth session via `claude auth login` (browser redirect
  or device-code). Canopy can optionally inject an `ANTHROPIC_API_KEY` via the vault
  to bypass Anthropic's managed OAuth entirely (Pro/Max subscribers who prefer
  direct API access).

  For the device-code / managed OAuth path, Anthropic does not publish a public
  device-authorization endpoint. The `start_device_flow/0` callback is therefore
  not implemented — the canonical auth path is:

      1. User runs `claude auth login` in a terminal (browser-based).
      2. Canopy reads auth status via `claude auth status --output-format json`.
      3. On success, Canopy marks the credential `:active` with a synthetic token.

  If Anthropic publishes an official OAuth device endpoint, add the URL to
  application config under `:canopy, [:claude_code_auth, :device_authorization_url]`
  and implement the RFC 8628 flow below.

  ## test/1

  Invokes `claude --version` to confirm the binary works. Full prompt execution
  would require dangerously-skip-permissions which is inappropriate for a health check.
  """

  @behaviour Canopy.Runtimes.Auth.Provider

  alias Canopy.Runtimes.ClaudeLocal.Binary

  @impl true
  def runtime_type, do: "claude-local"

  @impl true
  def start_device_flow do
    # TODO: implement when Anthropic publishes a device-authorization endpoint.
    # Config key to add: config :canopy, :claude_code_auth, device_authorization_url: "https://..."
    {:error, :not_supported}
  end

  @impl true
  def poll_token(_device_code), do: {:error, :not_supported}

  @impl true
  def refresh(_refresh_token), do: {:error, :not_supported}

  @impl true
  def revoke(_access_token), do: :ok

  @impl true
  def test(_credential) do
    binary = Binary.resolve(%{})

    with :ok <- Binary.guard_path(binary) do
      {output, elapsed_ms} =
        timed(fn -> System.cmd(binary, ["--version"], stderr_to_stdout: true) end)

      case output do
        {version_str, 0} ->
          {:ok, %{ok: true, model: String.trim(version_str), latency_ms: elapsed_ms}}

        {error_output, _exit_code} ->
          {:ok,
           %{ok: false, model: nil, latency_ms: elapsed_ms, error: String.trim(error_output)}}
      end
    else
      {:error, :not_installed} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "claude binary not found on PATH"}}

      {:error, {:binary_path_not_allowed, path}} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "binary path not allowed: #{path}"}}
    end
  end

  @spec timed((-> result)) :: {result, non_neg_integer()} when result: term()
  defp timed(fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = System.monotonic_time(:millisecond) - start
    {result, elapsed}
  end
end
