defmodule Canopy.Adapters.Amp do
  @moduledoc """
  Amp adapter — spawns Sourcegraph's `amp` CLI agent with prompt delivered
  via stdin for non-interactive execution.

  Amp is Sourcegraph's AI coding agent with deep code intelligence and
  codebase-aware context retrieval.

  ## Installation

      npm install -g @sourcegraph/amp
      # or via their install script:
      curl -fsSL https://amp.sourcegraph.com/install.sh | bash

  Verify installation:

      amp --version

  ## Config keys

  - `"working_dir"` — working directory / repo path (default: system tmp)
  - `"model"` — model override (optional)

  If the `amp` binary is not found, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "amp"

  @impl true
  def name, do: "Amp"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write, :tools, :web_search]

  @impl true
  def health do
    if find_amp(), do: :ok, else: {:error, "amp binary not found in PATH"}
  end

  @impl true
  def start(config) do
    case find_amp() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           amp_bin: path,
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

    case find_amp() do
      nil -> not_installed_stream()
      amp_bin -> spawn_amp_stream(amp_bin, prompt, cwd, model, opts)
    end
  end

  @impl true
  def send_message(%{amp_bin: amp_bin, cwd: cwd, model: model} = state, message) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    spawn_amp_stream(amp_bin, message, cwd, model, opts)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_amp do
    case System.find_executable("amp") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "amp"]),
          Path.join([home, ".sourcegraph", "bin", "amp"]),
          "/usr/local/bin/amp",
          "/opt/homebrew/bin/amp"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model) do
    base = ["--non-interactive"]
    if model, do: base ++ ["--model", model], else: base
  end

  defp spawn_amp_stream(amp_bin, prompt, cwd, model, opts) do
    args = build_args(model)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, amp_bin},
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
              "error" => "Amp binary not found",
              "adapter" => type(),
              "hint" =>
                "Install Amp: npm install -g @sourcegraph/amp  (see https://amp.sourcegraph.com)"
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
      {~c"AMP", ~c""},
      {~c"AMP_SESSION", ~c""},
      {~c"AMP_PARENT_SESSION", ~c""}
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
