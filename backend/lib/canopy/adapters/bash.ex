defmodule Canopy.Adapters.Bash do
  @moduledoc "Bash adapter — spawns shell, streams stdout/stderr."
  @behaviour Canopy.Adapter

  @impl true
  def type, do: "bash"

  @impl true
  def name, do: "Bash Shell"

  @impl true
  def supports_session?, do: false

  @impl true
  def supports_concurrent?, do: true

  @impl true
  def capabilities, do: [:code_execution, :file_edit]

  @impl true
  def health, do: :ok

  @impl true
  def start(config) do
    {:ok, %{cwd: config["working_dir"] || ".", shell: config["shell"] || "/bin/bash"}}
  end

  @impl true
  def stop(_session), do: :ok

  @impl true
  def execute_heartbeat(params) do
    command = params["context"] || "echo 'No heartbeat command configured'"
    cwd = params["working_dir"] || "."

    Stream.resource(
      fn ->
        port =
          Port.open(
            {:spawn_executable, "/bin/bash"},
            [
              :binary,
              :exit_status,
              :stderr_to_stdout,
              args: ["-c", command],
              cd: to_charlist(cwd)
            ]
          )

        {port, ""}
      end,
      fn
        {:halt_next, _} ->
          {:halt, :done}

        {port, buf} ->
          receive do
            {^port, {:data, data}} ->
              {[%{event_type: "run.output", data: %{"text" => data}, tokens: 0}],
               {port, buf <> data}}

            {^port, {:exit_status, code}} ->
              {[
                 %{
                   event_type: "run.completed",
                   data: %{"exit_code" => code, "output" => buf},
                   tokens: 0
                 }
               ], {:halt_next, port}}
          after
            120_000 -> {:halt, {port, buf}}
          end
      end,
      fn
        :done ->
          :ok

        {:halt_next, port} ->
          try do
            Port.close(port)
          rescue
            _ -> :ok
          end

        {port, _} ->
          try do
            Port.close(port)
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
