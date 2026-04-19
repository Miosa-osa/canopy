defmodule Canopy.Miosa.ClientBehaviour do
  @moduledoc """
  Behaviour that `Canopy.Miosa.Client` implements.

  Extracted so tests can mock the HTTP client with Mox without making real
  network calls.  In production the default implementation is the real client.
  Override via `config :canopy, :miosa_client, MyModule` in test config.
  """

  @type sandbox_result :: %{
          sandbox_id: String.t(),
          url: String.t(),
          status: String.t()
        }

  @callback ping(opts :: keyword()) ::
              {:ok, non_neg_integer()} | {:error, term()}

  @callback provision_sandbox(opts :: keyword()) ::
              {:ok, sandbox_result()} | {:error, term()}

  @callback get_sandbox(sandbox_id :: String.t()) ::
              {:ok, sandbox_result()} | {:error, :not_found | term()}

  @callback exec(sandbox_id :: String.t(), command :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, :not_found | term()}

  @callback destroy_sandbox(sandbox_id :: String.t()) ::
              :ok | {:error, :not_found | term()}
end
