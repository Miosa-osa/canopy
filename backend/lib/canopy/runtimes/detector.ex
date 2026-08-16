defmodule Canopy.Runtimes.Detector do
  @moduledoc """
  Server-side runtime detection for the full coding-agent ecosystem.

  `detect_all/0` probes the host machine for every CLI runtime in the catalog:
  - CLI agents: runs `System.find_executable/1`, then `{binary} --version` with a 2s timeout
  - Hosted API runtimes: always `installed: true` (no binary needed)
  - Ollama: additionally probes `http://localhost:11434/api/tags` for running server + models

  Results are written back via `Canopy.Runtimes.upsert_from_detection/1`.
  Wire into the existing `POST /api/v1/runtimes/detect` endpoint by calling this
  module server-side rather than waiting for the Tauri sidecar.
  """

  require Logger

  alias Canopy.Runtimes

  # Maps runtime type slug → actual binary name when they differ.
  @binary_map %{
    "continue-cli" => "continue",
    "gpt-engineer" => "gpte",
    "cursor-agent" => "cursor-agent",
    "gemini-cli" => "gemini",
    "smol-developer" => "smol-dev",
    "llamacpp" => "llama-cli",
    "claude-local" => "claude",
    "codex-local" => "codex",
    "gemini-local" => "gemini",
    "opencode-local" => "opencode",
    "aider-local" => "aider",
    "windsurf-local" => "windsurf",
    "opendevin" => "opendevin",
    "goose" => "goose"
  }

  @doc """
  Detects all CLI runtimes in the catalog and updates the database.

  Returns a list of `{:ok, runtime}` or `{:error, reason}` tuples.
  """
  @spec detect_all() :: [{:ok, Canopy.Runtimes.Runtime.t()} | {:error, term()}]
  def detect_all do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, all_runtimes} = Runtimes.list()

    all_runtimes
    |> Enum.map(fn runtime ->
      # Start with required fields so changeset validation always passes,
      # then merge in detection-derived fields.
      base = %{type: runtime.type, kind: runtime.kind, name: runtime.name}
      detection = detect_one(runtime.type, runtime.kind, now)
      Runtimes.upsert_from_detection(Map.merge(base, detection))
    end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec detect_one(String.t(), String.t(), DateTime.t()) :: map()
  defp detect_one(type, "api", now) do
    %{
      type: type,
      kind: "api",
      installed: true,
      last_detected_at: now
    }
  end

  defp detect_one("ollama", "cli", now) do
    base = detect_cli_binary("ollama", now)

    extra_config =
      if base.installed do
        probe_ollama_server()
      else
        %{}
      end

    Map.update(base, :config, extra_config, &Map.merge(&1, extra_config))
  end

  defp detect_one(type, "cli", now) do
    detect_cli_binary(type, now)
  end

  defp detect_one(type, _kind, now) do
    %{type: type, last_detected_at: now}
  end

  # Common install prefixes not always in beam's $PATH — we expand ~ at runtime.
  @extra_path_prefixes ["~/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]

  @spec detect_cli_binary(String.t(), DateTime.t()) :: map()
  defp detect_cli_binary(type, now) do
    binary = binary_for(type)

    case resolve_binary(binary) do
      nil ->
        %{
          type: type,
          kind: "cli",
          installed: false,
          binary_path: nil,
          version: nil,
          last_detected_at: now
        }

      path ->
        version = probe_version(path)

        %{
          type: type,
          kind: "cli",
          installed: true,
          binary_path: path,
          version: version,
          last_detected_at: now
        }
    end
  end

  # Tries $PATH first, then common user install prefixes that beam's $PATH often
  # misses (~/.local/bin, /opt/homebrew/bin). Only returns paths whose target
  # exists — stale symlinks count as missing.
  @spec resolve_binary(String.t()) :: String.t() | nil
  defp resolve_binary(binary) do
    case System.find_executable(binary) do
      nil -> find_in_prefixes(binary)
      path -> if File.exists?(path), do: path, else: find_in_prefixes(binary)
    end
  end

  @spec find_in_prefixes(String.t()) :: String.t() | nil
  defp find_in_prefixes(binary) do
    @extra_path_prefixes
    |> Enum.map(&Path.expand/1)
    |> Enum.map(&Path.join(&1, binary))
    |> Enum.find(&File.exists?/1)
  end

  @spec probe_version(String.t()) :: String.t() | nil
  defp probe_version(binary_path) do
    task =
      Task.async(fn ->
        System.cmd(binary_path, ["--version"], stderr_to_stdout: true)
      end)

    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        output
        |> String.split("\n")
        |> List.first("")
        |> String.trim()
        |> then(&if(&1 == "", do: nil, else: &1))

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  @spec probe_ollama_server() :: map()
  defp probe_ollama_server do
    url = "http://localhost:11434/api/tags"

    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, 2_000}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"models" => models}} when is_list(models) ->
            model_names = Enum.map(models, & &1["name"])
            %{server_url: "http://localhost:11434", models: model_names, server_running: true}

          _ ->
            %{server_url: "http://localhost:11434", server_running: true}
        end

      _ ->
        %{server_url: "http://localhost:11434", server_running: false}
    end
  rescue
    _ -> %{server_url: "http://localhost:11434", server_running: false}
  end

  @spec binary_for(String.t()) :: String.t()
  defp binary_for(type), do: Map.get(@binary_map, type, type)
end
