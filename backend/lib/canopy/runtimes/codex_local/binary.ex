defmodule Canopy.Runtimes.CodexLocal.Binary do
  @moduledoc """
  Binary resolution and path-safety layer for the Codex Local adapter.

  Handles three concerns:

  1. **Resolution** — resolves the `codex` binary from the execution context
     or from `$PATH` when no explicit path is configured.

  2. **Path-traversal guard** — rejects binary paths that contain `..`
     components, preventing path-traversal attacks in user-supplied config.

  3. **Version check** — runs `codex --version` to confirm the binary is
     executable and returns the version string for health-check reporting.

  All functions are pure (no GenServer state) and may be called from any
  process without side effects beyond the subprocess spawned by `run_version/1`.
  """

  require Logger

  @doc """
  Resolves the `codex` binary path from an execution context map.

  If `context["command"]` is a non-empty string, that value is used directly.
  Otherwise the binary is located via `System.find_executable/1`; if not found
  on `$PATH`, the bare string `"codex"` is returned so the caller receives a
  descriptive `:not_installed` error from `run_version/1`.
  """
  @spec resolve(map()) :: Path.t()
  def resolve(context) do
    configured = Map.get(context, "command", "") |> to_string() |> String.trim()

    if configured == "" do
      find_in_path("codex")
    else
      configured
    end
  end

  @doc """
  Looks up `cmd` on `$PATH` via `System.find_executable/1`.

  Returns the absolute path when found, or `cmd` unchanged when not found.
  """
  @spec find_in_path(String.t()) :: Path.t()
  def find_in_path(cmd) do
    case System.find_executable(cmd) do
      nil -> cmd
      path -> path
    end
  end

  @doc """
  Guards against path-traversal attacks by rejecting paths with `..` components.

  Returns `:ok` when the path is safe, or
  `{:error, {:binary_path_not_allowed, path}}` when a `..` component is found.
  """
  @spec guard_path(Path.t()) :: :ok | {:error, {:binary_path_not_allowed, Path.t()}}
  def guard_path(path) do
    if path_traversal?(path) do
      {:error, {:binary_path_not_allowed, path}}
    else
      :ok
    end
  end

  @doc """
  Returns `true` when `path` contains a `..` component.
  """
  @spec path_traversal?(Path.t()) :: boolean()
  def path_traversal?(path) do
    ".." in Path.split(path)
  end

  @doc """
  Runs `binary --version` and returns the trimmed output.

  Returns `{:ok, version_string}` on success (exit code 0), or
  `{:error, :not_installed}` when the binary is missing, not executable,
  or exits with a non-zero code.
  """
  @spec run_version(Path.t()) :: {:ok, String.t()} | {:error, :not_installed}
  def run_version(binary) do
    case System.cmd(binary, ["--version"], stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.trim(output)}
      {_output, _code} -> {:error, :not_installed}
    end
  rescue
    ErlangError -> {:error, :not_installed}
  end
end
