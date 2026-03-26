defmodule Canopy.Adapters.JidoClaw do
  @moduledoc """
  JidoClaw adapter — Elixir-native agent framework integration.

  JidoClaw is an Elixir/OTP-native agent framework. When the `JidoClaw` module
  is available in the runtime (i.e. the package is a dependency), this adapter
  calls it directly via function calls. Otherwise, it falls back to spawning the
  `jidoclaw` CLI binary.

  ## Installation (library mode — preferred)

  Add to your `mix.exs`:

      {:jido_claw, "~> 0.1"}

  ## Installation (CLI mode — fallback)

      mix escript.install hex jido_claw
      # or
      brew install jidoclaw

  ## Config keys

  - `"working_dir"` — working directory (default: system tmp)
  - `"model"` — model to use when invoking JidoClaw (optional)
  - `"jidoclaw_args"` — extra CLI args when running in CLI mode (optional)

  If neither the module nor the binary is available, `start/1` returns
  `{:error, :adapter_not_installed}` and streams emit a `run.failed` event.
  """

  @behaviour Canopy.Adapter

  require Logger

  @impl true
  def type, do: "jido-claw"

  @impl true
  def name, do: "JidoClaw"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:code_edit, :file_read, :file_write, :shell_execution, :elixir_native]

  @impl true
  def health do
    cond do
      native_available?() -> :ok
      find_jidoclaw_cli() != nil -> :ok
      true -> {:error, "jidoclaw not found (neither module nor CLI binary)"}
    end
  end

  @impl true
  def start(config) do
    cond do
      native_available?() ->
        {:ok,
         %{
           mode: :native,
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"]
         }}

      find_jidoclaw_cli() != nil ->
        {:ok,
         %{
           mode: :cli,
           jidoclaw_bin: find_jidoclaw_cli(),
           cwd: config["working_dir"] || System.tmp_dir!(),
           model: config["model"],
           extra_args: config["jidoclaw_args"] || []
         }}

      true ->
        {:error, :adapter_not_installed}
    end
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || "Perform your scheduled task."
    cwd = params["working_dir"] || "."
    model = params["model"]

    cond do
      native_available?() ->
        run_native(prompt, cwd, model)

      find_jidoclaw_cli() != nil ->
        spawn_cli_stream(find_jidoclaw_cli(), prompt, cwd, model, params["jidoclaw_args"] || [])

      true ->
        not_installed_stream()
    end
  end

  @impl true
  def send_message(%{mode: :native, cwd: cwd, model: model}, message) do
    run_native(message, cwd, model)
  end

  def send_message(
        %{mode: :cli, jidoclaw_bin: bin, cwd: cwd, model: model, extra_args: extra_args},
        message
      ) do
    spawn_cli_stream(bin, message, cwd, model, extra_args)
  end

  def send_message(_session, message) do
    execute_heartbeat(%{"context" => message})
  end

  # -- Private --

  # Runtime check — uses function_exported?/3 so the type system treats this
  # as an opaque boolean (not a compile-time constant), avoiding dead-code warnings
  # when JidoClaw is not a dependency of this project.
  defp native_available? do
    function_exported?(JidoClaw, :run, 1)
  end

  defp find_jidoclaw_cli do
    case System.find_executable("jidoclaw") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".mix", "escripts", "jidoclaw"]),
          Path.join([home, ".local", "bin", "jidoclaw"]),
          "/usr/local/bin/jidoclaw",
          "/opt/homebrew/bin/jidoclaw"
        ]

        Enum.find(known_paths, &File.exists?/1)

      path ->
        path
    end
  end

  defp run_native(prompt, _cwd, _model) do
    # JidoClaw native module is present — call it directly.
    # The exact API depends on the JidoClaw version; we pattern-match the module
    # being available and fall back gracefully if the call fails.
    Stream.resource(
      fn -> :pending end,
      fn
        :pending ->
          result =
            try do
              # Attempt to call the JidoClaw module's run function.
              # Adjust the function name/arity if the JidoClaw API differs.
              apply(JidoClaw, :run, [prompt])
            rescue
              e ->
                {:error, Exception.message(e)}
            catch
              :exit, reason ->
                {:error, inspect(reason)}
            end

          case result do
            {:ok, output} when is_binary(output) ->
              events = [
                %{event_type: "run.output", data: %{"text" => output}, tokens: 0},
                %{event_type: "run.completed", data: %{}, tokens: 0}
              ]

              {events, :done}

            {:ok, output} ->
              events = [
                %{event_type: "run.output", data: %{"result" => output}, tokens: 0},
                %{event_type: "run.completed", data: %{}, tokens: 0}
              ]

              {events, :done}

            {:error, reason} ->
              {[%{event_type: "run.failed", data: %{"error" => inspect(reason)}, tokens: 0}],
               :done}

            other ->
              {[
                 %{event_type: "run.output", data: %{"result" => inspect(other)}, tokens: 0},
                 %{event_type: "run.completed", data: %{}, tokens: 0}
               ], :done}
          end

        :done ->
          {:halt, :done}
      end,
      fn _ -> :ok end
    )
  end

  defp spawn_cli_stream(jidoclaw_bin, prompt, cwd, model, extra_args) do
    model_args = if model, do: ["--model", model], else: []
    args = ["run", "--prompt", prompt] ++ model_args ++ extra_args

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, jidoclaw_bin},
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
              "error" => "JidoClaw not found (neither module nor CLI)",
              "adapter" => type(),
              "hint" =>
                "Add {:jido_claw, \"~> 0.1\"} to mix.exs, or install the CLI: mix escript.install hex jido_claw"
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
