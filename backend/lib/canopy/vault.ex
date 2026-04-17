defmodule Canopy.Vault do
  @moduledoc """
  Public API for credential vault operations.

  Canopy stores secret values (API keys, tokens) in the OS keychain via the
  Tauri `tauri-plugin-keyring` integration on the frontend. The backend only
  persists credential *references* — identifiers and metadata — never the
  plaintext secret values themselves.

  This design ensures secrets never traverse the network or touch the database.
  The frontend reads credentials directly from macOS Keychain/Windows Credential
  Store/Linux Secret Service and injects them into adapter configs at runtime.

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 2 scope (references stored in Postgres; values stay in Keychain).
  """

  @doc "Retrieves a credential reference for the given runtime and key."
  @spec get_credential(String.t(), String.t()) ::
          {:ok, map()} | {:error, :not_found | :not_implemented}
  def get_credential(_runtime_type, _key) do
    {:error, :not_implemented}
  end

  @doc "Persists a credential reference (not the value) for the given runtime and key."
  @spec put_credential(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, :not_implemented}
  def put_credential(_runtime_type, _key, _metadata) do
    {:error, :not_implemented}
  end

  @doc "Removes a credential reference for the given runtime and key."
  @spec delete_credential(String.t(), String.t()) ::
          {:ok, map()} | {:error, :not_found | :not_implemented}
  def delete_credential(_runtime_type, _key) do
    {:error, :not_implemented}
  end
end
