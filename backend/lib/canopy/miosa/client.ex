defmodule Canopy.Miosa.Client do
  @moduledoc """
  HTTP client for the MIOSA compute API.

  Wraps `Req` with base URL and auth header configuration sourced from the
  application environment (set in `runtime.exs` for production, `dev.exs` for
  development). The client uses the `Canopy.Finch` connection pool.

  Week 2 additions:
  - `provision_sandbox/1` — create a MIOSA sandbox for a session
  - `exec/3` — run a command inside a sandbox
  - `destroy/1` — terminate and clean up a sandbox
  - Response type parsing into typed structs
  """

  @doc "Returns a pre-configured Req client for MIOSA API calls."
  @spec client() :: Req.Request.t()
  def client do
    base_url = Application.fetch_env!(:canopy, :miosa_api_url)
    api_key = Application.fetch_env!(:canopy, :miosa_api_key)

    Req.new(
      base_url: base_url,
      finch: Canopy.Finch,
      headers: [{"authorization", "Bearer #{api_key}"}],
      retry: :transient,
      max_retries: 3
    )
  end

  @doc "Sends a GET request to the given MIOSA API path."
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(path, opts \\ []) do
    case Req.get(client(), [url: path] ++ opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Sends a POST request to the given MIOSA API path with a JSON body."
  @spec post(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(path, body, opts \\ []) do
    case Req.post(client(), [url: path, json: body] ++ opts) do
      {:ok, %{status: status, body: response}} when status in 200..299 -> {:ok, response}
      {:ok, %{status: status, body: response}} -> {:error, {status, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Sends a DELETE request to the given MIOSA API path."
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(path, opts \\ []) do
    case Req.delete(client(), [url: path] ++ opts) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {status, body}}
      {:error, reason} -> {:error, reason}
    end
  end
end
