defmodule Canopy.Issues do
  @moduledoc """
  Context for the Issues domain.

  Developer-facing unit of work. Analogous to GitHub Issues.
  Short IDs use a random 8-digit numeric suffix: `I-XXXXXXXX`.

  ## API

  - `list/1`     — query with optional filters
  - `get/1`      — by short_id or uuid
  - `create/1`   — inserts, auto-generates short_id
  - `update/2`   — by short_id
  - `assign/2`   — set assignee_type + assignee_id
  - `complete/1` — close, set completed_at
  - `reopen/1`   — reopen to :open, clear completed_at
  - `delete/1`   — hard delete by short_id
  - `dispatch/2` — dispatch to agent terminal (mirrors Tasks.Dispatcher)
  """

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  alias Canopy.Governance.Reviewer
  alias Canopy.Issues.{Dispatcher, Issue}
  alias Canopy.Repo
  alias Canopy.Sessions

  @spec list(map()) :: [Issue.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(i in Issue, order_by: [desc: i.updated_at], limit: ^limit)
    |> maybe_filter_status(filters)
    |> maybe_filter_workspace(filters)
    |> maybe_filter_assignee(filters)
    |> maybe_filter_project(filters)
    |> maybe_filter_parent(filters)
    |> maybe_filter_query(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Issue.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    # Accept both short_id ("I-XXXXXXXX") and UUID
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} ->
        case Repo.get(Issue, id) do
          nil -> {:error, :not_found}
          issue -> {:ok, issue}
        end

      :error ->
        case Repo.get_by(Issue, short_id: id) do
          nil -> {:error, :not_found}
          issue -> {:ok, issue}
        end
    end
  end

  @spec create(map()) :: {:ok, Issue.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    normalized = normalize_keys(attrs)
    attrs_with_id = Map.put_new(normalized, :short_id, generate_short_id())

    result =
      %Issue{}
      |> Issue.changeset(attrs_with_id)
      |> Repo.insert()

    case result do
      {:ok, issue} ->
        # Trigger review gate when assignee_type is "agent".
        review_result =
          if issue.assignee_type == "agent" do
            Reviewer.maybe_request_review(:artifact, %{
              workspace_slug: issue.workspace_slug,
              artifact_type: "issue",
              artifact_id: issue.id,
              artifact_preview: issue.title,
              agent_id: issue.assignee_id,
              session_id: issue.session_id
            })
          else
            :no_review_required
          end

        case review_result do
          {:review_pending, review_id} ->
            case issue
                 |> Issue.changeset(%{review_id: review_id})
                 |> Repo.update() do
              {:ok, updated} ->
                {:ok, updated}

              {:error, reason} ->
                Logger.warning(
                  "[Issues] could not stamp review_id on issue #{issue.short_id}: #{inspect(reason)}"
                )

                {:ok, issue}
            end

          :no_review_required ->
            {:ok, issue}
        end

      error ->
        error
    end
  end

  @spec update(String.t(), map()) :: {:ok, Issue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(id, attrs) do
    with {:ok, issue} <- get(id) do
      issue
      |> Issue.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec assign(String.t(), map()) :: {:ok, Issue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def assign(id, %{"assignee_type" => type, "assignee_id" => aid}),
    do: update(id, %{assignee_type: type, assignee_id: aid})

  def assign(id, %{assignee_type: type, assignee_id: aid}),
    do: update(id, %{assignee_type: type, assignee_id: aid})

  @spec complete(String.t()) :: {:ok, Issue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def complete(id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update(id, %{status: "closed", completed_at: now})
  end

  @spec reopen(String.t()) :: {:ok, Issue.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reopen(id) do
    update(id, %{status: "open", completed_at: nil})
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(id) do
    with {:ok, issue} <- get(id) do
      Repo.delete!(issue)
      :ok
    end
  end

  @spec dispatch(String.t(), keyword()) ::
          {:ok, %{session_id: String.t(), issue: Issue.t()}}
          | {:error, :not_found}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
  def dispatch(id, opts \\ []) do
    Dispatcher.dispatch(id, opts)
  end

  @doc """
  Attempts to check out an issue for an agent.

  Returns `{:ok, issue}` on success (new or same-agent renewal).
  Returns `{:error, :already_checked_out, info}` when another agent owns an active lock.
  """
  @spec try_checkout(String.t(), String.t(), pos_integer()) ::
          {:ok, Issue.t()}
          | {:error, :not_found}
          | {:error, :already_checked_out, map()}
          | {:error, Ecto.Changeset.t()}
  def try_checkout(id, agent_slug, ttl_seconds \\ 1800) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    with {:ok, issue} <- get(id) do
      cond do
        # Lock expired or not set — anyone may claim
        is_nil(issue.checkout_expires_at) or
            DateTime.compare(issue.checkout_expires_at, now) == :lt ->
          do_checkout(issue, agent_slug, ttl_seconds, now)

        # Same agent renews
        issue.checked_out_by_agent == agent_slug ->
          do_checkout(issue, agent_slug, ttl_seconds, now)

        # Another agent holds an active lock
        true ->
          {:error, :already_checked_out,
           %{
             locked_by: issue.checked_out_by_agent,
             locked_until: issue.checkout_expires_at
           }}
      end
    end
  end

  @spec release(String.t(), String.t()) ::
          :ok | {:error, :not_found} | {:error, :not_owner}
  def release(id, agent_slug) do
    with {:ok, issue} <- get(id) do
      if issue.checked_out_by_agent == agent_slug do
        attrs = %{checked_out_by_agent: nil, checked_out_at: nil, checkout_expires_at: nil}

        case issue |> Issue.changeset(attrs) |> Repo.update() do
          {:ok, _} -> :ok
          error -> error
        end
      else
        {:error, :not_owner}
      end
    end
  end

  @doc """
  Sweeps issues with expired checkout locks and clears them.
  Intended to be called from an Oban job every minute.
  """
  @spec expire_stale_locks() :: non_neg_integer()
  def expire_stale_locks do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    import Ecto.Query, only: [from: 2]

    {count, _} =
      Repo.update_all(
        from(i in Issue,
          where: not is_nil(i.checkout_expires_at) and i.checkout_expires_at < ^now
        ),
        set: [
          checked_out_by_agent: nil,
          checked_out_at: nil,
          checkout_expires_at: nil
        ]
      )

    Logger.info("[Issues] expired #{count} stale checkout lock(s)")
    count
  end

  defp do_checkout(issue, agent_slug, ttl_seconds, now) do
    expires_at = DateTime.add(now, ttl_seconds, :second)

    attrs = %{
      checked_out_by_agent: agent_slug,
      checked_out_at: now,
      checkout_expires_at: expires_at
    }

    issue |> Issue.changeset(attrs) |> Repo.update()
  end

  @doc """
  Applies a Kanban column verb to an issue. Mirrors `Canopy.Tasks.apply_verb/3`.

  Verbs:
  - `"start"` / `"build"` — dispatch to agent terminal
  - `"pause"` — pause the bound session's pty output (pty stays alive)
  - `"resume"` — resume paused session output
  - `"stop"` / `"cancel"` — kill pty, clear session_id, set status :open
  - `"done"` — mark issue closed, stop session
  - `"noop"` — update issue status field only
  """
  @spec apply_verb(Issue.t() | String.t(), String.t(), String.t() | nil) ::
          {:ok, Issue.t(), String.t() | nil}
          | {:error, :not_found}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
          | {:error, Ecto.Changeset.t()}
  def apply_verb(issue_or_id, verb, target_status \\ nil)

  def apply_verb(%Issue{} = issue, verb, target_status) do
    do_apply_verb(issue, verb, target_status)
  end

  def apply_verb(id, verb, target_status) when is_binary(id) do
    with {:ok, issue} <- get(id) do
      do_apply_verb(issue, verb, target_status)
    end
  end

  defp do_apply_verb(issue, verb, _target_status) when verb in ["start", "build"] do
    case Dispatcher.dispatch(issue) do
      {:ok, %{session_id: session_id, issue: updated}} ->
        {:ok, updated, session_id}

      other ->
        other
    end
  end

  defp do_apply_verb(issue, "pause", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    with {:ok, updated} <- maybe_update_issue(issue, attrs),
         :ok <- maybe_pause_session(updated.session_id) do
      {:ok, updated, updated.session_id}
    end
  end

  defp do_apply_verb(issue, "resume", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    with {:ok, updated} <- maybe_update_issue(issue, attrs),
         :ok <- maybe_resume_session(updated.session_id) do
      {:ok, updated, updated.session_id}
    end
  end

  defp do_apply_verb(issue, verb, _target_status) when verb in ["stop", "cancel"] do
    _ = if issue.session_id, do: Sessions.stop(issue.session_id)

    case update(issue.short_id, %{status: "open", session_id: nil}) do
      {:ok, updated} -> {:ok, updated, nil}
      other -> other
    end
  end

  defp do_apply_verb(issue, "done", _target_status) do
    _ = if issue.session_id, do: Sessions.stop(issue.session_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case update(issue.short_id, %{status: "closed", completed_at: now}) do
      {:ok, updated} -> {:ok, updated, nil}
      other -> other
    end
  end

  defp do_apply_verb(issue, "noop", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    case maybe_update_issue(issue, attrs) do
      {:ok, updated} -> {:ok, updated, updated.session_id}
      other -> other
    end
  end

  defp do_apply_verb(issue, _unknown_verb, target_status) do
    do_apply_verb(issue, "noop", target_status)
  end

  defp maybe_update_issue(issue, attrs) when map_size(attrs) == 0, do: {:ok, issue}
  defp maybe_update_issue(issue, attrs), do: update(issue.short_id, attrs)

  defp maybe_pause_session(nil), do: :ok
  defp maybe_pause_session(session_id), do: Sessions.pause(session_id) |> elem_ok()

  defp maybe_resume_session(nil), do: :ok
  defp maybe_resume_session(session_id), do: Sessions.resume(session_id) |> elem_ok()

  defp elem_ok({:ok, _}), do: :ok
  defp elem_ok(other), do: other

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_short_id do
    n = :rand.uniform(100_000_000) - 1
    "I-" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  @known_string_keys ~w(short_id title description status priority assignee_type assignee_id
                        workspace_slug project_slug parent_id session_id dispatched_at
                        completed_at branch pr_url labels estimate_minutes due_at
                        created_by_run_id review_id
                        checked_out_by_agent checked_out_at checkout_expires_at)

  @spec normalize_keys(map()) :: map()
  defp normalize_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, k, v)

      {k, v}, acc when is_binary(k) and k in @known_string_keys ->
        Map.put(acc, String.to_existing_atom(k), v)

      _, acc ->
        acc
    end)
  end

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [i], i.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [i], i.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_assignee(query, %{assignee_type: at, assignee_id: aid})
       when is_binary(at) and is_binary(aid),
       do: where(query, [i], i.assignee_type == ^at and i.assignee_id == ^aid)

  defp maybe_filter_assignee(query, %{assignee_type: at}) when is_binary(at),
    do: where(query, [i], i.assignee_type == ^at)

  defp maybe_filter_assignee(query, _), do: query

  defp maybe_filter_project(query, %{project_slug: ps}) when is_binary(ps),
    do: where(query, [i], i.project_slug == ^ps)

  defp maybe_filter_project(query, _), do: query

  defp maybe_filter_parent(query, %{parent_id: pid}) when is_binary(pid),
    do: where(query, [i], i.parent_id == ^pid)

  defp maybe_filter_parent(query, _), do: query

  defp maybe_filter_query(query, %{q: q}) when is_binary(q) and q != "" do
    pattern = "%#{String.replace(q, ["%", "_"], fn c -> "\\#{c}" end)}%"
    where(query, [i], ilike(i.title, ^pattern))
  end

  defp maybe_filter_query(query, _), do: query
end
