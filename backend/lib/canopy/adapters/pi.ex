defmodule Canopy.Adapters.Pi do
  @moduledoc """
  Pi adapter — spawns the `pi` CLI-based agent.

  Pi is invoked in non-interactive mode with the prompt delivered via stdin.
  Output is streamed as plain text lines, matching the Aider/Hermes adapter pattern.

  ## Installation

      # Install from https://pi.ai or your distribution's package manager
      brew install pi
      # or
      npm install -g @pi-ai/cli

  Verify installation:

      pi --version

  ## Config keys

  - `"working_dir"` — working directory for pi to operate in (default: system tmp)
  - `"model"` — model override (optional)

  ## Environment variables

  The adapter sets `CANOPY_*` env vars so Pi sub-processes can call back to the
  Canopy API. Provider keys are read from the environment as needed.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "pi"

  @impl true
  def name, do: "Pi"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :file_edit]

  @impl true
  def health do
    case find_pi() do
      nil -> {:error, "pi binary not found"}
      _path -> :ok
    end
  end

  @impl true
  def start(config) do
    {:ok,
     %{
       cwd: config["working_dir"] || System.tmp_dir!(),
       model: config["model"],
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

    opts = %{
      agent_id: Map.get(params, "agent_id", ""),
      run_id: Map.get(params, "run_id", ""),
      workspace_path: cwd
    }

    stream_pi_command(prompt, cwd, model, opts)
  end

  @impl true
  def send_message(%{cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    stream_pi_command(message, cwd, model, opts)
  end

  # -- Private --

  defp find_pi do
    case System.find_executable("pi") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "pi"]),
          Path.join([home, ".npm-global", "bin", "pi"]),
          "/usr/local/bin/pi",
          "/opt/homebrew/bin/pi"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model) do
    base = ["--print"]
    model_args = if model, do: ["--model", model], else: []
    base ++ model_args
  end

  defp stream_pi_command(prompt, cwd, model, opts) do
    pi_bin = find_pi()

    if is_nil(pi_bin) do
      not_installed_stream()
    else
      args = build_args(model)

      Stream.resource(
        fn ->
          port =
            Port.open(
              {:spawn_executable, pi_bin},
              [
                :binary,
                :exit_status,
                :stderr_to_stdout,
                args: args,
                cd: to_charlist(cwd),
                env: canopy_env(opts)
              ]
            )

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
                |> Enum.map(fn line ->
                  %{
                    event_type: "run.output",
                    data: %{"text" => line},
                    tokens_input: 0,
                    tokens_output: 0
                  }
                end)

              {events, {port, remaining}}

            {^port, {:exit_status, 0}} ->
              final_events =
                if String.trim(buffer) != "" do
                  [
                    %{
                      event_type: "run.output",
                      data: %{"text" => buffer},
                      tokens_input: 0,
                      tokens_output: 0
                    }
                  ]
                else
                  []
                end

              {final_events ++
                 [%{event_type: "run.completed", data: %{}, tokens_input: 0, tokens_output: 0}],
               {:halt_port, port}}

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

  defp not_installed_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "Pi binary not found",
              "adapter" => type(),
              "hint" => "Install Pi: npm install -g @pi-ai/cli  (see https://pi.ai)"
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
