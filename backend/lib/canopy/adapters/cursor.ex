defmodule Canopy.Adapters.Cursor do
  @moduledoc """
  Cursor IDE adapter — spawns the `cursor` CLI for non-interactive task execution.

  Cursor is an AI-powered IDE. This adapter drives it via the `cursor` CLI binary,
  which must be installed and available in PATH (or the standard install locations).

  ## Installation

      # macOS — Cursor ships a CLI via its application bundle
      # Open Cursor → Cmd+Shift+P → "Install 'cursor' command in PATH"
      # Or add the app bundle's bin to your PATH:
      export PATH="$PATH:/Applications/Cursor.app/Contents/Resources/app/bin"

  ## Config keys

  - `"working_dir"` — working directory for execution (default: system tmp)
  - `"model"` — model override passed to cursor CLI (optional)

  If the `cursor` binary is not installed, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "cursor"

  @impl true
  def name, do: "Cursor"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: false

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :code_completion]

  @impl true
  def health do
    if find_cursor(), do: :ok, else: {:error, "cursor binary not found"}
  end

  @impl true
  def start(config) do
    case find_cursor() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           cursor_bin: path,
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

    case find_cursor() do
      nil ->
        not_installed_stream()

      cursor_bin ->
        spawn_cursor_stream(cursor_bin, prompt, cwd, params["model"])
    end
  end

  @impl true
  def send_message(%{cursor_bin: cursor_bin, cwd: cwd, model: model}, message) do
    spawn_cursor_stream(cursor_bin, message, cwd, model)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_cursor do
    case System.find_executable("cursor") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          "/Applications/Cursor.app/Contents/Resources/app/bin/cursor",
          Path.join([home, ".local", "bin", "cursor"]),
          "/usr/local/bin/cursor",
          "/opt/homebrew/bin/cursor"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp spawn_cursor_stream(cursor_bin, prompt, cwd, model) do
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
            {:spawn_executable, cursor_bin},
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
              "error" => "Cursor CLI not found",
              "adapter" => type(),
              "hint" =>
                "Install Cursor from https://cursor.sh and run: Cursor → Cmd+Shift+P → 'Install cursor command in PATH'"
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
