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

    stream_claude_command(context, cwd, model)
  end

  @impl true
  def send_message(%{cwd: cwd, model: model}, message) do
    stream_claude_command(message, cwd, model)
  end

  defp stream_claude_command(prompt, cwd, model) do
    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, find_claude_binary()},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: [
                "--print",
                "--verbose",
                "--output-format",
                "stream-json",
                "--model",
                model,
                prompt
              ],
              cd: to_charlist(cwd)
            ]
          )

        {port, ""}
      end,
      fn {port, buffer} ->
        receive do
          {^port, {:data, data}} ->
            combined = buffer <> data
            {events, remaining} = parse_stream_json(combined)

            adapter_events =
              Enum.map(events, fn event ->
                %{
                  event_type: map_claude_event_type(event),
                  data: event,
                  tokens: get_in(event, ["usage", "input_tokens"]) || 0
                }
              end)

            {adapter_events, {port, remaining}}

          {^port, {:exit_status, _code}} ->
            {:halt, {port, buffer}}
        after
          60_000 ->
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

  defp find_claude_binary do
    # Try multiple known paths since Erlang's PATH may differ from shell
    case System.find_executable("claude") do
      nil ->
        home = System.get_env("HOME") || "/Users/symac"

        known_paths = [
          Path.join([home, ".superset", "bin", "claude"]),
          Path.join([home, ".nvm", "versions", "node", "current", "bin", "claude"]),
          Path.join([home, ".local", "bin", "claude"]),
          "/usr/local/bin/claude",
          "/opt/homebrew/bin/claude"
        ]

        Enum.find(known_paths, "/usr/local/bin/claude", &File.exists?/1)

      path ->
        path
    end
  end

  defp parse_stream_json(buffer) do
    lines = String.split(buffer, "\n")
    {complete, [last]} = Enum.split(lines, -1)

    events =
      complete
      |> Enum.reject(&(&1 == ""))
      |> Enum.flat_map(fn line ->
        case Jason.decode(line) do
          {:ok, event} -> [event]
          _ -> []
        end
      end)

    {events, last}
  end

  defp map_claude_event_type(%{"type" => "assistant"}), do: "run.output"
  defp map_claude_event_type(%{"type" => "tool_use"}), do: "run.tool_call"
  defp map_claude_event_type(%{"type" => "tool_result"}), do: "run.tool_result"
  defp map_claude_event_type(%{"type" => "thinking"}), do: "run.thinking"
  defp map_claude_event_type(%{"type" => "error"}), do: "run.failed"
  defp map_claude_event_type(%{"type" => "result"}), do: "run.completed"
  defp map_claude_event_type(_), do: "run.output"

  defp generate_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
end
