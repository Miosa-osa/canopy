defmodule Canopy.Miosa do
  @moduledoc """
  Public API for MIOSA compute sandbox operations.

  MIOSA provisions ephemeral VMs (Firecracker-based) on demand. Canopy uses these
  sandboxes to give agent sessions an isolated compute environment. The agent process
  runs inside the sandbox; Canopy injects the sandbox URL as an environment variable.

  Sandbox lifecycle per session:
  1. `provision_sandbox/1` — request a new VM for the session
  2. Agent runs inside the VM (PTY via Tauri sidecar or direct SSH)
  3. `exec/3` — run discrete commands if needed outside the PTY session
  4. `destroy/1` — terminate the VM when the session completes or is cancelled

  All functions currently return `{:error, :not_implemented}`. Full implementation
  is Week 2 scope.
  """

  @doc "Provisions a new MIOSA sandbox for the given session context."
  @spec provision_sandbox(map()) :: {:ok, map()} | {:error, :not_implemented}
  def provision_sandbox(_session_context) do
    {:error, :not_implemented}
  end

  @doc "Executes a command inside a running sandbox."
  @spec exec(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, :not_found | :not_implemented}
  def exec(_sandbox_id, _command, _opts \\ []) do
    {:error, :not_implemented}
  end

  @doc "Destroys a sandbox and releases its compute resources."
  @spec destroy(String.t()) :: {:ok, map()} | {:error, :not_found | :not_implemented}
  def destroy(_sandbox_id) do
    {:error, :not_implemented}
  end
end
