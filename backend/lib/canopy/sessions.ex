defmodule Canopy.Sessions do
  @moduledoc """
  Public API for Canopy session management.

  A session represents one agent execution: a runtime is selected, a prompt is
  submitted, the subprocess runs, and a structured transcript is captured via
  `SessionMessage` records. Sessions form chains via `parent_session_id`.

  The Paperclip triple-key resume pattern uses `id + cwd + prompt_bundle_key`
  to decide whether a session can be resumed without re-injecting skills.

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

  alias Canopy.Budgets
  alias Canopy.Governance
  alias Canopy.Repo
  alias Canopy.Sessions.{Redaction, Resume, Session, SessionMessage}

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

  # Inserts the session row and triggers MIOSA sandbox provisioning.
  @spec do_insert(map(), map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  defp do_insert(attrs_with_resume, original_attrs) do
    with {:ok, session} <-
           %Session{}
           |> Session.changeset(attrs_with_resume)
           |> Repo.insert() do
      maybe_provision_miosa_sandbox(session, original_attrs)
      {:ok, session}
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

        session
        |> Session.finalize_changeset(finalize_attrs)
        |> Repo.update()
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
end
