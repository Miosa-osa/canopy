defmodule Canopy.Adapters.Plandex do
  @moduledoc """
  Plandex adapter — spawns the `plandex` CLI using the `tell` subcommand
  for non-interactive, single-shot task execution.

  Plandex is an open-source AI coding engine that uses long-running agents
  to plan and implement complex, multi-file changes.

  ## Installation

      curl -sL https://plandex.ai/install.sh | bash
      # or via Homebrew:
      brew install plandex-ai/tap/plandex

  Verify installation:

      plandex version

  ## Config keys

  - `"working_dir"` — working directory / repo path (default: system tmp)
  - `"model"` — model pack or model string (optional)
  - `"plan_name"` — plandex plan name to use (optional)

  If the `plandex` binary is not found, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "plandex"

  @impl true
  def name, do: "Plandex"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: false

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :git_operations, :tools]

  @impl true
  def health do
    if find_plandex(), do: :ok, else: {:error, "plandex binary not found in PATH"}
  end

  @impl true
  def start(config) do
    case find_plandex() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           plandex_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           plan_name: config["plan_name"]
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
    plan_name = params["plan_name"]
    opts = %{workspace_path: cwd}

    case find_plandex() do
      nil -> not_installed_stream()
      plandex_bin -> spawn_plandex_stream(plandex_bin, prompt, cwd, model, plan_name, opts)
    end
  end

  @impl true
  def send_message(
        %{plandex_bin: plandex_bin, cwd: cwd, model: model, plan_name: plan_name} = state,
        message
      ) do
    opts = %{
      agent_id: Map.get(state, :agent_id, ""),
      run_id: Map.get(state, :run_id, ""),
      workspace_path: cwd
    }

    spawn_plandex_stream(plandex_bin, message, cwd, model, plan_name, opts)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_plandex do
    case System.find_executable("plandex") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "plandex"]),
          Path.join([home, ".plandex", "bin", "plandex"]),
          "/usr/local/bin/plandex",
          "/opt/homebrew/bin/plandex"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(prompt, model, plan_name) do
    # plandex tell "<prompt>" [--name <plan>] [--model <model>] --auto-continue
    base = ["tell", prompt, "--auto-continue"]
    name_args = if plan_name, do: ["--name", plan_name], else: []
    model_args = if model, do: ["--model", model], else: []
    base ++ name_args ++ model_args
  end

  defp spawn_plandex_stream(plandex_bin, prompt, cwd, model, plan_name, opts) do
    args = build_args(prompt, model, plan_name)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, plandex_bin},
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
              "error" => "Plandex binary not found",
              "adapter" => type(),
              "hint" =>
                "Install Plandex: curl -sL https://plandex.ai/install.sh | bash  (see https://github.com/plandex-ai/plandex)"
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
      {~c"PLANDEX", ~c""},
      {~c"PLANDEX_SESSION", ~c""},
      {~c"PLANDEX_PARENT_SESSION", ~c""}
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
