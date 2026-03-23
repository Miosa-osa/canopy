defmodule CanopyWeb.ApprovalController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Approval, ApprovalComment}
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    query =
      from a in Approval,
        order_by: [desc: a.inserted_at]

    query =
      if params["status"],
        do: where(query, [a], a.status == ^params["status"]),
        else: query

    query =
      cond do
        workspace_id -> where(query, [a], a.workspace_id == ^workspace_id)
        user_workspace_ids != [] -> where(query, [a], a.workspace_id in ^user_workspace_ids)
        true -> query
      end

    approvals = Repo.all(query)
    json(conn, %{approvals: Enum.map(approvals, &serialize/1)})
  end

  def create(conn, params) do
    changeset = Approval.changeset(%Approval{}, params)

    case Repo.insert(changeset) do
      {:ok, approval} ->
        conn |> put_status(201) |> json(%{approval: serialize(approval)})

      {:error, cs} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(cs)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Approval, id) |> Repo.preload(:approval_comments) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      approval ->
        json(conn, %{
          approval:
            serialize(approval)
            |> Map.put(:comments, Enum.map(approval.approval_comments, &serialize_comment/1))
        })
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Approval, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      approval ->
        changeset = Approval.changeset(approval, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{approval: serialize(updated)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Approval, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      approval ->
        Repo.delete!(approval)
        json(conn, %{ok: true})
    end
  end

  def approve(conn, %{"approval_id" => id} = params) do
    case Repo.get(Approval, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      approval ->
        case approval
             |> Ecto.Changeset.change(
               status: "approved",
               decision: "approved",
               decision_comment: params["decision_comment"]
             )
             |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{approval: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def reject(conn, %{"approval_id" => id} = params) do
    case Repo.get(Approval, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      approval ->
        case approval
             |> Ecto.Changeset.change(
               status: "rejected",
               decision: "rejected",
               decision_comment: params["decision_comment"]
             )
             |> Repo.update() do
          {:ok, updated} ->
            json(conn, %{approval: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def comment(conn, %{"approval_id" => id} = params) do
    case Repo.get(Approval, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      _approval ->
        changeset =
          ApprovalComment.changeset(%ApprovalComment{}, %{
            "approval_id" => id,
            "body" => params["body"],
            "author_type" => params["author_type"],
            "author_id" => params["author_id"]
          })

        case Repo.insert(changeset) do
          {:ok, c} ->
            conn |> put_status(201) |> json(%{comment: serialize_comment(c)})

          {:error, cs} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(cs)})
        end
    end
  end

  # --- Private helpers ---

  defp serialize(%Approval{} = a) do
    %{
      id: a.id,
      title: a.title,
      description: a.description,
      status: a.status,
      decision: a.decision,
      decision_comment: a.decision_comment,
      context: a.context,
      expires_at: a.expires_at,
      requested_by: a.requested_by,
      reviewer_id: a.reviewer_id,
      workspace_id: a.workspace_id,
      created_at: a.inserted_at,
      inserted_at: a.inserted_at,
      updated_at: a.updated_at
    }
  end

  defp serialize_comment(%ApprovalComment{} = c) do
    %{
      id: c.id,
      approval_id: c.approval_id,
      body: c.body,
      author_type: c.author_type,
      author_id: c.author_id,
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
