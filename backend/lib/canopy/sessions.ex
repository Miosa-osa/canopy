defmodule Canopy.Sessions do
  @moduledoc """
  Public API for Canopy session management.

  A session represents one agent execution: a runtime is selected, a prompt is
  submitted, the subprocess runs, and a structured transcript is captured via
  `SessionMessage` records. Sessions form chains via `parent_session_id`.

  The triple-key resume pattern uses `id + cwd + prompt_bundle_key` to decide
  whether a session can be resumed without re-injecting skills.

  ## Governance and Budget Gates

  `create/1` evaluates governance rules and budget limits before inserting.
  Gate outcomes:

  - `:pass` — governance clean; global budget checked. Proceeds to insert on `:ok`
    or `{:warn, ...}`. Agent/workspace scoped budgets require UUID resolution
    and are enforced at the Heartbeat/billing layer.
  - `{:warn, rule}` — governance warn; logged, then proceeds to budget check.
  - `{:block, rule}` — returns `{:error, {:governance_blocked, rule}}`. No insert.
  - `{:require_approval, rule}` — inserts session with `status: "pending_approval"`,
    stores rule id in metadata, creates a governance approval record. Returns
    `{:ok, session}`.
  - `{:block, budget, spent}` — returns `{:error, {:budget_blocked, budget, spent}}`.
  - `{:warn, budget, spent}` — budget warn; logged, proceeds to insert.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Analytics.Emitter
  alias Canopy.Budgets
  alias Canopy.Governance
  alias Canopy.Repo

  alias Canopy.Sessions.{
    Persistence,
    PtyBridge,
    Redaction,
    Resume,
    ScrollbackSupervisor,
    Session,
    SessionMessage,
    WorktreeManager
  }

  require Logger

  # ---------------------------------------------------------------------------
  # Session lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new session, subject to governance and budget gates.

  When `agent_slug` and `workspace_slug` are present, looks up the most recent
  completed session for the same agent+workspace+cwd triple and pre-populates
  `external_session_id` so the adapter can pass `--resume` to the CLI.

  Gate evaluation order:
  1. `Canopy.Governance.evaluate/1` — policy rules fire first.
  2. `Canopy.Budgets.check/3` — spend checks across global, agent, and workspace
     scopes (only when governance allows the session to proceed).

  Returns:
  - `{:ok, session}` — inserted and (if applicable) queued for MIOSA sandbox.
  - `{:ok, session}` (status `"pending_approval"`) — governance requires approval.
  - `{:error, changeset}` — Ecto validation failure.
  - `{:error, {:governance_blocked, rule}}` — blocked by a governance rule.
  - `{:error, {:budget_blocked, budget, spent}}` — budget hard ceiling exceeded.
  """
  @spec create(map()) ::
          {:ok, Session.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:governance_blocked, Governance.Rule.t()}}
          | {:error, {:budget_blocked, Budgets.Budget.t(), Decimal.t()}}
  def create(attrs) do
    attrs_with_resume = maybe_inject_resume(attrs)
    context = build_governance_context(attrs_with_resume)

    case Governance.evaluate(context) do
      :pass ->
        check_budget_and_insert(attrs_with_resume, attrs)

      {:warn, rule} ->
        Logger.warning(
          "[Sessions] Governance warn rule=#{rule.id} name=#{rule.name} — proceeding"
        )

        check_budget_and_insert(attrs_with_resume, attrs)

      {:block, rule} ->
        Logger.warning("[Sessions] Governance blocked rule=#{rule.id} name=#{rule.name}")

        {:error, {:governance_blocked, rule}}

      {:require_approval, rule} ->
        insert_as_pending(attrs_with_resume, rule, attrs)
    end
  end

  # ---------------------------------------------------------------------------
  # Gate helpers (governance + budget)
  # ---------------------------------------------------------------------------

  # Builds the string-keyed context map expected by Governance.evaluate/1.
  @spec build_governance_context(map()) :: map()
  defp build_governance_context(attrs) do
    %{
      "runtime_type" => str_val(attrs, :runtime_type, "runtime_type"),
      "agent_slug" => str_val(attrs, :agent_slug, "agent_slug"),
      "workspace_slug" => str_val(attrs, :workspace_slug, "workspace_slug"),
      "prompt" => str_val(attrs, :prompt, "prompt"),
      "cost_usd" => 0
    }
  end

  # Reads a field from an atom-keyed or string-keyed map.
  @spec str_val(map(), atom(), String.t()) :: String.t() | nil
  defp str_val(attrs, atom_key, string_key) do
    Map.get(attrs, atom_key) || Map.get(attrs, string_key)
  end

  # Runs budget checks and inserts on pass/warn.
  #
  # Scope strategy: only the global scope (scope_id: nil) is evaluated here.
  # Agent-scoped and workspace-scoped budgets use the entity's UUID as scope_id
  # (see Budget schema, :binary_id). Sessions.create/1 has only slugs — resolving
  # slugs to UUIDs would require coupling Sessions to Agents/Workspaces contexts.
  # Agent and workspace scoped enforcement is delegated to the Heartbeat.Worker
  # and future billing hooks that have entity UUIDs in scope.
  @spec check_budget_and_insert(map(), map()) ::
          {:ok, Session.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:budget_blocked, Budgets.Budget.t(), Decimal.t()}}
  defp check_budget_and_insert(attrs_with_resume, original_attrs) do
    projected = Decimal.new(0)

    case Budgets.check("global", nil, projected) do
      :ok ->
        do_insert(attrs_with_resume, original_attrs)

      {:warn, budget, spent} ->
        Logger.warning(
          "[Sessions] Budget warn budget=#{budget.id} spent=#{spent} limit=#{budget.limit_usd} — proceeding"
        )

        do_insert(attrs_with_resume, original_attrs)

      {:block, budget, spent} ->
        Logger.warning(
          "[Sessions] Budget blocked budget=#{budget.id} spent=#{spent} limit=#{budget.limit_usd}"
        )

        {:error, {:budget_blocked, budget, spent}}
    end
  end

  # Inserts the session row, provisions a git worktree when the workspace is a
  # git repo, and triggers MIOSA sandbox provisioning.
  #
  # When `interactive: true` is set in original_attrs, the full SpawnPipeline is
  # invoked after insert — this wires skills, run records, CANOPY_* env vars, and
  # the pty in one atomic sequence.
  #
  # For non-interactive sessions (API-driven, background jobs), the legacy path
  # is preserved: worktree + scrollback only, no pty.
  @spec do_insert(map(), map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  defp do_insert(attrs_with_resume, original_attrs) do
    interactive =
      Map.get(original_attrs, :interactive) || Map.get(original_attrs, "interactive") || false

    with {:ok, session} <-
           %Session{}
           |> Session.changeset(attrs_with_resume)
           |> Repo.insert() do
      Emitter.session_created(%{
        session_id: session.id,
        agent_id: nil,
        workspace_slug: session.workspace_slug,
        runtime: session.runtime_type,
        payload: %{"agent_slug" => session.agent_slug}
      })

      if interactive do
        # Full pipeline: run + worktree + env + pty + scrollback + status
        wake_reason =
          Map.get(original_attrs, :wake_reason) ||
            Map.get(original_attrs, "wake_reason") ||
            "user_prompt"

        approval_id =
          Map.get(original_attrs, :approval_id) || Map.get(original_attrs, "approval_id")

        parent_session_id =
          Map.get(original_attrs, :parent_session_id) ||
            Map.get(original_attrs, "parent_session_id")

        case Canopy.Agents.SpawnPipeline.spawn(session,
               wake_reason: wake_reason,
               approval_id: approval_id,
               parent_session_id: parent_session_id
             ) do
          {:ok, %{session: spawned_session}} ->
            maybe_provision_miosa_sandbox(spawned_session, original_attrs)
            {:ok, spawned_session}

          {:error, _stage, _reason} ->
            # Pipeline failure is already logged and rolled back. Return the
            # bare session so callers can surface the error_reason via status.
            maybe_provision_miosa_sandbox(session, original_attrs)
            {:ok, session}
        end
      else
        # Legacy path: worktree + scrollback only; pty is not started.
        session = maybe_create_worktree(session, original_attrs)
        maybe_provision_miosa_sandbox(session, original_attrs)
        ScrollbackSupervisor.start_child(session.id)
        {:ok, session}
      end
    end
  end

  # Attempts to create a git worktree for this session when the workspace has a
  # root_path that is a git repository. On failure: logs a warning and proceeds
  # with nil worktree fields (plain root_path used as pty cwd).
  @spec maybe_create_worktree(Session.t(), map()) :: Session.t()
  defp maybe_create_worktree(session, original_attrs) do
    workspace_slug =
      Map.get(original_attrs, :workspace_slug) ||
        Map.get(original_attrs, "workspace_slug")

    root_path = resolve_workspace_root(workspace_slug)

    cond do
      is_nil(root_path) ->
        session

      not WorktreeManager.is_git_repo?(root_path) ->
        Logger.debug(
          "[Sessions] workspace not a git repo, skipping worktree session=#{session.id} root=#{root_path}"
        )

        session

      true ->
        branch = WorktreeManager.branch_name(session.id)

        case WorktreeManager.create_worktree(session.id, root_path, branch) do
          {:ok, %{path: path, branch: branch, base_branch: base_branch}} ->
            {:ok, updated} =
              session
              |> Session.worktree_changeset(%{
                worktree_path: path,
                branch: branch,
                base_branch: base_branch
              })
              |> Repo.update()

            updated

          {:error, reason} ->
            Logger.warning(
              "[Sessions] worktree creation failed session=#{session.id}: #{inspect(reason)} — proceeding with plain cwd"
            )

            session
        end
    end
  end

  # Resolves a workspace slug to its root_path. Returns nil when slug is blank
  # or the workspace is not found.
  @spec resolve_workspace_root(String.t() | nil) :: String.t() | nil
  defp resolve_workspace_root(nil), do: nil
  defp resolve_workspace_root(""), do: nil

  defp resolve_workspace_root(slug) do
    case Canopy.Workspaces.get_by_slug(slug) do
      {:ok, workspace} -> workspace.root_path
      _ -> nil
    end
  end

  # Inserts the session with status "pending_approval" and creates a governance
  # approval record so the UI can surface the pending decision.
  @spec insert_as_pending(map(), Governance.Rule.t(), map()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  defp insert_as_pending(attrs_with_resume, rule, _original_attrs) do
    pending_attrs =
      attrs_with_resume
      |> Map.put(:status, "pending_approval")
      |> put_governance_metadata(rule)

    with {:ok, session} <-
           %Session{}
           |> Session.changeset(pending_attrs)
           |> Repo.insert() do
      # Best-effort approval record — failure is logged, session is still returned.
      case Governance.request_approval(rule.id, session.id) do
        {:ok, _approval} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "[Sessions] request_approval failed session=#{session.id} rule=#{rule.id}: #{inspect(reason)}"
          )
      end

      Logger.info(
        "[Sessions] Inserted pending_approval session=#{session.id} rule=#{rule.id} name=#{rule.name}"
      )

      {:ok, session}
    end
  end

  # Merges governance approval metadata into the session attrs.
  @spec put_governance_metadata(map(), Governance.Rule.t()) :: map()
  defp put_governance_metadata(attrs, rule) do
    existing_meta =
      Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{}

    governance_meta =
      Map.merge(existing_meta, %{
        "governance_rule_id" => rule.id,
        "governance_rule_name" => rule.name,
        "governance_pending_since" => DateTime.to_iso8601(DateTime.utc_now())
      })

    # Preserve whichever key form was present in attrs
    if Map.has_key?(attrs, "metadata") do
      Map.put(attrs, "metadata", governance_meta)
    else
      Map.put(attrs, :metadata, governance_meta)
    end
  end

  # Fire-and-forget MIOSA sandbox provisioning triggered when agent metadata
  # includes `needs_sandbox: true` and MIOSA credentials are configured.
  # Track C (adapter args / env injection) reads `miosa_sandbox_url` from the
  # session row and injects CANOPY_MIOSA_SANDBOX_URL into the process environment.
  @spec maybe_provision_miosa_sandbox(Session.t(), map()) :: :ok
  defp maybe_provision_miosa_sandbox(session, attrs) do
    needs_sandbox =
      case attrs do
        %{"metadata" => %{"needs_sandbox" => true}} -> true
        %{metadata: %{"needs_sandbox" => true}} -> true
        %{metadata: %{needs_sandbox: true}} -> true
        _ -> false
      end

    if needs_sandbox and Canopy.Miosa.configured?() do
      Task.start(fn ->
        case Canopy.Miosa.provision_for_session(session.id) do
          {:ok, _updated} ->
            :ok

          {:error, reason} ->
            require Logger

            Logger.warning(
              "[Sessions] MIOSA provision failed session_id=#{session.id}: #{inspect(reason)}"
            )
        end
      end)
    end

    :ok
  end

  @doc """
  Removes the git worktree for `session_id` and nulls the worktree fields.

  Options:
  - `:keep_branch` — passed to WorktreeManager.cleanup/2 (default false)

  Returns `{:ok, session}` on success, `{:error, :not_found}` if the session
  doesn't exist, or `{:error, reason}` on git failure (worktree fields are
  still cleared so they don't point to a stale path).
  """
  @spec cleanup_worktree(binary(), keyword()) ::
          {:ok, Session.t()} | {:error, :not_found | term()}
  def cleanup_worktree(id, opts \\ []) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        git_result =
          if session.worktree_path do
            WorktreeManager.cleanup(id, opts)
          else
            :ok
          end

        case git_result do
          :ok ->
            session
            |> Session.worktree_changeset(%{worktree_path: nil, branch: nil, base_branch: nil})
            |> Repo.update()

          {:error, reason} ->
            Logger.warning(
              "[Sessions] cleanup_worktree git error session=#{id}: #{inspect(reason)} — clearing fields anyway"
            )

            session
            |> Session.worktree_changeset(%{worktree_path: nil, branch: nil, base_branch: nil})
            |> Repo.update()
        end
    end
  end

  @doc """
  Deletes a session record. Cancels the pty if running, cleans up the worktree,
  and stops the scrollback store.

  Returns `{:ok, session}` or `{:error, :not_found | changeset}`.
  """
  @spec delete(binary()) :: {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def delete(id) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        if session.status == "running" do
          PtyBridge.stop(id)
        end

        if session.worktree_path do
          case WorktreeManager.cleanup(id, keep_branch: false) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.warning(
                "[Sessions] delete worktree cleanup failed session=#{id}: #{inspect(reason)}"
              )
          end
        end

        delete_scrollback(id)

        Repo.delete(session)
    end
  end

  @doc """
  Stops the ScrollbackStore for `session_id` and removes the log file.

  Call this for explicit cleanup. `Sessions.create/1` starts the store;
  deletion is intentionally separate because the log is useful post-exit.
  Returns `:ok` regardless of whether the store was running.
  """
  @spec delete_scrollback(binary()) :: :ok
  def delete_scrollback(session_id) do
    ScrollbackSupervisor.stop_child(session_id)
    path = Path.join([System.user_home!(), ".canopy", "scrollback", "#{session_id}.log"])
    File.rm(path)
    :ok
  end

  @doc """
  Marks the session `paused` and tells the PtyBridge to buffer output.
  The pty subprocess keeps running. Returns `{:ok, session}` or `{:error, :not_found}`.
  """
  @spec pause(binary()) :: {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def pause(id) do
    with {:ok, session} <- update_status(id, "paused") do
      PtyBridge.pause(id)
      {:ok, session}
    end
  end

  @doc """
  Marks the session `running` and flushes the PtyBridge output buffer to subscribers.
  Returns `{:ok, session}` or `{:error, :not_found}`.
  """
  @spec resume(binary()) :: {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def resume(id) do
    with {:ok, session} <- update_status(id, "running") do
      PtyBridge.resume(id)
      {:ok, session}
    end
  end

  @doc "Snapshot live sessions to disk. See `Canopy.Sessions.Persistence.save_state/0`."
  @spec save_state() :: {:ok, Persistence.save_result()} | {:error, term()}
  def save_state, do: Persistence.save_state()

  @doc "Restore sessions from the on-disk snapshot. See `Canopy.Sessions.Persistence.restore_state/1`."
  @spec restore_state(keyword()) :: {:ok, Persistence.restore_result()}
  def restore_state(opts \\ []), do: Persistence.restore_state(opts)

  @doc """
  Kills the pty subprocess and marks the session `cancelled`.
  No-op if the session is already in a terminal state.
  Returns `{:ok, session}` or `{:error, :not_found}`.
  """
  @spec stop(binary()) :: {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def stop(id) do
    with {:ok, session} <- get(id) do
      PtyBridge.stop(id)

      if session.status not in ~w(completed cancelled failed) do
        result = update_status(id, "cancelled")

        Emitter.session_cancelled(%{
          session_id: id,
          workspace_slug: session.workspace_slug,
          runtime: session.runtime_type,
          payload: %{"agent_slug" => session.agent_slug, "previous_status" => session.status}
        })

        _ = maybe_flush_breadcrumbs(id)

        result
      else
        {:ok, session}
      end
    end
  end

  @doc """
  Bulk-deletes sessions matching the given filters.

  Accepts any combination of:
  - `:status` — e.g. `"ended"`, `"failed"`, `"cancelled"`, `"completed"`
  - `:before` — ISO8601 datetime string; only sessions inserted before this
    timestamp are deleted.

  Running sessions are never deleted by this function; callers must stop them
  first if needed.

  Returns `{:ok, count}` where `count` is the number of rows deleted.
  """
  @spec bulk_delete(keyword()) :: {:ok, non_neg_integer()}
  def bulk_delete(filters \\ []) do
    terminal_statuses = ~w(ended failed cancelled completed)

    query =
      from(s in Session,
        where: s.status in ^terminal_statuses
      )
      |> apply_bulk_filter(:status, Keyword.get(filters, :status))
      |> apply_bulk_before_filter(Keyword.get(filters, :before))

    {count, _} = Repo.delete_all(query)
    {:ok, count}
  end

  defp apply_bulk_filter(query, _field, nil), do: query

  defp apply_bulk_filter(query, :status, val) when val in ~w(ended failed cancelled completed) do
    from(s in query, where: s.status == ^val)
  end

  # Silently ignore unrecognized statuses (safety guard).
  defp apply_bulk_filter(query, :status, _val), do: query

  defp apply_bulk_before_filter(query, nil), do: query

  defp apply_bulk_before_filter(query, before_str) do
    case DateTime.from_iso8601(before_str) do
      {:ok, dt, _offset} -> from(s in query, where: s.inserted_at < ^dt)
      _error -> query
    end
  end

  @doc "Returns the session by id, or `{:error, :not_found}`."
  @spec get(binary()) :: {:ok, Session.t()} | {:error, :not_found}
  def get(id) do
    case Repo.get(Session, id) do
      nil -> {:error, :not_found}
      session -> {:ok, session}
    end
  end

  @doc "Returns the session by id, raising `Ecto.NoResultsError` if not found."
  @spec get!(binary()) :: Session.t()
  def get!(id), do: Repo.get!(Session, id)

  @doc """
  Returns the full session chain: the session itself, all its ancestors
  (up to the root), and all its direct children ordered by sequence_number.
  """
  @spec get_chain(binary()) :: {:ok, map()} | {:error, :not_found}
  def get_chain(id) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        ancestors = load_ancestors(session, [])

        children =
          Repo.all(
            from(s in Session,
              where: s.parent_session_id == ^id,
              order_by: [asc: s.sequence_number]
            )
          )

        {:ok, %{session: session, ancestors: ancestors, children: children}}
    end
  end

  @doc """
  Lists sessions with optional filters.

  Options:
  - `:status` — filter by session status
  - `:kind` — filter by session kind (`terminal`, `agent_conversation`)
  - `:runtime` — filter by runtime_type
  - `:workspace` — filter by workspace_slug
  - `:limit` — max results (default 50)
  - `:cursor` — inserted_at cursor for pagination (ISO8601 string)
  """
  @spec list(keyword()) :: {:ok, [Session.t()]}
  def list(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    query =
      from(s in Session, order_by: [desc: s.inserted_at], limit: ^limit)
      |> apply_session_filter(:status, Keyword.get(opts, :status))
      |> apply_session_filter(:kind, Keyword.get(opts, :kind))
      |> apply_session_filter(:runtime, Keyword.get(opts, :runtime))
      |> apply_session_filter(:workspace, Keyword.get(opts, :workspace))
      |> apply_cursor_filter(Keyword.get(opts, :cursor))

    {:ok, Repo.all(query)}
  end

  @doc "Returns sessions matching the given status, ordered by insertion time descending."
  @spec list_by_status(String.t()) :: {:ok, [Session.t()]}
  def list_by_status(status) do
    sessions =
      Repo.all(
        from(s in Session,
          where: s.status == ^status,
          order_by: [desc: s.inserted_at]
        )
      )

    {:ok, sessions}
  end

  @doc """
  Transitions the session status.

  Returns `{:ok, session}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec update_status(binary(), String.t()) ::
          {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_status(id, status) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        session
        |> Session.status_changeset(%{status: status})
        |> Repo.update()
    end
  end

  @doc """
  Finalizes a session: sets status to `completed`, records `completed_at`,
  and persists cost and token usage.

  Returns `{:ok, session}` or `{:error, :not_found | changeset}`.
  """
  @spec finalize(binary(), map()) ::
          {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def finalize(id, attrs) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        finalize_attrs =
          Map.merge(attrs, %{status: "completed", completed_at: DateTime.utc_now()})

        result =
          session
          |> Session.finalize_changeset(finalize_attrs)
          |> Repo.update()

        case result do
          {:ok, finalized} ->
            duration_ms = compute_session_duration_ms(finalized)

            Emitter.session_completed(%{
              session_id: finalized.id,
              workspace_slug: finalized.workspace_slug,
              runtime: finalized.runtime_type,
              duration_ms: duration_ms,
              cost_cents: cost_to_cents(finalized.cost_usd),
              payload: %{"agent_slug" => finalized.agent_slug}
            })

            # Best-effort: flush this run's breadcrumbs to disk on completion.
            _ = maybe_flush_breadcrumbs(finalized.id)

            {:ok, finalized}

          other ->
            other
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Messages (transcript entries)
  # ---------------------------------------------------------------------------

  @doc """
  Appends a `SessionMessage` to the session transcript.

  When the entry kind is `:result` (or the string `"result"`) and the content
  map contains a `session_id` or `"session_id"` key, the value is persisted
  as `external_session_id` on the parent session row via `Resume.persist/2`.
  This drives the resume lookup on the next `create/1` call for the same
  agent+workspace+cwd triple.

  Returns `{:ok, message}` or `{:error, changeset}`.
  """
  @spec add_message(binary(), map()) ::
          {:ok, SessionMessage.t()} | {:error, Ecto.Changeset.t()}
  def add_message(session_id, attrs) do
    # Redact credential-shaped strings from content before persist and broadcast.
    # Applied to attrs as a whole so nested content maps are also scrubbed.
    redacted_attrs = Redaction.scrub(attrs)

    result =
      %SessionMessage{}
      |> SessionMessage.changeset(Map.put(redacted_attrs, :session_id, session_id))
      |> Repo.insert()

    maybe_persist_resume(session_id, redacted_attrs)

    result
  end

  @doc """
  Returns all messages for a session, ordered by sequence ascending.

  Options:
  - `:from` — only return messages with sequence >= this value (SSE replay cursor)
  - `:limit` — maximum number of messages to return
  """
  @spec list_messages(binary(), keyword()) :: {:ok, [SessionMessage.t()]}
  def list_messages(session_id, opts \\ []) do
    from_seq = Keyword.get(opts, :from, 0)
    limit = Keyword.get(opts, :limit)

    query =
      from(m in SessionMessage,
        where: m.session_id == ^session_id and m.sequence >= ^from_seq,
        order_by: [asc: m.sequence]
      )

    query = if limit, do: from(m in query, limit: ^limit), else: query

    {:ok, Repo.all(query)}
  end

  @doc """
  Legacy stub for the TranscriptEntry streaming path.
  Superseded by `add_message/2`. Retained until Runner is updated.
  """
  @spec append_message(binary(), map()) :: :ok | {:error, term()}
  def append_message(_session_id, _entry), do: {:error, :not_implemented}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp apply_session_filter(query, _field, nil), do: query
  defp apply_session_filter(query, :status, val), do: from(s in query, where: s.status == ^val)
  defp apply_session_filter(query, :kind, val), do: from(s in query, where: s.kind == ^val)

  defp apply_session_filter(query, :runtime, val),
    do: from(s in query, where: s.runtime_type == ^val)

  defp apply_session_filter(query, :workspace, val),
    do: from(s in query, where: s.workspace_slug == ^val)

  defp apply_cursor_filter(query, nil), do: query

  defp apply_cursor_filter(query, cursor_str) do
    case DateTime.from_iso8601(cursor_str) do
      {:ok, dt, _tz_offset} -> from(s in query, where: s.inserted_at < ^dt)
      _parse_error -> query
    end
  end

  # Walks the parent_session_id chain upward, collecting ancestors.
  # Stops at the root (nil parent) or after 100 hops to prevent infinite loops.
  @spec load_ancestors(Session.t(), [Session.t()]) :: [Session.t()]
  defp load_ancestors(%Session{parent_session_id: nil}, acc), do: Enum.reverse(acc)
  defp load_ancestors(_session, acc) when length(acc) >= 100, do: Enum.reverse(acc)

  defp load_ancestors(%Session{parent_session_id: parent_id}, acc) do
    case Repo.get(Session, parent_id) do
      nil -> Enum.reverse(acc)
      parent -> load_ancestors(parent, [parent | acc])
    end
  end

  # Injects external_session_id from a prior completed session when available.
  # Only runs when agent_slug is present — direct prompts (no agent) are skipped.
  @spec maybe_inject_resume(map()) :: map()
  defp maybe_inject_resume(%{agent_slug: agent} = attrs) when is_binary(agent) and agent != "" do
    workspace = Map.get(attrs, :workspace_slug)
    cwd = Map.get(attrs, :cwd, "")
    bundle_key = Map.get(attrs, :prompt_bundle_key)

    case Resume.find_resumable(agent, workspace, cwd, bundle_key) do
      {:ok, external_id} -> Map.put(attrs, :external_session_id, external_id)
      {:error, :no_resume} -> attrs
    end
  end

  defp maybe_inject_resume(%{"agent_slug" => agent} = attrs)
       when is_binary(agent) and agent != "" do
    workspace = Map.get(attrs, "workspace_slug")
    cwd = Map.get(attrs, "cwd", "")
    bundle_key = Map.get(attrs, "prompt_bundle_key")

    case Resume.find_resumable(agent, workspace, cwd, bundle_key) do
      {:ok, external_id} -> Map.put(attrs, "external_session_id", external_id)
      {:error, :no_resume} -> attrs
    end
  end

  defp maybe_inject_resume(attrs), do: attrs

  # Persists external_session_id on :result entries that carry a session_id from
  # the adapter CLI. Runs fire-and-forget — failure is logged, never raised.
  @spec maybe_persist_resume(binary(), map()) :: :ok
  defp maybe_persist_resume(session_id, attrs) do
    kind = Map.get(attrs, :kind) || Map.get(attrs, "kind")
    content = Map.get(attrs, :content) || Map.get(attrs, "content") || %{}

    external_id =
      Map.get(content, :session_id) || Map.get(content, "session_id")

    if kind in [:result, "result"] and is_binary(external_id) and external_id != "" do
      Resume.persist(session_id, external_id)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Telemetry helpers (best-effort, never affect caller flow)
  # ---------------------------------------------------------------------------

  @spec compute_session_duration_ms(Session.t()) :: integer() | nil
  defp compute_session_duration_ms(%Session{inserted_at: %_{} = ins, completed_at: %_{} = done}) do
    DateTime.diff(done, ins, :millisecond)
  rescue
    _ -> nil
  end

  defp compute_session_duration_ms(_), do: nil

  @spec cost_to_cents(term()) :: integer() | nil
  defp cost_to_cents(nil), do: nil

  defp cost_to_cents(%Decimal{} = d) do
    d
    |> Decimal.mult(Decimal.new(100))
    |> Decimal.round(0)
    |> Decimal.to_integer()
  rescue
    _ -> nil
  end

  defp cost_to_cents(n) when is_number(n), do: round(n * 100)
  defp cost_to_cents(_), do: nil

  # Fire-and-forget breadcrumb flush. The Breadcrumbs GenServer may not be
  # initialised in test envs that skip the supervision tree, so any error is
  # swallowed.
  @spec maybe_flush_breadcrumbs(binary()) :: :ok
  defp maybe_flush_breadcrumbs(run_id) when is_binary(run_id) do
    try do
      _ = Canopy.Analytics.Breadcrumbs.flush_run(run_id)
      :ok
    rescue
      _ -> :ok
    catch
      _, _ -> :ok
    end
  end

  defp maybe_flush_breadcrumbs(_), do: :ok
end
