defmodule Canopy.Adapters.Windsurf do
  @moduledoc """
  Windsurf adapter — spawns the `windsurf` CLI for non-interactive task execution.

  Windsurf is an AI-powered IDE by Codeium. This adapter drives it via the
  `windsurf` CLI binary, which must be installed and available in PATH.

  ## Installation

      # macOS — Windsurf ships a CLI via its application bundle
      # Open Windsurf → Cmd+Shift+P → "Install 'windsurf' command in PATH"
      # Or add the app bundle's bin to your PATH:
      export PATH="$PATH:/Applications/Windsurf.app/Contents/Resources/app/bin"

  ## Config keys

  - `"working_dir"` — working directory for execution (default: system tmp)
  - `"model"` — model override passed to windsurf CLI (optional)

  If the `windsurf` binary is not installed, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "windsurf"

  @impl true
  def name, do: "Windsurf"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: false

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :code_completion]

  @impl true
  def health do
    if find_windsurf(), do: :ok, else: {:error, "windsurf binary not found"}
  end

  @impl true
  def start(config) do
    case find_windsurf() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           windsurf_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"]
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Review the workspace and report status."
    cwd = params["working_dir"] || "."

    case find_windsurf() do
      nil ->
        not_installed_stream()

      windsurf_bin ->
        spawn_windsurf_stream(windsurf_bin, prompt, cwd, params["model"])
    end
  end

  @impl true
  def send_message(%{windsurf_bin: windsurf_bin, cwd: cwd, model: model}, message) do
    spawn_windsurf_stream(windsurf_bin, message, cwd, model)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_windsurf do
    case System.find_executable("windsurf") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          "/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf",
          Path.join([home, ".local", "bin", "windsurf"]),
          "/usr/local/bin/windsurf",
          "/opt/homebrew/bin/windsurf"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp spawn_windsurf_stream(windsurf_bin, prompt, cwd, model) do
    args =
      if model do
        ["--model", model, "--print", prompt]
      else
        ["--print", prompt]
      end

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, windsurf_bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: args,
              cd: to_charlist(cwd)
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
              {[%{event_type: "run.completed", data: %{"output" => buf}, tokens: 0}], {:done, port}}

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

  defp not_installed_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "Windsurf CLI not found",
              "adapter" => type(),
              "hint" =>
                "Install Windsurf from https://codeium.com/windsurf and run: Windsurf → Cmd+Shift+P → 'Install windsurf command in PATH'"
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

  defp close_port(port) do
    try do
      Port.close(port)
    rescue
      _ -> :ok
    end
  end
end
