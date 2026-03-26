defmodule Canopy.Adapters.Aider do
  @moduledoc """
  Aider adapter — spawns the `aider` Python-based AI coding assistant.

  Aider is an open-source CLI tool that uses LLMs to edit code in git repositories.
  This adapter runs it in `--message` mode (non-interactive, single-shot) and
  streams stdout/stderr back as events.

  ## Installation

      pip install aider-chat
      # or with uv:
      uv tool install aider-chat

  Verify installation:

      aider --version

  ## Config keys

  - `"working_dir"` — git repo directory for aider to operate in (default: system tmp)
  - `"model"` — LLM model string aider should use (e.g. `"claude-3-5-sonnet"`, optional)
  - `"api_key"` — API key for the model provider (optional; aider reads env vars too)
  - `"aider_args"` — list of extra CLI args passed to aider (optional)

  ## Environment variables

  Aider reads provider keys from the environment automatically:
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, etc.

  If the `aider` binary is not found, `start/1` returns `{:error, :adapter_not_installed}`
  and streams emit a `run.failed` event with installation instructions.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "aider"

  @impl true
  def name, do: "Aider"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :git_operations]

  @impl true
  def health do
    if find_aider(), do: :ok, else: {:error, "aider binary not found"}
  end

  @impl true
  def start(config) do
    case find_aider() do
      nil ->
        {:error, :adapter_not_installed}

      path ->
        {:ok,
         %{
           aider_bin: path,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           extra_args: config["aider_args"] || []
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
    extra_args = params["aider_args"] || []

    case find_aider() do
      nil ->
        not_installed_stream()

      aider_bin ->
        spawn_aider_stream(aider_bin, prompt, cwd, model, extra_args)
    end
  end

  @impl true
  def send_message(
        %{aider_bin: aider_bin, cwd: cwd, model: model, extra_args: extra_args},
        message
      ) do
    spawn_aider_stream(aider_bin, message, cwd, model, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  defp find_aider do
    case System.find_executable("aider") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".local", "bin", "aider"]),
          Path.join([home, ".venv", "bin", "aider"]),
          Path.join([home, "Library", "Python", "3.12", "bin", "aider"]),
          Path.join([home, "Library", "Python", "3.11", "bin", "aider"]),
          "/usr/local/bin/aider",
          "/opt/homebrew/bin/aider"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp build_args(prompt, model, extra_args) do
    base = [
      "--message",
      prompt,
      "--yes-always",
      "--no-auto-commits"
    ]

    model_args = if model, do: ["--model", model], else: []

    base ++ model_args ++ extra_args
  end

  defp spawn_aider_stream(aider_bin, prompt, cwd, model, extra_args) do
    args = build_args(prompt, model, extra_args)

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, aider_bin},
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
              "error" => "Aider binary not found",
              "adapter" => type(),
              "hint" =>
                "Install Aider: pip install aider-chat  (see https://aider.chat/docs/installation.html)"
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
