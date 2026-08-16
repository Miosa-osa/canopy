defmodule Canopy.Workspaces.Engine do
  @moduledoc """
  Workspace-scoped OptimalEngine execution.

  A workspace may contain:

    * `engine/` — its local Elixir engine project
    * `.canopy/engine.yaml` — the allowlist of runnable `optimal.*` Mix tasks

  This module never runs arbitrary shell. It resolves the workspace, checks the
  engine directory, loads the manifest, and executes `mix <task> <args>` without
  invoking a shell.
  """

  alias Canopy.Workspaces
  alias Canopy.Workspaces.Engine.Manifest
  alias Canopy.Workspaces.Workspace

  require Logger

  @default_timeout_ms 60_000
  @max_timeout_ms 300_000
  @max_output_bytes 256 * 1024
  @max_arg_bytes 4 * 1024

  @type command_result :: %{
          workspace_slug: String.t(),
          command: String.t(),
          task: String.t(),
          args: [String.t()],
          cwd: String.t(),
          stdout: String.t(),
          stderr: String.t(),
          exit_code: integer(),
          duration_ms: non_neg_integer()
        }

  @spec health(String.t()) :: {:ok, map()} | {:error, :not_found}
  def health(workspace_slug) do
    with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug) do
      engine_path = engine_dir(workspace)
      manifest_path = Manifest.manifest_path(workspace.root_path)
      commands = load_commands_for_health(workspace.root_path)

      engine_exists = File.dir?(engine_path)
      mix_project = File.exists?(Path.join(engine_path, "mix.exs"))
      manifest_exists = File.exists?(manifest_path)

      {:ok,
       %{
         workspace_slug: workspace.slug,
         root_path: workspace.root_path,
         engine_path: engine_path,
         engine_exists: engine_exists,
         mix_project: mix_project,
         manifest_path: manifest_path,
         manifest_exists: manifest_exists,
         commands_count: length(commands),
         available: engine_exists and mix_project and manifest_exists
       }}
    end
  end

  @spec list_commands(String.t()) :: {:ok, [Manifest.command()]} | {:error, term()}
  def list_commands(workspace_slug) do
    with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug),
         :ok <- ensure_engine_ready(workspace),
         {:ok, commands} <- Manifest.load(workspace.root_path) do
      {:ok, commands}
    end
  end

  @spec run(String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, command_result()} | {:error, term()}
  def run(workspace_slug, command, args \\ [], opts \\ [])

  def run(workspace_slug, command, args, opts)
      when is_binary(workspace_slug) and is_binary(command) and is_list(args) do
    with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug),
         :ok <- ensure_engine_ready(workspace),
         {:ok, commands} <- Manifest.load(workspace.root_path),
         {:ok, manifest_command} <- find_command(commands, command),
         {:ok, runtime_args} <- normalize_args(args),
         {:ok, timeout_ms} <- normalize_timeout(Keyword.get(opts, :timeout_ms)) do
      execute(workspace, manifest_command, runtime_args, timeout_ms)
    end
  end

  def run(workspace_slug, command, _args, _opts)
      when is_binary(workspace_slug) and is_binary(command),
      do: {:error, :invalid_arg}

  defp execute(%Workspace{} = workspace, manifest_command, runtime_args, timeout_ms) do
    started = System.monotonic_time(:millisecond)
    cwd = engine_dir(workspace)
    mix = Application.get_env(:canopy, :engine_mix_executable, "mix")
    args = [manifest_command.task] ++ manifest_command.args ++ runtime_args

    Logger.info(
      "[WorkspaceEngine] workspace=#{workspace.slug} command=#{manifest_command.name} task=#{manifest_command.task}"
    )

    try do
      {stdout, exit_code} = run_executable(mix, args, cwd, timeout_ms)

      {:ok,
       %{
         workspace_slug: workspace.slug,
         command: manifest_command.name,
         task: manifest_command.task,
         args: args,
         cwd: cwd,
         stdout: truncate(stdout),
         stderr: "",
         exit_code: exit_code,
         duration_ms: System.monotonic_time(:millisecond) - started
       }}
    rescue
      error -> {:error, {:execution_failed, Exception.message(error)}}
    catch
      :exit, reason -> {:error, {:execution_failed, reason}}
    end
  end

  defp ensure_engine_ready(%Workspace{} = workspace) do
    dir = engine_dir(workspace)

    cond do
      not File.dir?(dir) -> {:error, :engine_not_found}
      not File.exists?(Path.join(dir, "mix.exs")) -> {:error, :mix_project_not_found}
      true -> :ok
    end
  end

  defp engine_dir(%Workspace{root_path: root_path}), do: Path.join(root_path, "engine")

  defp load_commands_for_health(root_path) do
    case Manifest.load(root_path) do
      {:ok, commands} -> commands
      {:error, _} -> []
    end
  end

  defp find_command(commands, command) do
    case Enum.find(commands, &(&1.name == command)) do
      nil -> {:error, :command_not_allowed}
      found -> {:ok, found}
    end
  end

  defp normalize_args(args) do
    args = Enum.map(args, &to_string/1)

    cond do
      Enum.any?(args, &String.contains?(&1, <<0>>)) -> {:error, :invalid_arg}
      Enum.any?(args, &(byte_size(&1) > @max_arg_bytes)) -> {:error, :arg_too_large}
      true -> {:ok, args}
    end
  end

  defp normalize_timeout(nil), do: {:ok, @default_timeout_ms}

  defp normalize_timeout(timeout_ms) when is_integer(timeout_ms) do
    cond do
      timeout_ms <= 0 -> {:error, :invalid_timeout}
      timeout_ms > @max_timeout_ms -> {:error, :timeout_too_large}
      true -> {:ok, timeout_ms}
    end
  end

  defp normalize_timeout(timeout_ms) when is_binary(timeout_ms) do
    case Integer.parse(timeout_ms) do
      {int, ""} -> normalize_timeout(int)
      _ -> {:error, :invalid_timeout}
    end
  end

  defp normalize_timeout(_), do: {:error, :invalid_timeout}

  defp run_executable(executable, args, cwd, timeout_ms) do
    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        {:args, args},
        {:cd, cwd}
      ])

    collect_port(port, "", timeout_ms)
  end

  defp collect_port(port, stdout, timeout_ms) do
    receive do
      {^port, {:data, data}} ->
        collect_port(port, stdout <> data, timeout_ms)

      {^port, {:exit_status, exit_code}} ->
        {stdout, exit_code}
    after
      timeout_ms ->
        Port.close(port)
        raise "engine command timed out after #{timeout_ms}ms"
    end
  end

  defp truncate(text) when byte_size(text) <= @max_output_bytes, do: text
  defp truncate(text), do: binary_part(text, 0, @max_output_bytes) <> "\n...[truncated]"
end
