defmodule Canopy.Adapters.OpenCode do
  @moduledoc """
  OpenCode adapter — spawns the `opencode` terminal AI coding assistant.

  OpenCode is invoked with `--print` and `--output-format stream-json` for
  non-interactive execution. The prompt is delivered via stdin, matching the
  claude_code adapter pattern exactly.

  ## Installation

      npm install -g @opencode/cli
      # or
      brew install opencode

  Verify installation:

      opencode --version

  ## Config keys

  - `"working_dir"` — working directory for opencode to operate in (default: system tmp)
  - `"model"` — model string (e.g. `"claude-4-sonnet"`, `"gpt-4o"`, optional)

  ## Environment variables

  The adapter sets `CANOPY_*` env vars so OpenCode sub-processes can call back to the
  Canopy API. Provider keys are read from the environment (ANTHROPIC_API_KEY, etc.).
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "opencode"

  @impl true
  def name, do: "OpenCode"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :file_edit, :web_search]

  @impl true
  def health do
    case find_opencode() do
      nil -> {:error, "opencode binary not found"}
      _path -> :ok
    end
  end

  @impl true
  def start(config) do
    {:ok,
     %{
       cwd: config["working_dir"] || System.tmp_dir!(),
       model: config["model"] || "claude-4-sonnet",
       session_id: generate_id()
     }}
  end

  @impl true
  def stop(%{port: port}) when is_port(port) do
    Port.close(port)
    :ok
  rescue
    _ -> :ok
  end

  def stop(_), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || params["workspace_path"] || "."
    model = params["model"] || "claude-4-sonnet"

    resume_session_id =
      params["resume_session_id"] || params[:resume_session_id]

    resume_args =
      case resume_session_id do
        nil -> []
        "" -> []
        id -> ["--resume", id]
      end

    opts = %{
      agent_id: Map.get(params, "agent_id", ""),
      run_id: Map.get(params, "run_id", ""),
      workspace_path: cwd
    }

    stream_opencode_command(prompt, cwd, model, opts, resume_args)
  end

  @impl true
  def send_message(%{cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    stream_opencode_command(message, cwd, model, opts, [])
  end

  # -- Private --

  defp find_opencode do
    case System.find_executable("opencode") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "opencode"]),
          "/usr/local/bin/opencode",
          "/opt/homebrew/bin/opencode"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp stream_opencode_command(prompt, cwd, model, opts, resume_args) do
    opencode_bin = find_opencode()

    if is_nil(opencode_bin) do
      not_installed_stream()
    else
      Stream.resource(
        fn ->
          port =
            Port.open(
              {:spawn_executable, opencode_bin},
              [
                :binary,
                :exit_status,
                :stderr_to_stdout,
                args:
                  [
                    "--print",
                    "--output-format",
                    "stream-json",
                    "--model",
                    model
                  ] ++ resume_args,
                cd: to_charlist(cwd),
                env: nesting_guard_env() ++ canopy_env(opts)
              ]
            )

          Port.command(port, prompt <> "\n")
          {port, ""}
        end,
        fn {port, buffer} ->
          receive do
            {^port, {:data, data}} ->
              combined = buffer <> data
              {events, remaining} = parse_stream_json(combined)

              adapter_events =
                Enum.map(events, fn event ->
                  {input, output} = extract_usage(event)

                  %{
                    event_type: map_opencode_event_type(event),
                    data: event,
                    tokens_input: input,
                    tokens_output: output
                  }
                end)

              {adapter_events, {port, remaining}}

            {^port, {:exit_status, _code}} ->
              {:halt, {port, buffer}}
          after
            60_000 ->
              graceful_kill(port)
              {:halt, {port, buffer}}
          end
        end,
        fn {port, _} -> close_port(port) end
      )
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
              "error" => "OpenCode binary not found",
              "adapter" => type(),
              "hint" =>
                "Install OpenCode: npm install -g @opencode/cli  (see https://opencode.ai)"
            },
            tokens_input: 0,
            tokens_output: 0
          }

          {[event], :done}

        :done ->
          {:halt, :done}
      end,
      fn _ -> :ok end
    )
  end

  # Nesting guard: prevent recursive agent spawning when OpenCode is run inside
  # another OpenCode session.
  defp nesting_guard_env do
    [
      {~c"OPENCODE", ~c""},
      {~c"OPENCODE_PARENT_SESSION", ~c""}
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

  defp parse_stream_json(buffer) do
    extract_json_objects(buffer, [], 0, "")
  end

  defp extract_json_objects("", acc, 0, ""), do: {Enum.reverse(acc), ""}
  defp extract_json_objects("", acc, _depth, partial), do: {Enum.reverse(acc), partial}

  defp extract_json_objects(<<char, rest::binary>>, acc, depth, partial) do
    new_partial = partial <> <<char>>

    cond do
      char == ?{ ->
        extract_json_objects(rest, acc, depth + 1, new_partial)

      char == ?} and depth == 1 ->
        case Jason.decode(new_partial) do
          {:ok, event} -> extract_json_objects(rest, [event | acc], 0, "")
          _ -> extract_json_objects(rest, acc, 0, "")
        end

      char == ?} ->
        extract_json_objects(rest, acc, depth - 1, new_partial)

      depth > 0 ->
        extract_json_objects(rest, acc, depth, new_partial)

      true ->
        extract_json_objects(rest, acc, depth, "")
    end
  end

  defp extract_usage(%{"usage" => usage}) when is_map(usage) do
    input =
      (usage["input_tokens"] || 0) + (usage["cache_read_input_tokens"] || 0) +
        (usage["cache_creation_input_tokens"] || 0)

    output = usage["output_tokens"] || 0
    {input, output}
  end

  defp extract_usage(_event), do: {0, 0}

  defp map_opencode_event_type(%{"type" => "system"}), do: "run.init"
  defp map_opencode_event_type(%{"type" => "assistant"}), do: "run.output"
  defp map_opencode_event_type(%{"type" => "tool_use"}), do: "run.tool_call"
  defp map_opencode_event_type(%{"type" => "tool_result"}), do: "run.tool_result"
  defp map_opencode_event_type(%{"type" => "thinking"}), do: "run.thinking"
  defp map_opencode_event_type(%{"type" => "error"}), do: "run.failed"
  defp map_opencode_event_type(%{"type" => "result"}), do: "run.completed"
  defp map_opencode_event_type(_), do: "run.output"

  defp graceful_kill(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} ->
        System.cmd("kill", ["-TERM", Integer.to_string(os_pid)], stderr_to_stdout: true)
        Process.sleep(5_000)
        System.cmd("kill", ["-KILL", Integer.to_string(os_pid)], stderr_to_stdout: true)

      _ ->
        :ok
    end

    close_port(port)
  end

  defp close_port(port) do
    try do
      Port.close(port)
    rescue
      _ -> :ok
    end
  end

  defp generate_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
end
