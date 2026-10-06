defmodule Canopy.Adapters.Qwen do
  @moduledoc """
  Qwen Coder adapter — spawns the `qwen-coder` or `qwen` CLI.

  Delivers prompts via stdin and streams stdout/stderr back as events.

  ## Installation

  Install via pip or your package manager:

      pip install qwen-agent
      # or via official Qwen CLI tooling

  Verify installation:

      qwen-coder --version
      # or: qwen --version

  ## Config keys

  - `"working_dir"` — directory for qwen to operate in (default: system tmp)
  - `"model"` — model string to use (e.g. `"qwen2.5-coder-32b"`, optional)
  - `"qwen_args"` — list of extra CLI args (optional)

  If neither `qwen-coder` nor `qwen` binary is found, `start/1` returns
  `{:error, :adapter_not_installed}`.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "qwen"

  @impl true
  def name, do: "Qwen Coder"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :code_edit, :file_read, :file_write]

  @impl true
  def health do
    if find_qwen(), do: :ok, else: {:error, "qwen-coder/qwen binary not found"}
  end

  @impl true
  def start(config) do
    case find_qwen() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           qwen_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           extra_args: config["qwen_args"] || []
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
    extra_args = params["qwen_args"] || []

    case find_qwen() do
      nil -> not_installed_stream()
      qwen_bin -> spawn_qwen_stream(qwen_bin, prompt, cwd, model, extra_args)
    end
  end

  @impl true
  def send_message(
        %{qwen_bin: qwen_bin, cwd: cwd, model: model, extra_args: extra_args},
        message
      ) do
    spawn_qwen_stream(qwen_bin, message, cwd, model, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_qwen do
    candidates = ["qwen-coder", "qwen"]

    Enum.find_value(candidates, fn binary ->
      case System.find_executable(binary) do
        nil ->
          home = System.get_env("HOME") || "/"

          known_paths = [
            Path.join([home, ".local", "bin", binary]),
            Path.join([home, ".venv", "bin", binary]),
            Path.join([home, "Library", "Python", "3.12", "bin", binary]),
            Path.join([home, "Library", "Python", "3.11", "bin", binary]),
            "/usr/local/bin/#{binary}",
            "/opt/homebrew/bin/#{binary}"
          ]

          Enum.find(known_paths, &File.exists?/1)

        path ->
          path
      end
    end)
  end

  defp build_args(model, extra_args) do
    model_args = if model, do: ["--model", model], else: []
    model_args ++ extra_args
  end

  defp spawn_qwen_stream(qwen_bin, prompt, cwd, model, extra_args) do
    args = build_args(model, extra_args)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, qwen_bin},
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
              "error" => "Qwen Coder binary not found",
              "adapter" => type(),
              "hint" => "Install Qwen CLI: pip install qwen-agent"
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
