defmodule Canopy.Tasks.Kanban do
  @moduledoc """
  Agent-Kanban operations layered on top of `Canopy.Tasks`.

  An agent-kanban task is a regular `Canopy.Tasks.Task` row with three extra
  fields: `claimed_by_agent_id`, `claimed_at`, `auto_assignable`, and
  `required_skills`. This module owns the atomic claim/release/complete
  state machine and the queue queries that feed both the auto-pickup loop
  and the kanban frontend.

  ## Claim atomicity

  `claim_task/2` acquires the row with `SELECT … FOR UPDATE SKIP LOCKED`
  inside a `Repo.transaction`. Two concurrent claims on the same task
  return `{:ok, task}` for exactly one caller and `{:error, :already_claimed}`
  for the other — no double-dispatch. SKIP LOCKED keeps the auto-pickup
  loop scaling: workers fan out across rows without ever waiting on each other.

  ## Lifecycle

      Backlog (unclaimed, status=todo)
        ──claim_task──►  Claimed (claimed_by set, status=todo)
        ──dispatch via Tasks.Dispatcher──►  In Progress (session_id set, status=in_progress)
        ──complete_task──►  Done (status=done, claimed cleared, completed_at set)

  `release_task/1` puts a claimed task back in Backlog without losing its
  session_id history. `complete_task/2` records the session that produced
  the work for traceability.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Tasks
  alias Canopy.Tasks.Task

  require Logger

  @type kanban_column :: :backlog | :claimed | :in_progress | :done

  # ---------------------------------------------------------------------------
  # Atomic claim
  # ---------------------------------------------------------------------------

  @doc """
  Claims `task_short_id` for `agent_slug` atomically.

  Uses `SELECT … FOR UPDATE SKIP LOCKED` inside a transaction. If another
  worker has already grabbed the row, the lock is skipped and the call
  returns `{:error, :already_claimed}` immediately — no waiting.

  Returns:
  - `{:ok, %Task{}}` — caller now owns the task
  - `{:error, :already_claimed}` — another agent already has it
  - `{:error, :not_found}` — short_id does not exist
  """
  @spec claim_task(String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, :already_claimed | :not_found}
  def claim_task(task_short_id, agent_slug)
      when is_binary(task_short_id) and is_binary(agent_slug) do
    Repo.transaction(fn ->
      result =
        from(t in Task,
          where: t.short_id == ^task_short_id and is_nil(t.claimed_by_agent_id),
          lock: "FOR UPDATE SKIP LOCKED"
        )
        |> Repo.one()

      case result do
        nil ->
          # Either the row doesn't exist OR it's already claimed (lock skipped).
          # Distinguish by an unlocked existence check inside the same tx.
          if Repo.exists?(from t in Task, where: t.short_id == ^task_short_id) do
            Repo.rollback(:already_claimed)
          else
            Repo.rollback(:not_found)
          end

        task ->
          now = DateTime.utc_now()

          {:ok, claimed} =
            task
            |> Task.changeset(%{
              claimed_by_agent_id: agent_slug,
              claimed_at: now,
              assignee_type: "agent",
              assignee_id: agent_slug
            })
            |> Repo.update()

          claimed
      end
    end)
    |> case do
      {:ok, task} ->
        broadcast_kanban_event(task, "kanban:claimed", agent_slug)
        {:ok, task}

      {:error, reason} when reason in [:already_claimed, :not_found] ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Release / complete
  # ---------------------------------------------------------------------------

  @doc """
  Releases a claimed task back into the Backlog column.

  Idempotent: releasing an already-unclaimed task is a no-op.
  """
  @spec release_task(String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def release_task(task_short_id) when is_binary(task_short_id) do
    with {:ok, task} <- Tasks.get(task_short_id) do
      agent_slug = task.claimed_by_agent_id

      result =
        task
        |> Task.changeset(%{claimed_by_agent_id: nil, claimed_at: nil})
        |> Repo.update()

      case result do
        {:ok, released} ->
          broadcast_kanban_event(released, "kanban:released", agent_slug)
          {:ok, released}

        error ->
          error
      end
    end
  end

  @doc """
  Marks a task done and records the session that produced the work.

  Idempotent on the status flip — calling complete on an already-done task
  re-stamps `completed_at` but does not error.
  """
  @spec complete_task(String.t(), binary() | nil) :: {:ok, Task.t()} | {:error, :not_found}
  def complete_task(task_short_id, session_id \\ nil) when is_binary(task_short_id) do
    with {:ok, task} <- Tasks.get(task_short_id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs =
        %{status: "done", completed_at: now}
        |> maybe_put_session_id(session_id)

      result =
        task
        |> Task.changeset(attrs)
        |> Repo.update()

      case result do
        {:ok, completed} ->
          broadcast_kanban_event(completed, "kanban:completed", completed.claimed_by_agent_id)
          {:ok, completed}

        error ->
          error
      end
    end
  end

  defp maybe_put_session_id(attrs, nil), do: attrs
  defp maybe_put_session_id(attrs, sid) when is_binary(sid), do: Map.put(attrs, :session_id, sid)

  defp broadcast_kanban_event(%Task{workspace_slug: nil}, _event, _agent_slug), do: :ok

  defp broadcast_kanban_event(%Task{workspace_slug: slug, id: task_id}, event, agent_slug) do
    Phoenix.PubSub.broadcast(Canopy.PubSub, "tasks:workspace:#{slug}", %{
      event: event,
      task_id: task_id,
      agent_slug: agent_slug
    })
  end

  # ---------------------------------------------------------------------------
  # Queue queries
  # ---------------------------------------------------------------------------

  @doc """
  Returns the next unclaimed task an agent could pick up.

  Filters:
  - `auto_assignable = true`
  - `claimed_by_agent_id IS NULL`
  - `status IN ('todo','in_progress')`
  - `required_skills` ⊆ `agent_skills` — every required skill must be in the
    agent's skill list. Uses Postgres array containment (`<@`).

  Ordered by priority DESC, then `inserted_at` ASC (FIFO within priority).
  Optional `:workspace_slug` filter.

  Returns `nil` when nothing matches — callers loop on next tick.
  """
  @spec next_unclaimed([String.t()], keyword()) :: Task.t() | nil
  def next_unclaimed(agent_skills, opts \\ []) when is_list(agent_skills) do
    workspace = Keyword.get(opts, :workspace_slug)

    query =
      from(t in Task,
        where:
          t.auto_assignable == true and is_nil(t.claimed_by_agent_id) and
            t.status in ["todo", "in_progress"] and
            fragment("? <@ ?::varchar[]", t.required_skills, ^agent_skills),
        order_by: [desc: t.priority, asc: t.inserted_at],
        limit: 1
      )

    query
    |> maybe_filter_workspace(workspace)
    |> Repo.one()
  end

  defp maybe_filter_workspace(query, nil), do: query

  defp maybe_filter_workspace(query, slug) when is_binary(slug),
    do: from(t in query, where: t.workspace_slug == ^slug)

  @doc """
  Lists tasks claimed by `agent_slug`, ordered by claim time descending.
  """
  @spec claimed_by(String.t()) :: [Task.t()]
  def claimed_by(agent_slug) when is_binary(agent_slug) do
    Repo.all(
      from(t in Task,
        where: t.claimed_by_agent_id == ^agent_slug,
        order_by: [desc: t.claimed_at]
      )
    )
  end

  @doc """
  Returns the four kanban columns for a workspace as a single map.

      %{
        backlog:     [Task.t()],   # unclaimed, status in (todo, in_progress)
        claimed:     [Task.t()],   # claimed but no live session yet
        in_progress: [Task.t()],   # session_id set, status=in_progress
        done:        [Task.t()]    # status=done
      }

  Limits each column to `:limit` (default 100) so the UI never paints a
  multi-thousand-row column. Filters by workspace when `:workspace_slug`
  is provided.
  """
  @spec board(keyword()) :: %{kanban_column() => [Task.t()]}
  def board(opts \\ []) do
    workspace = Keyword.get(opts, :workspace_slug)
    limit = opts |> Keyword.get(:limit, 100) |> min(500)

    base = from(t in Task, order_by: [desc: t.priority, desc: t.updated_at], limit: ^limit)
    base = maybe_filter_workspace(base, workspace)

    backlog =
      Repo.all(
        from t in base,
          where: is_nil(t.claimed_by_agent_id) and t.status in ["todo", "in_progress"]
      )

    claimed =
      Repo.all(
        from t in base,
          where: not is_nil(t.claimed_by_agent_id) and is_nil(t.session_id) and t.status != "done"
      )

    in_progress =
      Repo.all(
        from t in base,
          where: not is_nil(t.session_id) and t.status == "in_progress"
      )

    done = Repo.all(from t in base, where: t.status == "done")

    %{backlog: backlog, claimed: claimed, in_progress: in_progress, done: done}
  end

  @doc """
  Returns unclaimed tasks for a workspace as a flat list — convenience for
  callers that only want the Backlog column.
  """
  @spec unclaimed_for_workspace(String.t()) :: [Task.t()]
  def unclaimed_for_workspace(workspace_slug) when is_binary(workspace_slug) do
    Repo.all(
      from(t in Task,
        where:
          t.workspace_slug == ^workspace_slug and is_nil(t.claimed_by_agent_id) and
            t.status in ["todo", "in_progress"],
        order_by: [desc: t.priority, asc: t.inserted_at]
      )
    )
  end
end
