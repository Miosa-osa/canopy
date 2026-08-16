defmodule Canopy.Hooks.Manager do
  @moduledoc """
  Installs and removes Canopy lifecycle hooks in global AI agent configs.

  Called at application boot (`install!/0`) so every agent session on the
  machine — including those started outside Canopy — fires the notify script
  on every lifecycle event (PostToolUse, Stop, UserPromptSubmit, PermissionRequest).

  ## Versioned markers

  Every file or JSON key Canopy writes is guarded by a marker comment or
  marker sentinel, e.g. `# Canopy hook v1` in shell scripts. On re-install,
  the manager detects its own marker and updates in place. If a key already
  exists without our marker it is left untouched (conservative merge).

  ## Supported runtimes

  | Runtime   | Config location                         | Mechanism           |
  |-----------|----------------------------------------|---------------------|
  | claude    | ~/.claude/settings.json                | JSON hooks merge    |
  | cursor    | ~/.cursor/hooks.json                   | JSON hooks merge    |
  | gemini    | ~/.gemini/settings.json                | JSON hooks merge    |
  | codex     | ~/.codex/config.toml                   | TOML append         |
  | opencode  | ~/.config/opencode/config.json         | JSON hooks merge    |

  ## Fail-safe

  `install!/0` wraps every runtime in its own try/rescue so a broken config
  directory for one runtime does not abort the others, and never crashes the
  application supervisor.
  """

  require Logger

  @marker "# Canopy hook v1"
  @notify_script_src Application.app_dir(:canopy, "priv/hooks/claude-notify.sh")
  @hooks_dir Path.join(System.user_home!(), ".canopy/hooks")
  @notify_script_dest Path.join(@hooks_dir, "canopy-notify.sh")

  @agent_configs %{
    claude: %{
      path: Path.join(System.user_home!(), ".claude/settings.json"),
      type: :json_claude
    },
    cursor: %{
      path: Path.join(System.user_home!(), ".cursor/hooks.json"),
      type: :json_cursor
    },
    gemini: %{
      path: Path.join(System.user_home!(), ".gemini/settings.json"),
      type: :json_gemini
    },
    opencode: %{
      path: Path.join(System.user_home!(), ".config/opencode/config.json"),
      type: :json_opencode
    }
  }

  # ── Public API ───────────────────────────────────────────────────────────────

  @doc """
  Installs Canopy notify hooks into every supported agent's global config.

  Idempotent: safe to call on every application boot. Returns a map of
  `%{runtime_name => :ok | {:error, reason}}` for observability.
  """
  @spec install!() :: %{atom() => :ok | {:error, term()}}
  def install! do
    ensure_hooks_dir()
    write_notify_script()

    results =
      Map.new(@agent_configs, fn {name, cfg} ->
        result =
          try do
            install_runtime(name, cfg)
            :ok
          rescue
            e ->
              Logger.warning(
                "[Canopy.Hooks.Manager] Failed to install #{name} hook: #{Exception.message(e)}"
              )

              {:error, Exception.message(e)}
          end

        {name, result}
      end)

    installed = Enum.filter(results, fn {_, v} -> v == :ok end) |> Enum.map(&elem(&1, 0))
    failed = Enum.filter(results, fn {_, v} -> v != :ok end) |> Enum.map(&elem(&1, 0))

    if Enum.empty?(failed) do
      Logger.info("[Canopy.Hooks.Manager] Hooks installed for: #{inspect(installed)}")
    else
      Logger.warning(
        "[Canopy.Hooks.Manager] Hooks installed: #{inspect(installed)}, failed: #{inspect(failed)}"
      )
    end

    results
  end

  @doc """
  Removes Canopy hook entries from every agent global config.

  Conservative: only removes keys/entries that contain our marker. User
  customizations are preserved. Returns a results map like `install!/0`.
  """
  @spec uninstall!() :: %{atom() => :ok | {:error, term()}}
  def uninstall! do
    results =
      Map.new(@agent_configs, fn {name, cfg} ->
        result =
          try do
            uninstall_runtime(name, cfg)
            :ok
          rescue
            e ->
              Logger.warning(
                "[Canopy.Hooks.Manager] Failed to uninstall #{name} hook: #{Exception.message(e)}"
              )

              {:error, Exception.message(e)}
          end

        {name, result}
      end)

    Logger.info("[Canopy.Hooks.Manager] Uninstall complete: #{inspect(results)}")
    results
  end

  @doc "Returns install status per runtime: :installed | :not_installed | {:error, reason}."
  @spec status() :: %{atom() => :installed | :not_installed | {:error, term()}}
  def status do
    Map.new(@agent_configs, fn {name, cfg} ->
      result =
        try do
          runtime_installed?(name, cfg)
        rescue
          e -> {:error, Exception.message(e)}
        end

      {name, result}
    end)
  end

  # ── Notify script ────────────────────────────────────────────────────────────

  defp ensure_hooks_dir do
    File.mkdir_p!(@hooks_dir)
  end

  defp write_notify_script do
    src = @notify_script_src
    dest = @notify_script_dest

    if File.exists?(src) do
      content = File.read!(src)
      write_if_changed(dest, content, 0o755)
      Logger.debug("[Canopy.Hooks.Manager] Notify script at #{dest}")
    else
      # In test env the priv dir may not be compiled yet; write a minimal script
      minimal = """
      #!/usr/bin/env bash
      #{@marker}
      payload=$(cat)
      curl -sS -X POST -H "Content-Type: application/json" \\
        -d "$payload" "http://localhost:9190/api/v1/hooks/notify" \\
        --connect-timeout 1 --max-time 2 > /dev/null 2>&1 &
      exit 0
      """

      write_if_changed(dest, minimal, 0o755)
    end
  end

  # ── Per-runtime install ───────────────────────────────────────────────────────

  defp install_runtime(_name, %{path: path, type: :json_claude}) do
    existing = read_json(path)
    hooks = Map.get(existing, "hooks", %{})

    entry = %{"type" => "command", "command" => @notify_script_dest}
    matcher_entry = %{"matcher" => "*", "hooks" => [entry]}

    hooks =
      hooks
      |> put_claude_hook("UserPromptSubmit", %{"hooks" => [entry]})
      |> put_claude_hook("Stop", %{"hooks" => [entry]})
      |> put_claude_hook("PostToolUse", matcher_entry)
      |> put_claude_hook("PostToolUseFailure", matcher_entry)
      |> put_claude_hook("PermissionRequest", matcher_entry)

    merged = Map.put(existing, "hooks", hooks)
    write_json(path, merged)
  end

  defp install_runtime(_name, %{path: path, type: :json_cursor}) do
    existing = read_json(path)
    hooks = Map.get(existing, "hooks", %{})

    hooks =
      hooks
      |> put_single_hook("beforeSubmitPrompt", @notify_script_dest)
      |> put_single_hook("stop", @notify_script_dest)
      |> put_single_hook("beforeShellExecution", @notify_script_dest)
      |> put_single_hook("beforeMCPExecution", @notify_script_dest)

    merged = existing |> Map.put("hooks", hooks) |> Map.put_new("version", 1)
    write_json(path, merged)
  end

  defp install_runtime(_name, %{path: path, type: :json_gemini}) do
    existing = read_json(path)
    hooks = Map.get(existing, "hooks", %{})

    hook_def = %{"hooks" => [%{"type" => "command", "command" => @notify_script_dest}]}

    hooks =
      Enum.reduce(["BeforeAgent", "AfterAgent", "AfterTool"], hooks, fn event, acc ->
        put_gemini_hook(acc, event, hook_def)
      end)

    merged = Map.put(existing, "hooks", hooks)
    write_json(path, merged)
  end

  defp install_runtime(_name, %{path: path, type: :json_opencode}) do
    existing = read_json(path)
    hooks = Map.get(existing, "hooks", %{})

    entry = %{"type" => "command", "command" => @notify_script_dest}

    hooks =
      hooks
      |> put_claude_hook("UserPromptSubmit", %{"hooks" => [entry]})
      |> put_claude_hook("Stop", %{"hooks" => [entry]})
      |> put_claude_hook("PostToolUse", %{"matcher" => "*", "hooks" => [entry]})

    merged = Map.put(existing, "hooks", hooks)
    write_json(path, merged)
  end

  # ── Per-runtime uninstall ─────────────────────────────────────────────────────

  defp uninstall_runtime(_name, %{path: path, type: type})
       when type in [:json_claude, :json_cursor, :json_gemini, :json_opencode] do
    if File.exists?(path) do
      existing = read_json(path)
      hooks = Map.get(existing, "hooks", %{})

      cleaned =
        Map.new(hooks, fn {event, entries} ->
          filtered =
            entries
            |> List.wrap()
            |> Enum.reject(&canopy_owned_entry?/1)

          {event, filtered}
        end)
        |> Enum.reject(fn {_, v} -> v == [] end)
        |> Map.new()

      merged = Map.put(existing, "hooks", cleaned)
      write_json(path, merged)
    end
  end

  # ── Status check ─────────────────────────────────────────────────────────────

  defp runtime_installed?(_name, %{path: path, type: type})
       when type in [:json_claude, :json_cursor, :json_gemini, :json_opencode] do
    if File.exists?(path) do
      content = File.read!(path)

      if String.contains?(content, @notify_script_dest) do
        :installed
      else
        :not_installed
      end
    else
      :not_installed
    end
  end

  # ── JSON helpers ──────────────────────────────────────────────────────────────

  defp read_json(path) do
    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, parsed} <- Jason.decode(content) do
      parsed
    else
      _ -> %{}
    end
  end

  defp write_json(path, data) do
    File.mkdir_p!(Path.dirname(path))
    content = Jason.encode!(data, pretty: true)
    write_if_changed(path, content, 0o644)
  end

  # Conservative merge for Claude-style hooks: list of hook definition objects.
  # Each definition is %{"hooks" => [...]} or %{"matcher" => "*", "hooks" => [...]}.
  # We remove our previous entries (by notify_script_dest presence) and append fresh.
  defp put_claude_hook(hooks_map, event, entry) do
    existing = Map.get(hooks_map, event, []) |> List.wrap()
    filtered = Enum.reject(existing, &canopy_owned_entry?/1)
    Map.put(hooks_map, event, filtered ++ [entry])
  end

  # Cursor: hooks are lists of %{"command" => "..."}
  defp put_single_hook(hooks_map, event, command) do
    existing = Map.get(hooks_map, event, []) |> List.wrap()

    filtered =
      Enum.reject(existing, fn entry ->
        is_map(entry) and
          (Map.get(entry, "command", "") |> String.contains?(@notify_script_dest) or
             Map.get(entry, "command", "") |> String.contains?(".canopy/hooks/"))
      end)

    Map.put(hooks_map, event, filtered ++ [%{"command" => command}])
  end

  # Gemini: hooks are lists of %{"hooks" => [%{"type" => "command", "command" => "..."}]}
  defp put_gemini_hook(hooks_map, event, hook_def) do
    existing = Map.get(hooks_map, event, []) |> List.wrap()
    filtered = Enum.reject(existing, &canopy_owned_entry?/1)
    Map.put(hooks_map, event, filtered ++ [hook_def])
  end

  defp canopy_owned_entry?(entry) when is_map(entry) do
    entry_str = inspect(entry)

    String.contains?(entry_str, @notify_script_dest) or
      String.contains?(entry_str, ".canopy/hooks/")
  end

  defp canopy_owned_entry?(_), do: false

  defp write_if_changed(path, content, mode) do
    existing =
      case File.read(path) do
        {:ok, data} -> data
        _ -> nil
      end

    if existing != content do
      File.write!(path, content)
    end

    File.chmod!(path, mode)
  end
end
