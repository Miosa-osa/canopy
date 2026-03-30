defmodule Canopy.Adapters.ClaudeCode do
  @moduledoc """
  Claude Code adapter — spawns the `claude` CLI process with --print flag
  for non-interactive execution, or --output-format stream-json for streaming.
  """
  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "claude-code"

  @impl true
  def name, do: "Claude Code"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :file_edit, :web_search]

  @impl true
  def health do
    path = Canopy.ClaudeBinary.find()

    if File.exists?(path) do
      :ok
    else
      {:error, "claude binary not found (checked: #{path})"}
    end
  end

  @impl true
  def start(config) do
    cwd = config["working_dir"] || config["workspace_path"] || System.tmp_dir!()
    model = config["model"] || "sonnet"

    {:ok,
     %{
       cwd: cwd,
       model: model,
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
    context = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || params["workspace_path"] || "."
    model = params["model"] || "sonnet"

    resume_session_id =
      params["resume_session_id"] || params[:resume_session_id]

    resume_args =
      case resume_session_id do
        nil -> []
        "" -> []
        id -> ["--resume", id]
      end

    stream_claude_command(context, cwd, model, %{workspace_path: cwd}, resume_args)
  end

  @impl true
  def send_message(%{cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    stream_claude_command(message, cwd, model, opts, [])
  end

  defp stream_claude_command(prompt, cwd, model, opts, resume_args) do
    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, Canopy.ClaudeBinary.find()},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args:
                [
                  "--print",
                  "--verbose",
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
                  event_type: map_claude_event_type(event),
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
            case Port.info(port, :os_pid) do
              {:os_pid, os_pid} ->
                System.cmd("kill", ["-TERM", Integer.to_string(os_pid)],
                  stderr_to_stdout: true
                )

                Process.sleep(5_000)

                System.cmd("kill", ["-KILL", Integer.to_string(os_pid)],
                  stderr_to_stdout: true
                )

              _ ->
                :ok
            end

            try do
              Port.close(port)
            rescue
              _ -> :ok
            end

            {:halt, {port, buffer}}
        end
      end,
      fn {port, _} ->
        try do
          Port.close(port)
        rescue
          _ -> :ok
        end
      end
    )
  end

  defp nesting_guard_env do
    [
      {~c"CLAUDECODE", ~c""},
      {~c"CLAUDE_CODE_ENTRYPOINT", ~c""},
      {~c"CLAUDE_CODE_SESSION", ~c""},
      {~c"CLAUDE_CODE_PARENT_SESSION", ~c""}
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
    {events, remaining} = extract_json_objects(buffer, [], 0, "")
    {events, remaining}
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
        # Outside any JSON object, skip whitespace/newlines
        extract_json_objects(rest, acc, depth, "")
    end
  end

  # Extract token usage from Claude stream-json events.
  # The "result" event contains the final summary with all token counts.
  # Intermediate events may have partial usage in their "usage" field.
  defp extract_usage(%{"usage" => usage}) when is_map(usage) do
    input =
      (usage["input_tokens"] || 0) + (usage["cache_read_input_tokens"] || 0) +
        (usage["cache_creation_input_tokens"] || 0)

    output = usage["output_tokens"] || 0
    {input, output}
  end

  defp extract_usage(_event), do: {0, 0}

  defp map_claude_event_type(%{"type" => "assistant"}), do: "run.output"
  defp map_claude_event_type(%{"type" => "tool_use"}), do: "run.tool_call"
  defp map_claude_event_type(%{"type" => "tool_result"}), do: "run.tool_result"
  defp map_claude_event_type(%{"type" => "thinking"}), do: "run.thinking"
  defp map_claude_event_type(%{"type" => "error"}), do: "run.failed"
  defp map_claude_event_type(%{"type" => "result"}), do: "run.completed"
  defp map_claude_event_type(_), do: "run.output"

  defp generate_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
end
