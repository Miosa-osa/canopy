defmodule Canopy.Agents.SpawnPipeline do
  @moduledoc """
  Ten-stage pipeline that fully initialises every agent spawn.

  Replaces the ad-hoc pty start scattered across `Sessions.create/1`,
  `SessionTerminalChannel.join/3`, and `Agents.Tools` — all three callers
  now delegate here.

  ## Stages

  1. `:validate`         — session row exists, runtime is known, workspace root resolves
  2. `:ensure_run`       — create or reuse a `Canopy.Runs.Run` tied to the session
  3. `:ensure_worktree`  — create/reuse git worktree when workspace is a git repo
  4. `:compose_prompt`   — build composed skill markdown via `Skills.Injection.compose/1`
  5. `:build_env`        — assemble CANOPY_* vars + runtime creds via Auth.session_env_for
  6. `:resolve_command`  — look up binary_path + default_args + inject system-prompt flag
  7. `:start_pty`        — start PtyBridge under DynamicSupervisor (idempotent)
  8. `:attach_scrollback`— ensure ScrollbackStore is running and attached
  9. `:mark_running`     — Sessions.update_status(:running), Runs.mark_running(os_pid)
  10. `:broadcast`        — PubSub event on `live_runs:workspace:<slug>`

  Returns `{:ok, spawn_result()}` or `{:error, stage_atom, reason}`.
  Failed stages are rolled back where safe (run → :failed, session → :failed).
  Worktrees are left in place for inspection.

  ## Options

  - `wake_reason:` `"user_prompt" | "approval" | "schedule" | "resume"` (default `"user_prompt"`)
  - `approval_id:` UUID | nil
  - `parent_session_id:` UUID | nil
  - `agent:` pre-loaded `Agent.t()` | nil  (skips DB lookup for perf when caller has it)
  """

  require Logger

  alias Canopy.Agents
  alias Canopy.Runs
  alias Canopy.Runtimes
  alias Canopy.Runtimes.Auth
  alias Canopy.Sessions
  alias Canopy.Sessions.{PtyBridge, ScrollbackSupervisor, Session, WorktreeManager}
  alias Canopy.Skills.Injection

  @type spawn_result :: %{
          run: Runs.Run.t(),
          session: Session.t(),
          os_pid: integer(),
          worktree: String.t() | nil
        }

  @type stage ::
          :validate
          | :ensure_run
          | :ensure_worktree
          | :snapshot_context
          | :compose_prompt
          | :build_env
          | :resolve_command
          | :start_pty
          | :attach_scrollback
          | :mark_running
          | :broadcast

  @env_snapshot_whitelist ~w(PATH HOME NODE_VERSION RUBY_VERSION PYTHON_VERSION
                             ELIXIR_VERSION MIX_ENV ASDF_DIR)

  @canopy_api_base "http://localhost:9190/api/v1"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Executes the full agent spawn pipeline for `session`.

  Idempotent: if a pty is already registered for `session.id`, returns the
  existing run + pty without re-spawning.
  """
  @spec spawn(Session.t(), keyword()) ::
          {:ok, spawn_result()} | {:error, stage(), term()}
  def spawn(%Session{} = session, opts \\ []) do
    wake_reason = Keyword.get(opts, :wake_reason, "user_prompt")
    approval_id = Keyword.get(opts, :approval_id)
    parent_session_id = Keyword.get(opts, :parent_session_id)
    preloaded_agent = Keyword.get(opts, :agent)

    Logger.info("[SpawnPipeline] starting session_id=#{session.id} wake_reason=#{wake_reason}")

    with {:ok, {session, runtime}} <- stage(:validate, fn -> validate(session) end, nil, nil),
         {:ok, run} <- stage(:ensure_run, fn -> ensure_run(session, wake_reason) end, nil, nil),
         {:ok, worktree} <-
           stage(:ensure_worktree, fn -> ensure_worktree(session) end, run, session),
         {:ok, _snapshot} <-
           stage(
             :snapshot_context,
             fn -> snapshot_context(run, worktree, session) end,
             run,
             session
           ),
         {:ok, prompt_text} <-
           stage(
             :compose_prompt,
             fn -> compose_prompt(session, preloaded_agent) end,
             run,
             session
           ),
         {:ok, env} <-
           stage(
             :build_env,
             fn ->
               build_env(session, run, worktree, wake_reason, approval_id, parent_session_id)
             end,
             run,
             session
           ),
         {:ok, {command, args}} <-
           stage(
             :resolve_command,
             fn -> resolve_command(session, runtime, prompt_text) end,
             run,
             session
           ),
         {:ok, os_pid} <-
           stage(
             :start_pty,
             fn -> start_pty(session, command, args, env, worktree) end,
             run,
             session
           ),
         :ok <-
           stage(:attach_scrollback, fn -> attach_scrollback(session.id) end, run, session),
         {:ok, session} <-
           stage(:mark_running, fn -> mark_running(session, run, os_pid) end, run, session),
         :ok <- stage(:broadcast, fn -> broadcast(session) end, run, session) do
      {:ok,
       %{
         run: run,
         session: session,
         os_pid: os_pid,
         worktree: worktree
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage wrappers
  # ---------------------------------------------------------------------------

  # Wraps each stage: logs entry, handles errors, rolls back on failure.
  @spec stage(stage(), (-> term()), Runs.Run.t() | nil, Session.t() | nil) ::
          {:ok, term()} | {:error, stage(), term()}
  defp stage(name, fun, run, session) do
    Logger.debug("[SpawnPipeline] stage=#{name} session_id=#{session_id_for(session)}")

    case fun.() do
      {:ok, _} = ok ->
        ok

      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "[SpawnPipeline] failed stage=#{name} session_id=#{session_id_for(session)} reason=#{inspect(reason)}"
        )

        rollback(name, run, session, reason)
        {:error, name, reason}

      other ->
        Logger.warning(
          "[SpawnPipeline] unexpected result stage=#{name} session_id=#{session_id_for(session)}: #{inspect(other)}"
        )

        rollback(name, run, session, other)
        {:error, name, other}
    end
  end

  defp session_id_for(nil), do: "unknown"
  defp session_id_for(%Session{id: id}), do: id

  # ---------------------------------------------------------------------------
  # Stage 1: validate
  # ---------------------------------------------------------------------------

  @spec validate(Session.t()) :: {:ok, {Session.t(), map()}} | {:error, term()}
  defp validate(session) do
    case Runtimes.get_by_type(session.runtime_type) do
      {:ok, runtime} ->
        {:ok, {session, runtime}}

      {:error, :not_found} ->
        {:error, {:unknown_runtime, session.runtime_type}}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 2: ensure_run
  # ---------------------------------------------------------------------------

  @spec ensure_run(Session.t(), String.t()) :: {:ok, Runs.Run.t()} | {:error, term()}
  defp ensure_run(session, wake_reason) do
    # Idempotent: reuse existing run for this session if one is already running.
    existing =
      Runs.list(%{session_id: session.id, status: "running"})
      |> List.first()

    if existing do
      Logger.debug(
        "[SpawnPipeline] reusing existing run short_id=#{existing.short_id} session_id=#{session.id}"
      )

      {:ok, existing}
    else
      Runs.start(%{
        session_id: session.id,
        agent_slug: session.agent_slug,
        workspace_slug: session.workspace_slug || "default",
        wake_reason: wake_reason
      })
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 3: ensure_worktree
  # ---------------------------------------------------------------------------

  @spec ensure_worktree(Session.t()) :: {:ok, String.t() | nil} | {:error, term()}
  defp ensure_worktree(session) do
    # Resolve root_path for the session's workspace so ensure_for can check git.
    root_path =
      case session.workspace_slug do
        slug when is_binary(slug) and slug != "" -> resolve_workspace_root(slug)
        _ -> nil
      end

    # Build a map that WorktreeManager.ensure_for/1 understands.
    session_map =
      session
      |> Map.from_struct()
      |> Map.put(:root_path, root_path)

    case WorktreeManager.ensure_for(session_map) do
      {:ok, %{path: path}} ->
        {:ok, path}

      {:skip, :not_git_repo} ->
        {:ok, nil}

      {:error, reason} ->
        Logger.warning(
          "[SpawnPipeline] worktree creation failed session_id=#{session.id}: #{inspect(reason)} — proceeding without worktree"
        )

        {:ok, nil}
    end
  end

  @spec resolve_workspace_root(String.t() | nil) :: String.t() | nil
  defp resolve_workspace_root(nil), do: nil
  defp resolve_workspace_root(""), do: nil

  defp resolve_workspace_root(slug) do
    case Canopy.Workspaces.get_by_slug(slug) do
      {:ok, workspace} -> workspace.root_path
      _ -> nil
    end
  end

  # erlexec does not expand ~ in the {:cd, path} option. Do it here.
  @spec expand_home(String.t() | nil) :: String.t()
  defp expand_home(nil), do: System.user_home!() || "/tmp"
  defp expand_home(""), do: System.user_home!() || "/tmp"
  defp expand_home("~"), do: System.user_home!() || "/tmp"

  defp expand_home("~/" <> rest) do
    Path.join(System.user_home!() || "/tmp", rest)
  end

  defp expand_home(path), do: path

  # Fall back to workspace root (then /tmp) if the resolved path doesn't exist.
  # Prevents erlexec from failing with ENOENT on a stale/invalid cwd.
  @spec ensure_dir_exists(String.t(), String.t() | nil) :: String.t()
  defp ensure_dir_exists(path, workspace_slug) do
    cond do
      File.dir?(path) ->
        path

      true ->
        fallback =
          resolve_workspace_root(workspace_slug)
          |> expand_home()

        cond do
          is_binary(fallback) and File.dir?(fallback) -> fallback
          true -> "/tmp"
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 4 (new): snapshot_context — capture commit SHA + env fingerprint
  # ---------------------------------------------------------------------------

  @spec snapshot_context(Runs.Run.t(), String.t() | nil, Session.t()) ::
          {:ok, map()} | {:error, term()}
  defp snapshot_context(run, worktree, session) do
    worktree_path = worktree || resolve_workspace_root(session.workspace_slug) || ""

    {commit_sha, branch} =
      if worktree_path != "" and File.dir?(worktree_path) do
        sha =
          case System.cmd("git", ["-C", worktree_path, "rev-parse", "HEAD"],
                 stderr_to_stdout: false
               ) do
            {output, 0} -> String.trim(output)
            _ -> nil
          end

        br =
          case System.cmd("git", ["-C", worktree_path, "branch", "--show-current"],
                 stderr_to_stdout: false
               ) do
            {output, 0} -> String.trim(output)
            _ -> session.branch
          end

        {sha, br}
      else
        {nil, session.branch}
      end

    env_hash =
      @env_snapshot_whitelist
      |> Enum.flat_map(fn key ->
        case System.get_env(key) do
          nil -> []
          val -> ["#{key}=#{val}"]
        end
      end)
      |> Enum.sort()
      |> Enum.join("\n")
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    snapshot = %{
      commit_sha: commit_sha,
      branch: branch,
      base_branch: session.base_branch,
      env_hash: env_hash,
      worktree_path: worktree_path,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    Runs.get(run.id)
    |> case do
      {:ok, r} ->
        r
        |> Runs.Run.changeset(%{context_snapshot: snapshot})
        |> Canopy.Repo.update()
        |> case do
          {:ok, _} -> {:ok, snapshot}
          {:error, _} -> {:ok, snapshot}
        end

      _ ->
        {:ok, snapshot}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 5: compose_prompt
  # ---------------------------------------------------------------------------

  @spec compose_prompt(Session.t(), map() | nil) :: {:ok, String.t()} | {:error, term()}
  defp compose_prompt(session, preloaded_agent) do
    agent_slug = session.agent_slug

    if is_nil(agent_slug) or agent_slug == "" do
      {:ok, ""}
    else
      agent =
        preloaded_agent ||
          case Agents.get_by_slug(agent_slug) do
            {:ok, a} -> a
            {:error, _} -> nil
          end

      if agent do
        persona = agent.persona_markdown || ""
        skills = Injection.compose(agent)
        local_manifest = local_config_manifest(agent.config || %{})

        prompt =
          [persona, skills, local_manifest]
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("\n\n")

        {:ok, prompt}
      else
        Logger.warning(
          "[SpawnPipeline] agent_slug=#{agent_slug} not found — spawning without skills"
        )

        {:ok, ""}
      end
    end
  end

  defp local_config_manifest(config) when is_map(config) do
    skills = list_config(config, "skills")
    tools = list_config(config, "tools")
    context_tier = Map.get(config, "context_tier")

    sections =
      []
      |> maybe_manifest_section("Workspace-declared skills", skills)
      |> maybe_manifest_section("Workspace-declared tools", tools)
      |> maybe_context_tier(context_tier)

    case sections do
      [] -> ""
      _ -> Enum.join(["## Workspace Agent Configuration" | Enum.reverse(sections)], "\n\n")
    end
  end

  defp local_config_manifest(_), do: ""

  defp list_config(config, key) do
    case Map.get(config, key) do
      values when is_list(values) -> Enum.map(values, &to_string/1)
      value when is_binary(value) -> [value]
      _ -> []
    end
  end

  defp maybe_manifest_section(sections, _title, []), do: sections

  defp maybe_manifest_section(sections, title, values) do
    lines = Enum.map_join(values, "\n", &"- #{&1}")
    ["### #{title}\n\n#{lines}" | sections]
  end

  defp maybe_context_tier(sections, nil), do: sections
  defp maybe_context_tier(sections, ""), do: sections
  defp maybe_context_tier(sections, tier), do: ["### Context tier\n\n#{tier}" | sections]

  # ---------------------------------------------------------------------------
  # Stage 5: build_env
  # ---------------------------------------------------------------------------

  @spec build_env(
          Session.t(),
          Runs.Run.t(),
          String.t() | nil,
          String.t(),
          String.t() | nil,
          String.t() | nil
        ) :: {:ok, [{String.t(), String.t()}]} | {:error, term()}
  defp build_env(session, run, worktree, wake_reason, approval_id, parent_session_id) do
    # Runtime creds (ANTHROPIC_API_KEY, OPENAI_API_KEY, etc.)
    cred_env =
      case Auth.session_env_for(session.runtime_type) do
        {:ok, map} -> map
        {:error, _} -> %{}
      end

    # Workspace root for PATH injection of priv/agent_helpers
    priv_helpers = priv_agent_helpers_path()

    worktree_path = worktree || resolve_workspace_root(session.workspace_slug) || ""
    branch = session.branch || ""

    canopy_vars =
      %{
        "CANOPY_SESSION_ID" => session.id,
        "CANOPY_RUN_ID" => run.short_id,
        "CANOPY_API_BASE" => @canopy_api_base,
        "CANOPY_WAKE_REASON" => wake_reason,
        "TERM" => "xterm-256color",
        "COLORTERM" => "truecolor"
      }
      |> put_if_present("CANOPY_WORKSPACE_SLUG", session.workspace_slug)
      |> put_if_present("CANOPY_WORKTREE_PATH", worktree_path)
      |> put_if_present("CANOPY_BRANCH", branch)
      |> put_if_present("CANOPY_APPROVAL_ID", approval_id)
      |> put_if_present("CANOPY_PARENT_SESSION_ID", parent_session_id)

    # MIOSA sandbox URL if available
    miosa_vars =
      if is_binary(session.miosa_sandbox_url) and session.miosa_sandbox_url != "" do
        %{"CANOPY_MIOSA_SANDBOX_URL" => session.miosa_sandbox_url}
      else
        %{}
      end

    # Prepend priv/agent_helpers to PATH so `canopy` CLI resolves correctly.
    path_prefix =
      if priv_helpers do
        existing_path = System.get_env("PATH", "")
        %{"PATH" => "#{priv_helpers}:#{existing_path}"}
      else
        %{}
      end

    merged =
      cred_env
      |> Map.merge(canopy_vars)
      |> Map.merge(miosa_vars)
      |> Map.merge(path_prefix)

    env_list = Enum.map(merged, fn {k, v} -> {k, to_string(v)} end)
    {:ok, env_list}
  end

  @spec put_if_present(map(), String.t(), String.t() | nil) :: map()
  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  @spec priv_agent_helpers_path() :: String.t() | nil
  defp priv_agent_helpers_path do
    path = :code.priv_dir(:canopy) |> to_string() |> Path.join("agent_helpers")

    if File.dir?(path), do: path, else: nil
  end

  # ---------------------------------------------------------------------------
  # Stage 6: resolve_command
  # ---------------------------------------------------------------------------

  @spec resolve_command(Session.t(), map(), String.t()) ::
          {:ok, {String.t(), [String.t()]}} | {:error, term()}
  defp resolve_command(_session, runtime, prompt_text) do
    whitelist = Application.get_env(:canopy, :terminal_command_whitelist, [])

    binary_path = runtime.binary_path
    runtime_type = runtime.type

    if is_nil(binary_path) or binary_path == "" do
      {:error, {:no_binary_path, runtime_type}}
    else
      if Enum.empty?(whitelist) or binary_path in whitelist do
        base_args = default_args_for(runtime_type)
        prompt_args = prompt_injection_args(runtime_type, prompt_text)
        {:ok, {binary_path, base_args ++ prompt_args}}
      else
        Logger.warning(
          "[SpawnPipeline] binary_path=#{binary_path} not in whitelist — falling back to bash"
        )

        {:ok, {"/bin/bash", []}}
      end
    end
  end

  # Per-runtime default args.
  @spec default_args_for(String.t()) :: [String.t()]
  defp default_args_for("claude-local"), do: ["--dangerously-skip-permissions"]
  defp default_args_for("codex-local"), do: ["--yes"]
  defp default_args_for(_), do: []

  # Injects the composed system prompt for runtimes that accept it.
  #
  # claude: --append-system-prompt "<text>"  (confirmed via `claude --help`)
  # codex:  no system-prompt flag — log TODO
  # gemini: not installed in this environment — skip
  @spec prompt_injection_args(String.t(), String.t()) :: [String.t()]
  defp prompt_injection_args(_runtime_type, ""), do: []

  defp prompt_injection_args("claude-local", prompt_text) do
    ["--append-system-prompt", prompt_text]
  end

  defp prompt_injection_args("codex-local", _prompt_text) do
    Logger.info(
      "[SpawnPipeline] TODO: codex-local has no system-prompt flag — skills documented in docs/ only"
    )

    []
  end

  defp prompt_injection_args("gemini-local", _prompt_text) do
    Logger.info(
      "[SpawnPipeline] TODO: gemini-local system-prompt flag not confirmed — skipping injection"
    )

    []
  end

  defp prompt_injection_args(_other, _prompt_text), do: []

  # ---------------------------------------------------------------------------
  # Stage 7: start_pty
  # ---------------------------------------------------------------------------

  @spec start_pty(
          Session.t(),
          String.t(),
          [String.t()],
          [{String.t(), String.t()}],
          String.t() | nil
        ) ::
          {:ok, integer()} | {:error, term()}
  defp start_pty(session, command, args, env, worktree) do
    # Resolve cwd with ~ expansion. erlexec does NOT expand ~ — passing it raw
    # causes the child process to fail with ENOENT. Prefer worktree > workspace
    # root > session.cwd > home.
    cwd =
      (worktree || resolve_workspace_root(session.workspace_slug) || session.cwd || "/tmp")
      |> expand_home()
      |> ensure_dir_exists(session.workspace_slug)

    # Idempotent: if a bridge is already running, return its os_pid via :sys.get_state.
    case Registry.lookup(Canopy.Sessions.PtyRegistry, session.id) do
      [{pid, _}] ->
        os_pid = pid_to_os_pid(pid)

        Logger.debug(
          "[SpawnPipeline] pty already running session_id=#{session.id} os_pid=#{inspect(os_pid)}"
        )

        {:ok, os_pid}

      [] ->
        case DynamicSupervisor.start_child(
               Canopy.Sessions.PtySupervisor,
               {PtyBridge, {session.id, command, args, env, cwd}}
             ) do
          {:ok, pid} ->
            {:ok, pid_to_os_pid(pid)}

          {:error, {:already_started, pid}} ->
            {:ok, pid_to_os_pid(pid)}

          {:error, reason} ->
            {:error, {:pty_start_failed, reason}}
        end
    end
  end

  # Reads os_pid from the PtyBridge GenServer state via :sys.get_state/2.
  # PtyBridge is not touched (concurrent agent #177 owns it), so we avoid
  # adding a new handle_call callback. Falls back to 0 on timeout.
  @spec pid_to_os_pid(pid()) :: integer()
  defp pid_to_os_pid(pid) do
    case :sys.get_state(pid, 2_000) do
      %{os_pid: os_pid} when is_integer(os_pid) -> os_pid
      _ -> 0
    end
  rescue
    _ -> 0
  end

  # ---------------------------------------------------------------------------
  # Stage 8: attach_scrollback
  # ---------------------------------------------------------------------------

  @spec attach_scrollback(binary()) :: :ok | {:error, term()}
  defp attach_scrollback(session_id) do
    case ScrollbackSupervisor.start_child(session_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 9: mark_running
  # ---------------------------------------------------------------------------

  @spec mark_running(Session.t(), Runs.Run.t(), integer()) ::
          {:ok, Session.t()} | {:error, term()}
  defp mark_running(session, run, os_pid) do
    # Best-effort: don't fail the pipeline if status transition is already done.
    Sessions.update_status(session.id, "running")
    Runs.mark_running(run.id, os_pid)

    case Sessions.get(session.id) do
      {:ok, updated} -> {:ok, updated}
      {:error, _} -> {:ok, session}
    end
  end

  # ---------------------------------------------------------------------------
  # Stage 10: broadcast
  # ---------------------------------------------------------------------------

  @spec broadcast(Session.t()) :: :ok
  defp broadcast(session) do
    workspace_slug = session.workspace_slug || "default"
    topic = "live_runs:workspace:#{workspace_slug}"

    Phoenix.PubSub.broadcast(
      Canopy.PubSub,
      topic,
      {:session_spawned, %{session_id: session.id, workspace_slug: workspace_slug}}
    )

    :ok
  end

  # ---------------------------------------------------------------------------
  # Rollback
  # ---------------------------------------------------------------------------

  @spec rollback(stage(), Runs.Run.t() | nil, Session.t() | nil, term()) :: :ok
  defp rollback(failed_stage, run, session, reason) do
    Logger.warning(
      "[SpawnPipeline] rolling back failed_stage=#{failed_stage} reason=#{inspect(reason)}"
    )

    if run do
      Runs.mark_finished(
        run.id,
        "failed",
        %{},
        "spawn_pipeline:#{failed_stage}:#{inspect(reason)}"
      )
    end

    if session do
      Sessions.update_status(session.id, "failed")
    end

    :ok
  end
end
