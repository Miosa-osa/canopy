defmodule Canopy.Adapters.Codex do
  @moduledoc "Codex CLI adapter — spawns `codex` process."
  @behaviour Canopy.Adapter

  @impl true
  def type, do: "codex"

  @impl true
  def name, do: "OpenAI Codex"

  @impl true
  def supports_session?, do: true

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:chat, :tools, :code_execution, :file_edit]

  @impl true
  def health do
    if System.find_executable("codex"), do: :ok, else: {:error, "codex binary not found in PATH"}
  end

  @impl true
  def start(config) do
    {:ok, %{cwd: config["working_dir"] || ".", model: config["model"] || "codex"}}
  end

  @impl true
  def stop(_), do: :ok

  @impl true
  def execute_heartbeat(params) do
    prompt = params["context"] || ""
    cwd = params["working_dir"] || "."

    Stream.resource(
      fn ->
        bin = System.find_executable("codex") || "codex"

        port =
          Port.open(
            {:spawn_executable, bin},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: ["--quiet", prompt],
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

            {^port, {:exit_status, code}} ->
              {[%{event_type: "run.completed", data: %{"exit_code" => code}, tokens: 0}],
               {:done, port}}
          after
            120_000 -> {:halt, {port, buf}}
          end
      end,
      fn
        {:done, p} ->
          try do
            Port.close(p)
          rescue
            _ -> :ok
          end

        {p, _} ->
          try do
            Port.close(p)
          rescue
            _ -> :ok
          end
      end
    )
  end

  @impl true
  def send_message(session, message) do
    execute_heartbeat(Map.merge(session, %{"context" => message}))
  end
end
