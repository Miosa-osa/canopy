defmodule Canopy.Adapters.Process do
  @moduledoc """
  Generic subprocess adapter — spawns any binary as an agent.

  This is the escape hatch: run literally anything that accepts stdin and
  produces stdout. Useful for custom scripts, local models, or any tool not
  covered by a dedicated adapter.

  ## Config keys

  - `"command"` — path to the binary to execute (required)
  - `"args"` — list of CLI arguments (default: `[]`)
  - `"working_dir"` — working directory for the subprocess (default: system tmp)
  - `"env"` — map of extra environment variables to set (default: `%{}`)

  ## Example config

      %{
        "command" => "/usr/local/bin/my-agent",
        "args" => ["--mode", "headless"],
        "working_dir" => "/workspace/project",
        "env" => %{"MY_API_KEY" => "abc123"}
      }

  ## Behaviour

  - Prompt is delivered to stdin followed by a newline.
  - stdout/stderr are both captured and emitted as `run.output` events.
  - Exit code 0 → `run.completed`. Non-zero → `run.failed`.
  - Timeout after 5 minutes of inactivity.

  If `"command"` is missing or the binary does not exist, `start/1` returns
  `{:error, :command_required}` or `{:error, :command_not_found}` respectively.
  """

  @behaviour Canopy.Adapter

  require Logger

  @timeout_ms 300_000

  @impl true
  def type, do: "process"

  @impl true
  def name, do: "Process"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write]

  @impl true
  def health, do: :ok

  @impl true
  def start(config) do
    case validate_command(config) do
      {:ok, command} ->
        {:ok,
         %{
           command: command,
           args: config["args"] || [],
           cwd: config["working_dir"] || System.tmp_dir!(),
           env: config["env"] || %{}
         }}

      error ->
        error
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || ""

    case validate_command(params) do
      {:ok, command} ->
        args = params["args"] || []
        cwd = params["working_dir"] || "."
        env = params["env"] || %{}
        spawn_process_stream(command, args, cwd, env, prompt)

      {:error, :command_required} ->
        error_stream("Process adapter requires 'command' in config")

      {:error, :command_not_found} ->
        error_stream("Command not found: #{params["command"]}")
    end
  end

  @impl true
  def send_message(%{command: command, args: args, cwd: cwd, env: env}, message) do
    spawn_process_stream(command, args, cwd, env, message)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp validate_command(%{"command" => nil}), do: {:error, :command_required}
  defp validate_command(%{"command" => ""}), do: {:error, :command_required}

  defp validate_command(%{"command" => command}) do
    resolved =
      if Path.type(command) == :absolute do
        if File.exists?(command), do: command, else: nil
      else
        System.find_executable(command)
      end

    case resolved do
      nil -> {:error, :command_not_found}
      path -> {:ok, path}
    end
  end

  defp validate_command(_), do: {:error, :command_required}

  defp build_port_env(env_map) when map_size(env_map) == 0, do: []

  defp build_port_env(env_map) do
    Enum.map(env_map, fn {k, v} ->
      {to_charlist(k), to_charlist(to_string(v))}
    end)
  end

  defp spawn_process_stream(command, args, cwd, env, prompt) do
    port_env = build_port_env(env)

    Stream.resource(
      fn ->
        port_opts =
          [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: args,
            cd: to_charlist(cwd)
          ]
          |> maybe_add_env(port_env)

        port = Port.open({:spawn_executable, command}, port_opts)

        if prompt != "" do
          Port.command(port, prompt <> "\n")
        end

        {port, ""}
      end,
      fn
        {:done, _} ->
          {:halt, :done}

        {port, buf} ->
          receive do
            {^port, {:data, data}} ->
              {[%{event_type: "run.output", data: %{"text" => data}, tokens: 0}],
               {port, buf <> data}}

            {^port, {:exit_status, 0}} ->
              {[%{event_type: "run.completed", data: %{"output" => buf}, tokens: 0}],
               {:done, port}}

            {^port, {:exit_status, code}} ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"exit_code" => code, "output" => buf},
                   tokens: 0
                 }
               ], {:done, port}}
          after
            @timeout_ms ->
              Logger.warning("[Canopy.Adapters.Process] timeout waiting for #{command}")
              {:halt, {port, buf}}
          end
      end,
      fn
        :done -> :ok
        {:done, port} -> close_port(port)
        {port, _buf} -> close_port(port)
      end
    )
  end

  defp maybe_add_env(opts, []), do: opts
  defp maybe_add_env(opts, env), do: opts ++ [env: env]

  defp error_stream(message) do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{"error" => message, "adapter" => type()},
            tokens: 0
          }

          {[event], :done}

        :done ->
          {:halt, :done}
      end,
      fn _ -> :ok end
    )
  end

  defp close_port(port) do
    try do
      Port.close(port)
    rescue
      _ -> :ok
    end
  end
end
