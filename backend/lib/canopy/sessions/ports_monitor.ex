defmodule Canopy.Sessions.PortsMonitor do
  @moduledoc """
  Scans listening TCP/UDP ports for a session's pty process and its descendants.

  Uses `lsof -Pan -p <pid> -i TCP -i UDP -sTCP:LISTEN` on macOS/Linux.
  Falls back to an empty list when lsof is unavailable or the process is gone.

  Public API:
    scan(session_id) — returns {:ok, [port_entry()]} | {:error, reason}

  port_entry() :: %{port: integer, proto: String.t(), state: String.t(), pid: integer}
  """

  require Logger

  @type port_entry :: %{
          port: non_neg_integer(),
          proto: String.t(),
          state: String.t(),
          pid: non_neg_integer()
        }

  @lsof_timeout_ms 3_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Returns listening ports for the given session's pty process.

  Looks up the os_pid via PtyBridge state, then calls lsof.
  """
  @spec scan(Canopy.Sessions.PtyBridge.session_id()) ::
          {:ok, [port_entry()]}
  def scan(session_id) do
    case os_pid_for_session(session_id) do
      nil ->
        {:ok, []}

      os_pid ->
        run_lsof(os_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp os_pid_for_session(session_id) do
    registry = Canopy.Sessions.PtyRegistry

    case Registry.lookup(registry, session_id) do
      [{pid, _}] ->
        try do
          state = :sys.get_state(pid, 2_000)
          Map.get(state, :os_pid)
        rescue
          _ -> nil
        catch
          _, _ -> nil
        end

      [] ->
        nil
    end
  end

  defp run_lsof(os_pid) do
    # -P  — show numeric ports (no service name substitution)
    # -a  — AND the selectors
    # -n  — no hostname resolution (speed)
    # -p  — target pid (and descendants via lsof tree)
    # -i  — internet sockets
    # -sT CP:LISTEN — only LISTEN state TCP; UDP has no state
    args = ["-Pan", "-p", to_string(os_pid), "-i", "TCP", "-i", "UDP", "-sTCP:LISTEN"]

    case System.find_executable("lsof") do
      nil ->
        Logger.warning("[PortsMonitor] lsof not found — returning empty port list")
        {:ok, []}

      lsof ->
        case System.cmd(lsof, args, stderr_to_stdout: true, timeout: @lsof_timeout_ms) do
          {output, _exit_code} ->
            ports = parse_lsof_output(output)
            {:ok, ports}
        end
    end
  rescue
    e ->
      Logger.warning("[PortsMonitor] lsof scan failed: #{Exception.message(e)}")
      {:ok, []}
  end

  # Parse lsof -P output lines. Sample:
  # COMMAND  PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
  # node    1234 user   25u  IPv4 0x...  0t0  TCP *:3000 (LISTEN)
  # node    1234 user   26u  IPv6 0x...  0t0  TCP *:3000 (LISTEN)
  @line_regex ~r/(\w+)\s+(\d+)\s+\S+\s+\S+\s+(IPv4|IPv6)\s+\S+\s+\S+\s+(TCP|UDP)\s+\S+:(\d+)\s*(?:\((\w+)\))?/

  defp parse_lsof_output(output) do
    output
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.flat_map(fn line ->
      case Regex.run(@line_regex, line) do
        [_, _cmd, pid_str, _ipv, proto, port_str, state_str] ->
          pid = String.to_integer(pid_str)
          port = String.to_integer(port_str)
          state = if state_str == "", do: "LISTEN", else: state_str

          [%{port: port, proto: proto, state: state, pid: pid}]

        _ ->
          []
      end
    end)
    |> Enum.uniq_by(fn %{port: port, proto: proto} -> {port, proto} end)
    |> Enum.sort_by(& &1.port)
  end
end
