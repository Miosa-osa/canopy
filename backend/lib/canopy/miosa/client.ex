defmodule Canopy.Miosa.Client do
  @moduledoc """
  HTTP client for the MIOSA compute API.

  Wraps `Req` with base URL and Bearer auth sourced from the application
  environment (`MIOSA_API_URL` / `MIOSA_API_KEY` in production; stubs in dev/test
  via `config :canopy, :miosa_api_url` and `config :canopy, :miosa_api_key`).

  All functions return tagged `{:ok, result}` or `{:error, reason}` — no exceptions
  escape the module boundary.  The client never logs the API key.

  Retry policy: up to 2 retries on 5xx or transport errors with Req's built-in
  exponential backoff.  Timeout: 30 s per call (configurable via `:timeout` opt).
  """

  @behaviour Canopy.Miosa.ClientBehaviour

  require Logger

  @default_timeout_ms 30_000
  @max_retries 2

  @type sandbox_result :: %{
          sandbox_id: String.t(),
          url: String.t(),
          status: String.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Provisions a new MIOSA sandbox.

  ## Options
    - `:template` — VM template name (default `"default"`)
    - `:ttl_seconds` — max lifetime in seconds (default `3600`)
    - `:resources` — map of resource hints, e.g. `%{cpu: 1, memory_mb: 512}`
    - `:timeout` — per-request timeout in ms (default 30 000)

  ## Returns
    - `{:ok, %{sandbox_id: id, url: url, status: status}}`
    - `{:error, reason}`
  """
  @spec provision_sandbox(keyword()) :: {:ok, sandbox_result()} | {:error, term()}
  def provision_sandbox(opts \\ []) do
    body = %{
      template: Keyword.get(opts, :template, "default"),
      ttl_seconds: Keyword.get(opts, :ttl_seconds, 3600),
      resources: Keyword.get(opts, :resources, %{})
    }

    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    case do_post("/v1/sandboxes", body, receive_timeout: timeout) do
      {:ok, %{"sandbox_id" => id, "url" => url, "status" => status}} ->
        {:ok, %{sandbox_id: id, url: url, status: status}}

      {:ok, body} ->
        {:error, {:unexpected_response, body}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Fetches current sandbox state by ID.

  ## Returns
    - `{:ok, %{sandbox_id: id, url: url, status: status}}`
    - `{:error, :not_found}`
    - `{:error, reason}`
  """
  @spec get_sandbox(String.t()) :: {:ok, sandbox_result()} | {:error, :not_found | term()}
  def get_sandbox(sandbox_id) when is_binary(sandbox_id) do
    case do_get("/v1/sandboxes/#{sandbox_id}") do
      {:ok, %{"sandbox_id" => id, "url" => url, "status" => status}} ->
        {:ok, %{sandbox_id: id, url: url, status: status}}

      {:error, {404, _}} ->
        {:error, :not_found}

      {:ok, body} ->
        {:error, {:unexpected_response, body}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Runs a command inside a running sandbox (fire-and-collect, not streaming).

  ## Options
    - `:timeout` — per-request timeout in ms (default 30 000)
    - `:env` — map of extra environment variables for the command

  ## Returns
    - `{:ok, %{exit_code: integer, stdout: string, stderr: string}}`
    - `{:error, :not_found}`
    - `{:error, reason}`
  """
  @spec exec(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :not_found | term()}
  def exec(sandbox_id, command, opts \\ [])
      when is_binary(sandbox_id) and is_binary(command) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    body = %{
      command: command,
      env: Keyword.get(opts, :env, %{})
    }

    case do_post("/v1/sandboxes/#{sandbox_id}/exec", body, receive_timeout: timeout) do
      {:ok, result} when is_map(result) ->
        {:ok, result}

      {:error, {404, _}} ->
        {:error, :not_found}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Destroys a sandbox, releasing its compute resources.

  ## Returns
    - `:ok`
    - `{:error, :not_found}`
    - `{:error, reason}`
  """
  @spec destroy_sandbox(String.t()) :: :ok | {:error, :not_found | term()}
  def destroy_sandbox(sandbox_id) when is_binary(sandbox_id) do
    case do_delete("/v1/sandboxes/#{sandbox_id}") do
      {:ok, _} ->
        :ok

      {:error, {404, _}} ->
        {:error, :not_found}

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Builds the base Req client from application config.
  # In tests, set `config :canopy, :miosa_req_options, plug: {Req.Test, :name}`
  # to intercept HTTP calls without a real server.  In prod this key is absent
  # so the Finch pool is used normally — no test-only code path in production.
  @spec build_client() :: Req.Request.t()
  defp build_client do
    base_url = Application.get_env(:canopy, :miosa_api_url, "http://localhost:4100")
    api_key = Application.get_env(:canopy, :miosa_api_key, "")
    test_overrides = Application.get_env(:canopy, :miosa_req_options, [])

    base_opts = [
      base_url: base_url,
      finch: Canopy.Finch,
      headers: [{"authorization", "Bearer #{api_key}"}],
      retry: :transient,
      max_retries: @max_retries,
      receive_timeout: @default_timeout_ms
    ]

    Req.new(Keyword.merge(base_opts, test_overrides))
  end

  @spec handle_response({:ok, Req.Response.t()} | {:error, term()}) ::
          {:ok, term()} | {:error, term()}
  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: 404, body: body}}) do
    {:error, {404, body}}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.warning("[Canopy.Miosa.Client] MIOSA API error status=#{status}")
    {:error, {status, body}}
  end

  defp handle_response({:error, reason}) do
    Logger.warning("[Canopy.Miosa.Client] MIOSA transport error: #{inspect(reason)}")
    {:error, reason}
  end

  defp do_get(path) do
    build_client()
    |> Req.get(url: path)
    |> handle_response()
  end

  defp do_post(path, body, extra_opts) do
    build_client()
    |> Req.post([url: path, json: body] ++ extra_opts)
    |> handle_response()
  end

  defp do_delete(path) do
    build_client()
    |> Req.delete(url: path)
    |> handle_response()
  end
end
