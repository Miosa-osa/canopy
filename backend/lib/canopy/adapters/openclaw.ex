defmodule Canopy.Adapters.OpenClaw do
  @moduledoc """
  OpenClaw adapter — spawns the `openclaw` CLI agent framework.

  OpenClaw is a CLI-driven agent framework. This adapter spawns `openclaw run`
  with the task context piped via stdin and streams stdout/stderr back as events.

  ## Installation

      npm install -g openclaw
      # or
      pip install openclaw

  Verify installation:

      openclaw --version

  ## Config keys

  - `"working_dir"` — working directory for the openclaw process (default: system tmp)
  - `"openclaw_args"` — list of extra args to pass to `openclaw run` (optional)

  If the `openclaw` binary is not found in PATH or known install locations,
  `start/1` returns `{:error, :adapter_not_installed}` and streams emit
  a `run.failed` event with installation instructions.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "openclaw"

  @impl true
  def name, do: "OpenClaw"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: false

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :shell_execution, :web_search]

  @impl true
  def health do
    if find_openclaw(), do: :ok, else: {:error, "openclaw binary not found"}
  end

  @impl true
  def start(config) do
    case find_openclaw() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           openclaw_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           extra_args: config["openclaw_args"] || []
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || "."
    extra_args = params["openclaw_args"] || []

    case find_openclaw() do
      nil ->
        not_installed_stream()

      openclaw_bin ->
        spawn_openclaw_stream(openclaw_bin, prompt, cwd, extra_args)
    end
  end

  @impl true
  def send_message(%{openclaw_bin: openclaw_bin, cwd: cwd, extra_args: extra_args}, message) do
    spawn_openclaw_stream(openclaw_bin, message, cwd, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_openclaw do
    case System.find_executable("openclaw") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "openclaw"]),
          Path.join([home, ".npm", "bin", "openclaw"]),
          "/usr/local/bin/openclaw",
          "/opt/homebrew/bin/openclaw"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp spawn_openclaw_stream(openclaw_bin, prompt, cwd, extra_args) do
    args = ["run"] ++ extra_args

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, openclaw_bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: args,
              cd: to_charlist(cwd)
            ]
          )

        # Pipe the task prompt to stdin, then close stdin to signal EOF
        Port.command(port, prompt <> "\n")
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
              {[%{event_type: "run.completed", data: %{"output" => buf}, tokens: 0}], {:done, port}}

            {^port, {:exit_status, code}} ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"exit_code" => code, "output" => buf},
                   tokens: 0
                 }
               ], {:done, port}}
          after
            120_000 ->
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

  defp not_installed_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "OpenClaw CLI not found",
              "adapter" => type(),
              "hint" => "Install OpenClaw: npm install -g openclaw  (or: pip install openclaw)"
            },
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
