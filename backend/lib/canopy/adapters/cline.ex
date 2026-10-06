defmodule Canopy.Adapters.Cline do
  @moduledoc """
  Cline adapter — spawns the `cline` CLI in `--print --output-format json` mode
  for non-interactive, single-shot execution with structured JSON output.

  Cline is an open-source AI coding agent for VS Code with a standalone CLI.

  ## Installation

      npm install -g cline
      # or via Homebrew:
      brew install cline

  Verify installation:

      cline --version

  ## Config keys

  - `"working_dir"` — working directory for execution (default: system tmp)
  - `"model"` — model string passed to cline (optional)

  If the `cline` binary is not found, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "cline"

  @impl true
  def name, do: "Cline"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write, :tools]

  @impl true
  def health do
    if find_cline(), do: :ok, else: {:error, "cline binary not found in PATH"}
  end

  @impl true
  def start(config) do
    case find_cline() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           cline_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"]
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || params["workspace_path"] || "."
    model = params["model"]
    opts = %{workspace_path: cwd}

    case find_cline() do
      nil -> not_installed_stream()
      cline_bin -> spawn_cline_stream(cline_bin, prompt, cwd, model, opts)
    end
  end

  @impl true
  def send_message(%{cline_bin: cline_bin, cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    spawn_cline_stream(cline_bin, message, cwd, model, opts)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_cline do
    case System.find_executable("cline") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "cline"]),
          "/usr/local/bin/cline",
          "/opt/homebrew/bin/cline"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(prompt, model) do
    base = ["--print", "--output-format", "json", prompt]
    if model, do: ["--model", model] ++ base, else: base
  end

  defp spawn_cline_stream(cline_bin, prompt, cwd, model, opts) do
    args = build_args(prompt, model)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, cline_bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: args,
              cd: to_charlist(cwd),
              env: nesting_guard_env() ++ canopy_env(opts)
            ]
          )

        {port, ""}
      end,
      fn
        {:done, _} ->
          {:halt, :done}

        {port, buf} ->
          receive do
            {^port, {:data, data}} ->
              combined = buf <> data
              {events, remaining} = parse_json_lines(combined)

              adapter_events =
                Enum.map(events, fn event ->
                  %{event_type: map_event_type(event), data: event, tokens: 0}
                end)

              {adapter_events, {port, remaining}}

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
            120_000 ->
              graceful_kill(port)
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

  # Parse newline-delimited JSON objects from a buffer.
  # Returns {[decoded_maps], remaining_partial_line}.
  defp parse_json_lines(buffer) do
    lines = String.split(buffer, "\n")
    {complete, [partial]} = Enum.split(lines, length(lines) - 1)

    events =
      complete
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.flat_map(fn line ->
        case Jason.decode(line) do
          {:ok, event} -> [event]
          _ -> [%{"type" => "text", "text" => line}]
        end
      end)

    {events, partial}
  end

  defp map_event_type(%{"type" => "result"}), do: "run.completed"
  defp map_event_type(%{"type" => "error"}), do: "run.failed"
  defp map_event_type(_), do: "run.output"

  defp graceful_kill(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} ->
        System.cmd("kill", ["-TERM", Integer.to_string(os_pid)], stderr_to_stdout: true)
        Process.sleep(5_000)
        System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)

      _ ->
        :ok
    end
  end

  defp not_installed_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "Cline binary not found",
              "adapter" => type(),
              "hint" => "Install Cline: npm install -g cline  (see https://github.com/cline/cline)"
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

  defp nesting_guard_env do
    [
      {~c"CLINE", ~c""},
      {~c"CLINE_SESSION", ~c""},
      {~c"CLINE_PARENT_SESSION", ~c""}
    ]
  end

  defp canopy_env(opts) do
    [
      {~c"CANOPY_AGENT_ID", to_charlist(Map.get(opts, :agent_id, ""))},
      {~c"CANOPY_RUN_ID", to_charlist(Map.get(opts, :run_id, ""))},
      {~c"CANOPY_WORKSPACE_PATH", to_charlist(Map.get(opts, :workspace_path, ""))},
      {~c"CANOPY_API_URL",
       to_charlist(
         Application.get_env(:canopy, :api_url, "http://localhost:4000") |> to_string()
       )},
      {~c"CANOPY_API_KEY",
       to_charlist(Application.get_env(:canopy, :api_key, "") |> to_string())}
    ]
  end

  defp close_port(port) do
    try do
      Port.close(port)
    rescue
      _ -> :ok
    end
  end
end
