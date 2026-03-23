defmodule CanopyWeb.IssueController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Issue, Comment, Agent, Label, IssueLabel}
  import Ecto.Query

  def index(conn, params) do
    limit = min(String.to_integer(params["limit"] || "50"), 100)
    offset = String.to_integer(params["offset"] || "0")

    workspace_id = params["workspace_id"]
    status = params["status"]
    priority = params["priority"]
    project_id = params["project_id"]
    assignee_id = params["assignee_id"]
    goal_id = params["goal_id"]

    query =
      from i in Issue,
        order_by: [desc: i.updated_at],
        limit: ^limit,
        offset: ^offset

    query = if workspace_id, do: where(query, [i], i.workspace_id == ^workspace_id), else: query
    query = if status, do: where(query, [i], i.status == ^status), else: query
    query = if priority, do: where(query, [i], i.priority == ^priority), else: query
    query = if project_id, do: where(query, [i], i.project_id == ^project_id), else: query
    query = if assignee_id, do: where(query, [i], i.assignee_id == ^assignee_id), else: query
    query = if goal_id, do: where(query, [i], i.goal_id == ^goal_id), else: query

    count_query = from i in Issue
    count_query = if workspace_id, do: where(count_query, [i], i.workspace_id == ^workspace_id), else: count_query
    count_query = if status, do: where(count_query, [i], i.status == ^status), else: count_query
    count_query = if priority, do: where(count_query, [i], i.priority == ^priority), else: count_query
    count_query = if project_id, do: where(count_query, [i], i.project_id == ^project_id), else: count_query
    count_query = if assignee_id, do: where(count_query, [i], i.assignee_id == ^assignee_id), else: count_query
    count_query = if goal_id, do: where(count_query, [i], i.goal_id == ^goal_id), else: count_query

    issues = Repo.all(query) |> Repo.preload([:labels, :assignee, :comments])
    total = Repo.aggregate(count_query, :count)
    json(conn, %{issues: Enum.map(issues, &serialize/1), total: total})
  end

  def create(conn, params) do
    changeset = Issue.changeset(%Issue{}, params)

    case Repo.insert(changeset) do
      {:ok, issue} ->
        issue = Repo.preload(issue, [:labels, :assignee, :comments])

        Canopy.EventBus.broadcast(
          Canopy.EventBus.workspace_topic(issue.workspace_id),
          %{event: "issue.created", issue_id: issue.id, title: issue.title}
        )

        conn |> put_status(201) |> json(%{issue: serialize(issue)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(cs)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Issue, id) |> Repo.preload([:comments, :labels, :assignee]) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      issue ->
        json(conn, %{
          issue:
            serialize(issue)
            |> Map.put(:comments, Enum.map(issue.comments, &serialize_comment/1))
        })
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Issue, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      issue ->
        old_status = issue.status
        changeset = Issue.changeset(issue, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            updated = Repo.preload(updated, [:labels, :assignee, :comments])

            if old_status != updated.status do
              Canopy.EventBus.broadcast(
                Canopy.EventBus.workspace_topic(updated.workspace_id),
                %{
                  event: "issue.status_changed",
                  issue_id: updated.id,
                  from: old_status,
                  to: updated.status
                }
              )
            end

            json(conn, %{issue: serialize(updated)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Issue, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      issue ->
        Repo.delete!(issue)
        json(conn, %{ok: true})
    end
  end

  def assign(conn, %{"issue_id" => id} = params) do
    agent_id = params["agent_id"]

    with %Issue{} = issue <- Repo.get(Issue, id),
         %Agent{} <- Repo.get(Agent, agent_id) do
      case issue
           |> Ecto.Changeset.change(assignee_id: agent_id)
           |> Repo.update() do
        {:ok, updated} ->
          updated = Repo.preload(updated, [:labels, :assignee, :comments])

          Canopy.EventBus.broadcast(
            Canopy.EventBus.workspace_topic(updated.workspace_id),
            %{event: "issue.assigned", issue_id: id, agent_id: agent_id}
          )

          json(conn, %{issue: serialize(updated)})

        {:error, _changeset} ->
          conn |> put_status(500) |> json(%{error: "update_failed"})
      end
    else
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
    end
  end

  def checkout(conn, %{"issue_id" => id} = params) do
    agent_id = params["agent_id"]

    case Repo.get(Issue, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      _issue ->
        case Canopy.Work.checkout_issue(id, agent_id) do
          {:ok, updated} ->
            updated = Repo.preload(updated, [:labels, :assignee, :comments])
            json(conn, %{issue: serialize(updated)})

          {:error, :already_checked_out} ->
            conn
            |> put_status(409)
            |> json(%{error: "already_checked_out"})
        end
    end
  end

  def dispatch(conn, %{"issue_id" => issue_id}) do
    case Canopy.IssueDispatcher.dispatch(issue_id) do
      {:ok, :dispatched} ->
        json(conn, %{ok: true, message: "Agent dispatched"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Issue not found"})

      {:error, :not_assigned} ->
        conn |> put_status(422) |> json(%{error: "Issue is not assigned to an agent"})

      {:error, :already_checked_out} ->
        conn |> put_status(409) |> json(%{error: "Issue is already being worked on"})

      {:error, {:agent_not_ready, _}} ->
        conn |> put_status(422) |> json(%{error: "Assigned agent is not ready"})

      {:error, _reason} ->
        conn |> put_status(422) |> json(%{error: "Dispatch failed"})
    end
  end

  def add_label(conn, %{"id" => issue_id, "label_id" => label_id}) do
    with %Issue{} <- Repo.get(Issue, issue_id),
         %Label{} <- Repo.get(Label, label_id) do
      case Repo.insert(%IssueLabel{issue_id: issue_id, label_id: label_id}, on_conflict: :nothing) do
        {:ok, _} -> json(conn, %{ok: true})
        {:error, cs} -> conn |> put_status(422) |> json(%{error: "failed", details: format_errors(cs)})
      end
    else
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
    end
  end

  def remove_label(conn, %{"id" => issue_id, "label_id" => label_id}) do
    query = from il in IssueLabel, where: il.issue_id == ^issue_id and il.label_id == ^label_id
    {count, _} = Repo.delete_all(query)

    if count > 0 do
      json(conn, %{ok: true})
    else
      conn |> put_status(404) |> json(%{error: "not_found"})
    end
  end

  # --- Private helpers ---

  defp serialize(%Issue{} = i) do
    assignee_name =
      if Ecto.assoc_loaded?(i.assignee) && i.assignee, do: i.assignee.name, else: nil

    comments_count =
      if Ecto.assoc_loaded?(i.comments), do: length(i.comments), else: 0

    labels =
      if Ecto.assoc_loaded?(i.labels),
        do: Enum.map(i.labels, fn l -> %{id: l.id, name: l.name, color: l.color} end),
        else: []

    %{
      id: i.id,
      title: i.title,
      description: i.description,
      status: i.status,
      priority: i.priority,
      workspace_id: i.workspace_id,
      project_id: i.project_id,
      goal_id: i.goal_id,
      assignee_id: i.assignee_id,
      assignee_name: assignee_name,
      labels: labels,
      comments_count: comments_count,
      created_by: nil,
      checked_out_by: i.checked_out_by,
      created_at: i.inserted_at,
      inserted_at: i.inserted_at,
      updated_at: i.updated_at
    }
  end

  defp serialize_comment(%Comment{} = c) do
    %{
      id: c.id,
      author_type: c.author_type,
      author_id: c.author_id,
      body: c.body,
      inserted_at: c.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
