defmodule Canopy.Adapters.Aide do
  @moduledoc """
  Aide adapter — spawns the `aide` CLI for AI-assisted coding.

  Aide is an open-source AI coding assistant. This adapter runs it in
  non-interactive mode by delivering the prompt via stdin.

  ## Installation

      npm install -g aide-cli
      # or via your package manager

  Verify installation:

      aide --version

  ## Config keys

  - `"working_dir"` — directory for aide to operate in (default: system tmp)
  - `"model"` — model string to use (optional)
  - `"aide_args"` — list of extra CLI args passed to aide (optional)

  If the `aide` binary is not found, `start/1` returns `{:error, :adapter_not_installed}`
  and streams emit a `run.failed` event with installation instructions.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "aide"

  @impl true
  def name, do: "Aide"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write]

  @impl true
  def health do
    if find_aide(), do: :ok, else: {:error, "aide binary not found"}
  end

  @impl true
  def start(config) do
    case find_aide() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           aide_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           extra_args: config["aide_args"] || []
         }}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Review the codebase and report status."
    cwd = params["working_dir"] || "."
    model = params["model"]
    extra_args = params["aide_args"] || []

    case find_aide() do
      nil -> not_installed_stream()
      aide_bin -> spawn_aide_stream(aide_bin, prompt, cwd, model, extra_args)
    end
  end

  @impl true
  def send_message(%{aide_bin: aide_bin, cwd: cwd, model: model, extra_args: extra_args}, message) do
    spawn_aide_stream(aide_bin, message, cwd, model, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_aide do
    case System.find_executable("aide") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "aide"]),
          Path.join([home, ".npm-global", "bin", "aide"]),
          "/usr/local/bin/aide",
          "/opt/homebrew/bin/aide"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model, extra_args) do
    model_args = if model, do: ["--model", model], else: []
    model_args ++ extra_args
  end

  defp spawn_aide_stream(aide_bin, prompt, cwd, model, extra_args) do
    args = build_args(model, extra_args)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, aide_bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: args,
              cd: to_charlist(cwd)
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
              "error" => "Aide binary not found",
              "adapter" => type(),
              "hint" => "Install Aide: npm install -g aide-cli"
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
