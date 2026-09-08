defmodule Canopy.Runtimes.Auth.Detector do
  @moduledoc """
  Per-runtime auth detection.

  Given a Runtime record with an `auth_profile`, runs detection in priority order:
    1. subscription_detect — checks a file path or env var for CLI-managed creds
    2. cli_login         — runs `<binary> auth status` and pattern-matches stdout
    3. api_key           — checks Canopy.Runtimes.Auth for a stored credential

  Returns the first successfully-detected method plus full state for all methods.

  Injectable checkers make unit-testing possible without global FS mocks:
    - `file_checker/1` — defaults to `File.exists?/1`
    - `cmd_runner/2`   — defaults to running `System.cmd/3` with a 2s timeout
  """

  require Logger

  alias Canopy.Runtimes.Auth
  alias Canopy.Runtimes.Runtime

  @type method :: String.t()

  @type detection_result :: %{
          type: String.t(),
          methods: [method()],
          subscription_detected: boolean() | nil,
          cli_logged_in: boolean() | nil,
          api_key_stored: boolean() | nil,
          active_method: method() | nil,
          session_env: [String.t()]
        }

  @doc """
  Detects auth state for the given runtime using its `auth_profile`.

  Optional keyword args (used in tests):
    - `:file_checker` — `(path :: String.t() -> boolean())`; defaults to `File.exists?/1`
    - `:cmd_runner`   — `(binary :: String.t(), args :: [String.t()] -> {:ok, String.t()} | :error)`;
                        defaults to `System.cmd/3` with 2s timeout

  Returns a map matching the `/auth/status` response shape.
  """
  @spec detect(Runtime.t(), keyword()) :: detection_result()
  def detect(%Runtime{} = runtime, opts \\ []) do
    file_checker = Keyword.get(opts, :file_checker, &File.exists?/1)
    cmd_runner = Keyword.get(opts, :cmd_runner, &default_cmd_runner/2)

    profile = runtime.auth_profile || %{}
    methods = Map.get(profile, "methods", [])

    subscription_detected = detect_subscription(profile, file_checker)
    cli_logged_in = detect_cli_login(profile, cmd_runner, runtime.binary_path)
    api_key_stored = detect_api_key(runtime.type)

    active_method =
      Enum.find(methods, fn
        "subscription_detect" -> subscription_detected == true
        "cli_login" -> cli_logged_in == true
        "api_key" -> api_key_stored == true
        _ -> false
      end)

    session_env = session_env_vars(profile, active_method)

    %{
      type: runtime.type,
      methods: methods,
      subscription_detected: subscription_detected,
      cli_logged_in: cli_logged_in,
      api_key_stored: api_key_stored,
      active_method: active_method,
      session_env: session_env
    }
  end

  # ---------------------------------------------------------------------------
  # Private — detection strategies
  # ---------------------------------------------------------------------------

  @spec detect_subscription(map(), (String.t() -> boolean())) :: boolean() | nil
  defp detect_subscription(profile, file_checker) do
    case Map.get(profile, "subscription_detect") do
      nil ->
        nil

      config ->
        file_found =
          case Map.get(config, "check_path") do
            nil ->
              false

            raw_path ->
              path = Path.expand(raw_path)
              file_checker.(path)
          end

        env_found =
          case Map.get(config, "alt_env_var") do
            nil -> false
            var -> System.get_env(var) not in [nil, ""]
          end

        file_found or env_found
    end
  end

  @spec detect_cli_login(
          map(),
          (String.t(), [String.t()] -> {:ok, String.t()} | :error),
          String.t() | nil
        ) :: boolean() | nil
  defp detect_cli_login(profile, cmd_runner, binary_path) do
    case Map.get(profile, "cli_login") do
      nil ->
        nil

      config ->
        detect_cmd = Map.get(config, "detect_command", "")
        success_pattern = Map.get(config, "detect_success_pattern", "")

        if detect_cmd == "" or success_pattern == "" do
          nil
        else
          parts = String.split(detect_cmd, " ", trim: true)
          args = Enum.drop(parts, 1)
          # Prefer the runtime's stored binary_path (detected at boot from $PATH)
          # over a re-resolve inside the beam process, which has a stripped $PATH
          # that often misses ~/.local/bin.
          binary = binary_path || List.first(parts)

          case cmd_runner.(binary, args) do
            {:ok, output} -> String.contains?(output, success_pattern)
            :error -> false
          end
        end
    end
  end

  @spec detect_api_key(String.t()) :: boolean()
  defp detect_api_key(runtime_type) do
    case Auth.get_credential(runtime_type) do
      {:ok, _cred} -> true
      {:error, :not_found} -> false
    end
  end

  @spec session_env_vars(map(), method() | nil) :: [String.t()]
  defp session_env_vars(_profile, nil), do: []

  defp session_env_vars(profile, method) when method in ["subscription_detect", "cli_login"] do
    # CLI-managed auth — we don't inject env vars. The CLI uses its own stored creds.
    # Optionally surface any env var the CLI itself exposes for observation.
    case Map.get(profile, "subscription_detect") do
      %{"alt_env_var" => var} when is_binary(var) -> [var]
      _ -> []
    end
  end

  defp session_env_vars(profile, "api_key") do
    case Map.get(profile, "api_key") do
      %{"env_var" => var} when is_binary(var) -> [var]
      _ -> []
    end
  end

  defp session_env_vars(_profile, _method), do: []

  # ---------------------------------------------------------------------------
  # Private — default command runner
  # ---------------------------------------------------------------------------

  @spec default_cmd_runner(String.t() | nil, [String.t()]) :: {:ok, String.t()} | :error
  defp default_cmd_runner(nil, _args), do: :error

  defp default_cmd_runner(binary, args) do
    # binary may be an absolute path (preferred, from runtime.binary_path) or a
    # bare command name. For absolute paths, use directly. For bare names, fall
    # back to find_executable which honors the beam process's $PATH.
    path =
      cond do
        is_binary(binary) and String.starts_with?(binary, "/") -> binary
        true -> System.find_executable(binary || "")
      end

    case path do
      nil ->
        :error

      resolved ->
        # Wrap in a Task so the 2s timeout actually applies — System.cmd has no
        # timeout option. If the subprocess hangs longer, we kill the task.
        task =
          Task.async(fn ->
            try do
              System.cmd(resolved, args, stderr_to_stdout: true)
            rescue
              _ -> :error
            end
          end)

        case Task.yield(task, 2_000) || Task.shutdown(task, :brutal_kill) do
          {:ok, {output, _exit_code}} -> {:ok, output}
          _ -> :error
        end
    end
  rescue
    _ -> :error
  end
end
