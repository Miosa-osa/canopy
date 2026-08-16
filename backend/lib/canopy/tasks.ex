defmodule Canopy.Tasks do
  @moduledoc """
  Context for the Tasks domain.

  Single `tasks` table. Short IDs use a random 8-digit numeric suffix: `T-XXXXXXXX`.

  ## API

  - `list/1` — query with optional filters
  - `get/1` — by short_id
  - `create/1` — inserts, auto-generates short_id
  - `update/2` — by short_id
  - `delete/1` — hard delete by short_id
  - `assign/3` — set assignee_type + assignee_id
  - `complete/1` — mark done, set completed_at
  - `reopen/1` — mark todo, clear completed_at
  """

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  alias Canopy.Governance.Reviewer
  alias Canopy.Repo
  alias Canopy.Sessions
  alias Canopy.Tasks.{Dispatcher, Task}

  @spec list(map()) :: [Task.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(t in Task, order_by: [desc: t.updated_at], limit: ^limit)
    |> maybe_filter_status(filters)
    |> maybe_filter_assignee(filters)
    |> maybe_filter_project(filters)
    |> maybe_filter_parent(filters)
    |> maybe_filter_query(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def get(short_id) when is_binary(short_id) do
    case Repo.get_by(Task, short_id: short_id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end

  @spec create(map()) :: {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    # Normalise to atom keys before injecting short_id so the changeset receives
    # a consistently-keyed map. String keys from HTTP params would otherwise mix
    # with the atom-keyed :short_id and fail Ecto's cast/3.
    normalized = normalize_keys(attrs)
    attrs_with_id = Map.put_new(normalized, :short_id, generate_short_id())

    result =
      %Task{}
      |> Task.changeset(attrs_with_id)
      |> Repo.insert()

    case result do
      {:ok, task} ->
        # Trigger review gate when assignee_type is "agent".
        review_result =
          if task.assignee_type == "agent" do
            Reviewer.maybe_request_review(:artifact, %{
              workspace_slug: task.workspace_slug,
              artifact_type: "task",
              artifact_id: task.id,
              artifact_preview: task.title,
              agent_id: task.assignee_id,
              session_id: task.session_id
            })
          else
            :no_review_required
          end

        case review_result do
          {:review_pending, review_id} ->
            case task
                 |> Task.changeset(%{review_id: review_id})
                 |> Repo.update() do
              {:ok, updated} ->
                {:ok, updated}

              {:error, reason} ->
                Logger.warning(
                  "[Tasks] could not stamp review_id on task #{task.short_id}: #{inspect(reason)}"
                )

                {:ok, task}
            end

          :no_review_required ->
            {:ok, task}
        end

      error ->
        error
    end
  end

  @spec update(String.t(), map()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(short_id, attrs) do
    with {:ok, task} <- get(short_id) do
      task
      |> Task.changeset(attrs)
      |> Repo.update()
    end
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(short_id) do
    with {:ok, task} <- get(short_id) do
      Repo.delete!(task)
      :ok
    end
  end

  @spec assign(String.t(), String.t(), String.t()) ::
          {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def assign(short_id, assignee_type, assignee_id) do
    update(short_id, %{assignee_type: assignee_type, assignee_id: assignee_id})
  end

  @spec complete(String.t()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def complete(short_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    update(short_id, %{status: "done", completed_at: now})
  end

  @spec reopen(String.t()) :: {:ok, Task.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reopen(short_id) do
    update(short_id, %{status: "todo", completed_at: nil})
  end

  @doc """
  Applies a Kanban column verb to a task. Drives the drag-to-state orchestration.

  Verbs:
  - `"start"` / `"build"` — dispatch to agent terminal (find or spawn session)
  - `"pause"` — pause the bound session's pty output (pty stays alive)
  - `"resume"` — resume paused session output
  - `"stop"` / `"cancel"` — kill pty, clear session_id, set status :todo
  - `"done"` — mark task done, stop session
  - `"noop"` — update task status field only (no terminal action)
  """
  @spec apply_verb(Task.t() | String.t(), String.t(), String.t() | nil) ::
          {:ok, Task.t(), String.t() | nil}
          | {:error, :not_found}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
          | {:error, Ecto.Changeset.t()}
  def apply_verb(task_or_id, verb, target_status \\ nil)

  def apply_verb(%Task{} = task, verb, target_status) do
    do_apply_verb(task, verb, target_status)
  end

  def apply_verb(short_id, verb, target_status) when is_binary(short_id) do
    with {:ok, task} <- get(short_id) do
      do_apply_verb(task, verb, target_status)
    end
  end

  defp do_apply_verb(task, verb, _target_status) when verb in ["start", "build"] do
    case Dispatcher.dispatch(task) do
      {:ok, %{session_id: session_id, task: updated}} ->
        {:ok, updated, session_id}

      other ->
        other
    end
  end

  defp do_apply_verb(task, "pause", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    with {:ok, updated} <- maybe_update(task, attrs),
         :ok <- maybe_pause_session(updated.session_id) do
      {:ok, updated, updated.session_id}
    end
  end

  defp do_apply_verb(task, "resume", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    with {:ok, updated} <- maybe_update(task, attrs),
         :ok <- maybe_resume_session(updated.session_id) do
      {:ok, updated, updated.session_id}
    end
  end

  defp do_apply_verb(task, verb, _target_status) when verb in ["stop", "cancel"] do
    _ = if task.session_id, do: Sessions.stop(task.session_id)

    case update(task.short_id, %{status: "todo", session_id: nil}) do
      {:ok, updated} -> {:ok, updated, nil}
      other -> other
    end
  end

  defp do_apply_verb(task, "done", _target_status) do
    _ = if task.session_id, do: Sessions.stop(task.session_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case update(task.short_id, %{status: "done", completed_at: now}) do
      {:ok, updated} -> {:ok, updated, nil}
      other -> other
    end
  end

  defp do_apply_verb(task, "noop", target_status) do
    attrs = if target_status, do: %{status: target_status}, else: %{}

    case maybe_update(task, attrs) do
      {:ok, updated} -> {:ok, updated, updated.session_id}
      other -> other
    end
  end

  defp do_apply_verb(task, _unknown_verb, target_status) do
    # Unknown verbs fall through as noop
    do_apply_verb(task, "noop", target_status)
  end

  defp maybe_update(task, attrs) when map_size(attrs) == 0, do: {:ok, task}
  defp maybe_update(task, attrs), do: update(task.short_id, attrs)

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
    "T-" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  # Converts a string-keyed map to an atom-keyed map using only known Task fields.
  # Atom-keyed entries are kept as-is. Unknown string keys are dropped safely.
  @known_string_keys ~w(short_id parent_id project_slug title description status priority
                        assignee_type assignee_id workspace_slug session_id dispatched_at
                        due_at completed_at labels created_by_run_id review_id
                        claimed_by_agent_id claimed_at auto_assignable required_skills)

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
    do: where(query, [t], t.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_assignee(query, %{assignee_type: at, assignee_id: aid})
       when is_binary(at) and is_binary(aid),
       do: where(query, [t], t.assignee_type == ^at and t.assignee_id == ^aid)

  defp maybe_filter_assignee(query, %{assignee_type: at}) when is_binary(at),
    do: where(query, [t], t.assignee_type == ^at)

  defp maybe_filter_assignee(query, _), do: query

  defp maybe_filter_project(query, %{project_slug: ps}) when is_binary(ps),
    do: where(query, [t], t.project_slug == ^ps)

  defp maybe_filter_project(query, _), do: query

  defp maybe_filter_parent(query, %{parent_id: pid}) when is_binary(pid),
    do: where(query, [t], t.parent_id == ^pid)

  defp maybe_filter_parent(query, _), do: query

  defp maybe_filter_query(query, %{q: q}) when is_binary(q) and q != "" do
    pattern = "%#{String.replace(q, ["%", "_"], fn c -> "\\#{c}" end)}%"
    where(query, [t], ilike(t.title, ^pattern))
  end

  defp maybe_filter_query(query, _), do: query
end
