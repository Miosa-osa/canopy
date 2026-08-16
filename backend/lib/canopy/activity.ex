defmodule Canopy.Activity do
  @moduledoc """
  Activity feed — a unified, time-sorted timeline of events across Canopy.

  Aggregates from four sources without a dedicated audit table:
  1. Session spawns (inserted_at, status = any)
  2. Session endings (:exit heartbeats)
  3. Task status changes (recently updated tasks with status done/cancelled)
  4. Issue status changes (recently closed/cancelled issues)

  Each row is normalised to a common activity map. The feed is sorted by `at`
  descending and can be filtered by `type`.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Heartbeats.Heartbeat
  alias Canopy.Issues.Issue
  alias Canopy.Repo
  alias Canopy.Sessions.Session
  alias Canopy.Tasks.Task

  @default_limit 50

  @typedoc "A normalised activity event."
  @type activity_item :: %{
          id: String.t(),
          type: String.t(),
          session_id: String.t() | nil,
          task_id: String.t() | nil,
          issue_id: String.t() | nil,
          workspace_slug: String.t(),
          actor_type: String.t(),
          actor_id: String.t(),
          title: String.t(),
          preview: String.t() | nil,
          at: DateTime.t()
        }

  @doc """
  Returns a unified activity feed sorted by `at` descending.

  Options:
  - `:workspace_slug` — scope to a workspace (recommended)
  - `:limit` — max results (default 50)
  - `:type` — filter to a single event type string
  """
  @spec feed(keyword()) :: [activity_item()]
  def feed(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    workspace_slug = Keyword.get(opts, :workspace_slug)
    type_filter = Keyword.get(opts, :type)

    session_spawns = load_session_spawns(workspace_slug, limit)
    session_endings = load_session_endings(workspace_slug, limit)
    task_events = load_task_events(workspace_slug, limit)
    issue_events = load_issue_events(workspace_slug, limit)

    all_events =
      (session_spawns ++ session_endings ++ task_events ++ issue_events)
      |> then(fn events ->
        if type_filter do
          Enum.filter(events, &(&1.type == type_filter))
        else
          events
        end
      end)
      |> Enum.sort_by(& &1.at, {:desc, DateTime})
      |> Enum.take(limit)

    all_events
  end

  # ---------------------------------------------------------------------------
  # Session spawns
  # ---------------------------------------------------------------------------

  @spec load_session_spawns(binary() | nil, integer()) :: [activity_item()]
  defp load_session_spawns(workspace_slug, limit) do
    from(s in Session,
      order_by: [desc: s.inserted_at],
      limit: ^limit,
      select: s
    )
    |> maybe_filter_workspace_session(workspace_slug)
    |> Repo.all()
    |> Enum.map(fn s ->
      %{
        id: "activity:session_started:#{s.id}",
        type: "session_started",
        session_id: s.id,
        task_id: nil,
        issue_id: nil,
        workspace_slug: s.workspace_slug || "default",
        actor_type: if(s.agent_slug, do: "agent", else: "human"),
        actor_id: s.agent_slug || "user",
        title: build_session_title(s),
        preview: s.prompt && String.slice(s.prompt, 0, 200),
        wake_reason: s.wake_reason,
        at: s.inserted_at
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Session endings (exit heartbeats)
  # ---------------------------------------------------------------------------

  @spec load_session_endings(binary() | nil, integer()) :: [activity_item()]
  defp load_session_endings(workspace_slug, limit) do
    from(h in Heartbeat,
      join: s in Session,
      on: s.id == h.session_id,
      where: h.kind == :exit,
      order_by: [desc: h.inserted_at],
      limit: ^limit,
      select: %{heartbeat: h, session: s}
    )
    |> maybe_filter_workspace_join(workspace_slug)
    |> Repo.all()
    |> Enum.map(fn %{heartbeat: h, session: s} ->
      exit_code = Map.get(h.meta || %{}, "exit_code")

      %{
        id: "activity:session_ended:#{h.id}",
        type: "session_ended",
        session_id: s.id,
        task_id: nil,
        issue_id: nil,
        workspace_slug: s.workspace_slug || "default",
        actor_type: if(s.agent_slug, do: "agent", else: "system"),
        actor_id: s.agent_slug || "system",
        title: "Session ended" <> if(exit_code, do: " (exit #{exit_code})", else: ""),
        preview: h.preview,
        at: h.inserted_at
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Task events
  # ---------------------------------------------------------------------------

  @spec load_task_events(binary() | nil, integer()) :: [activity_item()]
  defp load_task_events(workspace_slug, limit) do
    from(t in Task,
      where: t.status in ["done", "cancelled", "in_progress"],
      order_by: [desc: t.updated_at],
      limit: ^limit,
      select: t
    )
    |> maybe_filter_workspace_task(workspace_slug)
    |> Repo.all()
    |> Enum.map(fn t ->
      type =
        case t.status do
          "done" -> "task_completed"
          "cancelled" -> "task_cancelled"
          "in_progress" -> "task_dispatched"
          _ -> "task_updated"
        end

      %{
        id: "activity:#{type}:#{t.id}",
        type: type,
        session_id: t.session_id,
        task_id: t.id,
        issue_id: nil,
        workspace_slug: t.workspace_slug || "default",
        actor_type: if(t.assignee_type, do: t.assignee_type, else: "system"),
        actor_id: t.assignee_id || "system",
        title: t.title,
        preview: nil,
        at: t.updated_at
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Issue events
  # ---------------------------------------------------------------------------

  @spec load_issue_events(binary() | nil, integer()) :: [activity_item()]
  defp load_issue_events(workspace_slug, limit) do
    from(i in Issue,
      where: i.status in ["closed", "in_progress", "in_review"],
      order_by: [desc: i.updated_at],
      limit: ^limit,
      select: i
    )
    |> maybe_filter_workspace_issue(workspace_slug)
    |> Repo.all()
    |> Enum.map(fn i ->
      type =
        case i.status do
          "closed" -> "issue_closed"
          "in_progress" -> "issue_dispatched"
          "in_review" -> "issue_in_review"
          _ -> "issue_updated"
        end

      %{
        id: "activity:#{type}:#{i.id}",
        type: type,
        session_id: i.session_id,
        task_id: nil,
        issue_id: i.id,
        workspace_slug: i.workspace_slug || "default",
        actor_type: if(i.assignee_type, do: i.assignee_type, else: "system"),
        actor_id: i.assignee_id || "system",
        title: i.title,
        preview: nil,
        at: i.updated_at
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Filters
  # ---------------------------------------------------------------------------

  defp maybe_filter_workspace_session(query, nil), do: query

  defp maybe_filter_workspace_session(query, slug),
    do: from(s in query, where: s.workspace_slug == ^slug)

  defp maybe_filter_workspace_join(query, nil), do: query

  defp maybe_filter_workspace_join(query, slug),
    do: from([_h, s] in query, where: s.workspace_slug == ^slug)

  defp maybe_filter_workspace_task(query, nil), do: query

  defp maybe_filter_workspace_task(query, slug),
    do: from(t in query, where: t.workspace_slug == ^slug)

  defp maybe_filter_workspace_issue(query, nil), do: query

  defp maybe_filter_workspace_issue(query, slug),
    do: from(i in query, where: i.workspace_slug == ^slug)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  @spec build_session_title(Session.t()) :: String.t()
  defp build_session_title(%{agent_slug: slug}) when is_binary(slug) and slug != "",
    do: "Agent #{slug} session started"

  defp build_session_title(_), do: "Session started"
end
