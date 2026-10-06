defmodule Canopy.Adapters.Goose do
  @moduledoc """
  Goose adapter — spawns Block's `goose` CLI agent using the `--message` flag
  for single-shot, non-interactive task execution.

  Goose is an open-source AI developer agent built by Block (formerly Square).

  ## Installation

      # via Homebrew:
      brew install block/goose/goose
      # or via the install script:
      curl -fsSL https://raw.githubusercontent.com/block/goose/main/install.sh | bash

  Verify installation:

      goose --version

  ## Config keys

  - `"working_dir"` — working directory for execution (default: system tmp)
  - `"profile"` — goose profile to use (optional)

  If the `goose` binary is not found, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "goose"

  @impl true
  def name, do: "Goose"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write, :tools, :web_search]

  @impl true
  def health do
    if find_goose(), do: :ok, else: {:error, "goose binary not found in PATH"}
  end

  @impl true
  def start(config) do
    case find_goose() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           goose_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           profile: config["profile"]
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || params["workspace_path"] || "."
    profile = params["profile"]
    opts = %{workspace_path: cwd}

    case find_goose() do
      nil -> not_installed_stream()
      goose_bin -> spawn_goose_stream(goose_bin, prompt, cwd, profile, opts)
    end
  end

  @impl true
  def send_message(%{goose_bin: goose_bin, cwd: cwd, profile: profile} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    spawn_goose_stream(goose_bin, message, cwd, profile, opts)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_goose do
    case System.find_executable("goose") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "goose"]),
          Path.join([home, ".goose", "bin", "goose"]),
          "/usr/local/bin/goose",
          "/opt/homebrew/bin/goose"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(prompt, profile) do
    base = ["run", "--message", prompt]
    if profile, do: base ++ ["--profile", profile], else: base
  end

  defp spawn_goose_stream(goose_bin, prompt, cwd, profile, opts) do
    args = build_args(prompt, profile)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, goose_bin},
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
              "error" => "Goose binary not found",
              "adapter" => type(),
              "hint" =>
                "Install Goose: brew install block/goose/goose  (see https://github.com/block/goose)"
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
      {~c"GOOSE", ~c""},
      {~c"GOOSE_SESSION", ~c""},
      {~c"GOOSE_PARENT_SESSION", ~c""}
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
