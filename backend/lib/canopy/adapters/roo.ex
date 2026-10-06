defmodule Canopy.Adapters.Roo do
  @moduledoc """
  Roo Code adapter — spawns the `roo` CLI for AI-assisted coding.

  Roo Code is an AI coding assistant CLI. This adapter runs it in non-interactive
  mode by delivering the prompt via stdin and parsing JSON output.

  ## Installation

      npm install -g roo-cline
      # or via your package manager

  Verify installation:

      roo --version

  ## Config keys

  - `"working_dir"` — directory for roo to operate in (default: system tmp)
  - `"model"` — model string to use (optional)
  - `"roo_args"` — list of extra CLI args passed to roo (optional)

  If the `roo` binary is not found, `start/1` returns `{:error, :adapter_not_installed}`
  and streams emit a `run.failed` event with installation instructions.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "roo"

  @impl true
  def name, do: "Roo Code"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write, :tools]

  @impl true
  def health do
    if find_roo(), do: :ok, else: {:error, "roo binary not found"}
  end

  @impl true
  def start(config) do
    case find_roo() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           roo_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           extra_args: config["roo_args"] || []
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
    extra_args = params["roo_args"] || []

    case find_roo() do
      nil -> not_installed_stream()
      roo_bin -> spawn_roo_stream(roo_bin, prompt, cwd, model, extra_args)
    end
  end

  @impl true
  def send_message(%{roo_bin: roo_bin, cwd: cwd, model: model, extra_args: extra_args}, message) do
    spawn_roo_stream(roo_bin, message, cwd, model, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_roo do
    case System.find_executable("roo") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "roo"]),
          Path.join([home, ".npm-global", "bin", "roo"]),
          "/usr/local/bin/roo",
          "/opt/homebrew/bin/roo"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(model, extra_args) do
    base = ["--output-format", "json"]
    model_args = if model, do: ["--model", model], else: []
    base ++ model_args ++ extra_args
  end

  defp spawn_roo_stream(roo_bin, prompt, cwd, model, extra_args) do
    args = build_args(model, extra_args)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, roo_bin},
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
              combined = buf <> data
              {events, remaining} = parse_json_lines(combined)
              {events, {port, remaining}}

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

  # Parse newline-delimited JSON, returning {[events], remaining_buffer}.
  # Falls back to raw text events for non-JSON lines.
  defp parse_json_lines(buffer) do
    lines = String.split(buffer, "\n")
    {complete, [partial]} = Enum.split(lines, length(lines) - 1)

    events =
      complete
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(fn line ->
        case Jason.decode(line) do
          {:ok, decoded} ->
            %{
              event_type: Map.get(decoded, "type", "run.output"),
              data: decoded,
              tokens: Map.get(decoded, "tokens", 0)
            }

          _ ->
            %{event_type: "run.output", data: %{"text" => line}, tokens: 0}
        end
      end)

    {events, partial}
  end

  defp not_installed_stream do
    Stream.resource(
      fn -> :once end,
      fn
        :once ->
          event = %{
            event_type: "run.failed",
            data: %{
              "error" => "Roo binary not found",
              "adapter" => type(),
              "hint" => "Install Roo Code CLI: npm install -g roo-cline"
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
