defmodule Canopy.Adapters.SWEAgent do
  @moduledoc """
  SWE-agent adapter — spawns the `swe-agent` CLI (Princeton NLP) with prompt
  delivered via stdin for non-interactive execution.

  SWE-agent is an open-source autonomous software engineering agent that can
  resolve GitHub issues, write code, and execute tests.

  ## Installation

      pip install swe-agent
      # or from source:
      git clone https://github.com/SWE-agent/SWE-agent && pip install -e .

  Verify installation:

      swe-agent --version

  ## Config keys

  - `"working_dir"` — working directory / repo path (default: system tmp)
  - `"model"` — LLM model string (e.g. `"claude-3-5-sonnet"`, optional)
  - `"config"` — path to a SWE-agent config YAML (optional)

  If the `swe-agent` binary is not found, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "swe-agent"

  @impl true
  def name, do: "SWE-agent"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :git_operations, :tools]

  @impl true
  def health do
    if find_swe_agent(), do: :ok, else: {:error, "swe-agent binary not found in PATH"}
  end

  @impl true
  def start(config) do
    case find_swe_agent() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           swe_agent_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           config_path: config["config"]
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Analyze the repository and suggest improvements."
    cwd = params["working_dir"] || params["workspace_path"] || "."
    model = params["model"]
    config_path = params["config"]
    opts = %{workspace_path: cwd}

    case find_swe_agent() do
      nil -> not_installed_stream()
      swe_agent_bin -> spawn_swe_agent_stream(swe_agent_bin, prompt, cwd, model, config_path, opts)
    end
  end

  @impl true
  def send_message(
        %{swe_agent_bin: swe_agent_bin, cwd: cwd, model: model, config_path: config_path} =
          state,
        message
      ) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    spawn_swe_agent_stream(swe_agent_bin, message, cwd, model, config_path, opts)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_swe_agent do
    case System.find_executable("swe-agent") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "swe-agent"]),
          Path.join([home, ".venv", "bin", "swe-agent"]),
          "/usr/local/bin/swe-agent",
          "/opt/homebrew/bin/swe-agent"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model, config_path) do
    base = ["run"]
    model_args = if model, do: ["--model", model], else: []
    config_args = if config_path, do: ["--config", config_path], else: []
    base ++ model_args ++ config_args
  end

  defp spawn_swe_agent_stream(swe_agent_bin, prompt, cwd, model, config_path, opts) do
    args = build_args(model, config_path)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, swe_agent_bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: args,
              cd: to_charlist(cwd),
              env: nesting_guard_env() ++ canopy_env(opts)
            ]
          )

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
            180_000 ->
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
              "error" => "SWE-agent binary not found",
              "adapter" => type(),
              "hint" =>
                "Install SWE-agent: pip install swe-agent  (see https://github.com/SWE-agent/SWE-agent)"
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
      {~c"SWE_AGENT", ~c""},
      {~c"SWE_AGENT_SESSION", ~c""},
      {~c"SWE_AGENT_PARENT_SESSION", ~c""}
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
