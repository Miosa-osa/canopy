defmodule Canopy.Adapters.Hermes do
  @moduledoc """
  Hermes adapter — spawns the `hermes` CLI (NousResearch's open-source agent framework).

  Hermes is invoked with `hermes chat -q <prompt> -Q --yolo --source tool` for
  non-interactive, non-TTY execution. The `-Q` (quiet) flag produces clean output:
  just the response text followed by a `session_id: <id>` line.

  ## Installation

      cargo install hermes-cli
      # or download from https://github.com/nousresearch/hermes

  Verify installation:

      hermes --version

  ## Config keys

  - `"working_dir"` — working directory for hermes to operate in (default: system tmp)
  - `"model"` — model string (e.g. `"anthropic/claude-sonnet-4"`, optional)
  - `"provider"` — inference provider (e.g. `"anthropic"`, `"openrouter"`, optional)
  - `"toolsets"` — comma-separated toolsets to enable (optional)

  ## Environment variables

  The adapter sets `CANOPY_*` env vars so Hermes sub-processes can call back to the
  Canopy API. Hermes reads provider keys from the environment (ANTHROPIC_API_KEY, etc.).
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "hermes"

  @impl true
  def name, do: "Hermes"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :file_edit, :web_search]

  @impl true
  def health do
    case find_hermes() do
      nil -> {:error, "hermes binary not found"}
      _path -> :ok
    end
  end

  @impl true
  def start(config) do
    {:ok,
     %{
       cwd: config["working_dir"] || System.tmp_dir!(),
       model: config["model"],
       provider: config["provider"],
       toolsets: config["toolsets"],
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
    model = params["model"]
    provider = params["provider"]
    toolsets = params["toolsets"]

    resume_session_id =
      params["resume_session_id"] || params[:resume_session_id]

    opts = %{
      agent_id: Map.get(params, "agent_id", ""),
      run_id: Map.get(params, "run_id", ""),
      workspace_path: cwd
    }

    stream_hermes_command(prompt, cwd, model, provider, toolsets, opts, resume_session_id)
  end

  @impl true
  def send_message(%{cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    provider = Map.get(state, :provider)
    toolsets = Map.get(state, :toolsets)

    stream_hermes_command(message, cwd, model, provider, toolsets, opts, nil)
  end

  # -- Private --

  defp find_hermes do
    case System.find_executable("hermes") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".cargo", "bin", "hermes"]),
          Path.join([home, ".local", "bin", "hermes"]),
          "/usr/local/bin/hermes",
          "/opt/homebrew/bin/hermes"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model, provider, toolsets, resume_session_id) do
    base = [
      "chat",
      "-Q",
      "--yolo",
      "--source",
      "tool"
    ]

    model_args = if model, do: ["-m", model], else: []

    provider_args =
      if provider && provider != "auto", do: ["--provider", provider], else: []

    toolset_args = if toolsets, do: ["-t", toolsets], else: []

    resume_args =
      case resume_session_id do
        nil -> []
        "" -> []
        id -> ["-r", id]
      end

    base ++ model_args ++ provider_args ++ toolset_args ++ resume_args
  end

  defp stream_hermes_command(prompt, cwd, model, provider, toolsets, opts, resume_session_id) do
    hermes_bin = find_hermes()

    if is_nil(hermes_bin) do
      not_installed_stream()
    else
      args = build_args(model, provider, toolsets, resume_session_id)

      Stream.resource(
        fn ->
          port =
            Port.open(
              {:spawn_executable, hermes_bin},
              [
                :binary,
                :exit_status,
                :stderr_to_stdout,
                args: args,
                cd: to_charlist(cwd),
                env: canopy_env(opts)
              ]
            )

          # Hermes reads the query from the -q flag, but we pass prompt via stdin
          # for the same delivery pattern as claude_code. The -q flag is not set;
          # Hermes in quiet mode reads from stdin when -q is omitted.
          Port.command(port, prompt <> "\n")
          {port, ""}
        end,
        fn {port, buffer} ->
          receive do
            {^port, {:data, data}} ->
              combined = buffer <> data
              lines = String.split(combined, "\n")

              {complete, [remaining]} = Enum.split(lines, length(lines) - 1)

              events =
                complete
                |> Enum.reject(&(String.trim(&1) == ""))
                |> Enum.map(&map_hermes_line/1)

              {events, {port, remaining}}

            {^port, {:exit_status, 0}} ->
              final_events =
                if String.trim(buffer) != "" do
                  [map_hermes_line(buffer)]
                else
                  []
                end

              {final_events ++ [%{event_type: "run.completed", data: %{}, tokens_input: 0, tokens_output: 0}],
               {port, ""}}

            {^port, {:exit_status, code}} ->
              {[
                 %{
                   event_type: "run.failed",
                   data: %{"exit_code" => code, "output" => buffer},
                   tokens_input: 0,
                   tokens_output: 0
                 }
               ], {:halt_port, port}}
          after
            60_000 ->
              graceful_kill(port)
              {:halt, {port, buffer}}
          end
        end,
        fn
          {:halt_port, port} -> close_port(port)
          {port, _} -> close_port(port)
        end
      )
    end
  end

  # Map a raw Hermes output line to a Canopy event.
  # Hermes quiet-mode output: response text, then "session_id: <id>" at the end.
  defp map_hermes_line(line) do
    trimmed = String.trim(line)

    cond do
      String.starts_with?(trimmed, "session_id:") ->
        session_id =
          trimmed
          |> String.replace_prefix("session_id:", "")
          |> String.trim()

        %{
          event_type: "run.completed",
          data: %{"session_id" => session_id},
          tokens_input: 0,
          tokens_output: 0
        }

      String.starts_with?(trimmed, "[hermes]") or String.starts_with?(trimmed, "[tool]") ->
        %{
          event_type: "run.tool_result",
          data: %{"text" => trimmed},
          tokens_input: 0,
          tokens_output: 0
        }

      String.starts_with?(trimmed, "Error:") or String.starts_with?(trimmed, "ERROR:") ->
        %{
          event_type: "run.failed",
          data: %{"text" => trimmed},
          tokens_input: 0,
          tokens_output: 0
        }

      true ->
        %{
          event_type: "run.output",
          data: %{"text" => trimmed},
          tokens_input: 0,
          tokens_output: 0
        }
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
              "error" => "Hermes binary not found",
              "adapter" => type(),
              "hint" =>
                "Install Hermes: cargo install hermes-cli  (see https://github.com/nousresearch/hermes)"
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

  defp generate_id, do: Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
end
