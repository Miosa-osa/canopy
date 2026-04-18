defmodule Canopy.Sessions do
  @moduledoc """
  Public API for Canopy session management.

  A session represents one agent execution: a runtime is selected, a prompt is
  submitted, the subprocess runs, and a structured transcript is captured via
  `SessionMessage` records. Sessions form chains via `parent_session_id`.

  The Paperclip triple-key resume pattern uses `id + cwd + prompt_bundle_key`
  to decide whether a session can be resumed without re-injecting skills.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Sessions.{Resume, Session, SessionMessage}

  # ---------------------------------------------------------------------------
  # Session lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new session.

  When `agent_slug` and `workspace_slug` are present, looks up the most recent
  completed session for the same agent+workspace+cwd triple and pre-populates
  `external_session_id` so the adapter can pass `--resume` to the CLI.

  Returns `{:ok, session}` or `{:error, changeset}`.
  """
  @spec create(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs_with_resume = maybe_inject_resume(attrs)

    with {:ok, session} <-
           %Session{}
           |> Session.changeset(attrs_with_resume)
           |> Repo.insert() do
      maybe_provision_miosa_sandbox(session, attrs)
      {:ok, session}
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
    result =
      %SessionMessage{}
      |> SessionMessage.changeset(Map.put(attrs, :session_id, session_id))
      |> Repo.insert()

    maybe_persist_resume(session_id, attrs)

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
