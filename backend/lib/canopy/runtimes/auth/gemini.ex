defmodule Canopy.Runtimes.Auth.Gemini do
  @moduledoc """
  Authentication provider for the Google Gemini CLI (`gemini` binary).

  ## Auth strategy

  Gemini CLI supports three auth methods:

  1. **API key** — `GEMINI_API_KEY` or `GOOGLE_API_KEY` env var.
  2. **Service account** — `GOOGLE_APPLICATION_CREDENTIALS` pointing to a JSON key file.
  3. **Google OAuth** — session stored by the CLI at `~/.gemini/oauth_creds.json` after
     the user runs `gemini` interactively and chooses "Sign in with Google".

  Canopy stores the API key encrypted in the vault under `("gemini-local", "api_key")`.
  The OAuth session is CLI-managed; Canopy reads auth status by probing the local file
  system and the `gemini --version` binary.

  A Google OAuth device-flow endpoint is not documented in any public source reviewed.
  Add the URL to config under `:canopy, [:gemini_auth, :device_authorization_url]` when confirmed.

  ## test/1

  Invokes `gemini --version` to confirm binary availability, then checks for any
  auth signal (API key in credential map or OAuth creds file on disk).
  """

  @behaviour Canopy.Runtimes.Auth.Provider

  alias Canopy.Runtimes.GeminiLocal.Binary

  @impl true
  def runtime_type, do: "gemini-local"

  @impl true
  def start_device_flow do
    # TODO: implement when Google publishes a public device-authorization endpoint for Gemini CLI.
    # Config key: config :canopy, :gemini_auth, device_authorization_url: "https://..."
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
          [{"GEMINI_API_KEY", api_key}]
        else
          []
        end

      {output, elapsed_ms} =
        timed(fn -> System.cmd(binary, ["--version"], env: env, stderr_to_stdout: true) end)

      has_oauth_creds = oauth_creds_on_disk?()

      case output do
        {version_str, 0} ->
          authenticated = api_key != nil || has_oauth_creds

          {:ok,
           %{
             ok: authenticated,
             model: String.trim(version_str),
             latency_ms: elapsed_ms
           }}

        {error_output, _code} ->
          {:ok,
           %{ok: false, model: nil, latency_ms: elapsed_ms, error: String.trim(error_output)}}
      end
    else
      {:error, :not_installed} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "gemini binary not found on PATH"}}

      {:error, {:binary_path_not_allowed, path}} ->
        {:ok, %{ok: false, model: nil, latency_ms: 0, error: "binary path not allowed: #{path}"}}
    end
  rescue
    error in ErlangError ->
      {:ok, %{ok: false, model: nil, latency_ms: 0, error: Exception.message(error)}}
  end

  # Checks for CLI-managed OAuth credentials written by `gemini` (interactive login).
  @spec oauth_creds_on_disk?() :: boolean()
  defp oauth_creds_on_disk? do
    home = System.get_env("HOME", "")
    oauth_path = Path.join([home, ".gemini", "oauth_creds.json"])
    account_path = Path.join([home, ".gemini", "google_account_id"])
    File.exists?(oauth_path) || File.exists?(account_path)
  end

  @spec timed((-> result)) :: {result, non_neg_integer()} when result: term()
  defp timed(fun) do
    start = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed = System.monotonic_time(:millisecond) - start
    {result, elapsed}
  end
end
