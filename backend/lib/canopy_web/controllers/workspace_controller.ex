defmodule CanopyWeb.WorkspaceController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Workspace, Agent, Skill, Project}
  import Ecto.Query

  def index(conn, _params) do
    user_workspace_ids = conn.assigns[:user_workspace_ids] || []

    workspaces =
      Repo.all(
        from w in Workspace,
          where: w.id in ^user_workspace_ids,
          order_by: [desc: w.inserted_at]
      )

    workspace_ids = Enum.map(workspaces, & &1.id)

    # Batch all three counts in 3 queries (not 3×N)
    agent_counts =
      Repo.all(
        from a in Agent,
          where: a.workspace_id in ^workspace_ids,
          group_by: a.workspace_id,
          select: {a.workspace_id, count(a.id)}
      )
      |> Map.new()

    skill_counts =
      Repo.all(
        from s in Skill,
          where: s.workspace_id in ^workspace_ids,
          group_by: s.workspace_id,
          select: {s.workspace_id, count(s.id)}
      )
      |> Map.new()

    project_counts =
      Repo.all(
        from p in Project,
          where: p.workspace_id in ^workspace_ids,
          group_by: p.workspace_id,
          select: {p.workspace_id, count(p.id)}
      )
      |> Map.new()

    workspaces_with_counts =
      Enum.map(workspaces, fn w ->
        %{
          id: w.id,
          name: w.name,
          description: nil,
          directory: w.path,
          path: w.path,
          status: w.status,
          owner_id: w.owner_id,
          agent_count: Map.get(agent_counts, w.id, 0),
          project_count: Map.get(project_counts, w.id, 0),
          skill_count: Map.get(skill_counts, w.id, 0),
          created_at: w.inserted_at,
          inserted_at: w.inserted_at,
          updated_at: w.updated_at
        }
      end)

    json(conn, %{workspaces: workspaces_with_counts})
  end

  def create(conn, params) do
    user = conn.assigns[:current_user]
    params = Map.put_new(params, "owner_id", user.id)

    # Frontend sends "directory" but schema expects "path"
    params =
      if params["directory"] && !params["path"] do
        Map.put(params, "path", params["directory"])
      else
        params
      end

    changeset = Workspace.changeset(%Workspace{}, params)

    case Repo.insert(changeset) do
      {:ok, workspace} ->
        init_canopy_dir(workspace.path)

        conn
        |> put_status(201)
        |> json(%{workspace: serialize(workspace)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Workspace, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workspace ->
        agent_count = Repo.aggregate(from(a in Agent, where: a.workspace_id == ^id), :count)
        skill_count = Repo.aggregate(from(s in Skill, where: s.workspace_id == ^id), :count)
        project_count = Repo.aggregate(from(p in Project, where: p.workspace_id == ^id), :count)

        json(conn, %{
          workspace:
            serialize(workspace)
            |> Map.merge(%{
              agent_count: agent_count,
              project_count: project_count,
              skill_count: skill_count
            })
        })
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Workspace, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workspace ->
        changeset = Workspace.changeset(workspace, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{workspace: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Workspace, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workspace ->
        Repo.delete!(workspace)
        json(conn, %{ok: true})
    end
  end

  def activate(conn, %{"workspace_id" => id}) do
    user = conn.assigns[:current_user]
    user_id = user.id

    case Repo.get(Workspace, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      %Workspace{owner_id: owner_id} when owner_id != user_id ->
        conn |> put_status(403) |> json(%{error: "forbidden"})

      workspace ->
        # Bulk-deactivate all others using change/2 to bypass status enum validation
        # ("inactive" is an internal transition value, not exposed in the changeset enum)
        # Scoped to the current user's workspaces only to avoid archiving other users' data.
        Repo.update_all(
          from(w in Workspace, where: w.id != ^id and w.owner_id == ^user.id),
          set: [status: "archived"]
        )

        case workspace
             |> Ecto.Changeset.change(status: "active")
             |> Repo.update() do
          {:ok, updated} ->
            Canopy.EventBus.broadcast("workspace:global", {:workspace_activated, updated.id})
            json(conn, %{workspace: serialize(updated)})

          {:error, _changeset} ->
            conn |> put_status(500) |> json(%{error: "update_failed"})
        end
    end
  end

  def agents(conn, %{"workspace_id" => id}) do
    agents =
      Repo.all(
        from a in Agent,
          where: a.workspace_id == ^id,
          order_by: [asc: a.name]
      )

    json(conn, %{agents: Enum.map(agents, &serialize_agent/1)})
  end

  def skills(conn, %{"workspace_id" => id}) do
    skills =
      Repo.all(
        from s in Skill,
          where: s.workspace_id == ^id,
          order_by: [asc: s.name]
      )

    json(conn, %{skills: Enum.map(skills, &serialize_skill/1)})
  end

  def config(conn, %{"workspace_id" => id}) do
    case Repo.get(Workspace, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workspace ->
        canopy_dir = Path.join(workspace.path, ".canopy")
        system_path = Path.join(canopy_dir, "SYSTEM.md")
        company_path = Path.join(canopy_dir, "COMPANY.md")

        system_content = if File.exists?(system_path), do: File.read!(system_path), else: nil
        company_content = if File.exists?(company_path), do: File.read!(company_path), else: nil

        json(conn, %{
          config: %{
            has_system: system_content != nil,
            has_company: company_content != nil,
            system: system_content,
            company: company_content
          }
        })
    end
  end

  # --- Private helpers ---

  defp init_canopy_dir(path) when is_binary(path) do
    canopy = Path.join(path, ".canopy")
    File.mkdir_p!(Path.join(canopy, "agents"))
    File.mkdir_p!(Path.join(canopy, "skills"))
    File.mkdir_p!(Path.join(canopy, "reference"))

    system_path = Path.join(canopy, "SYSTEM.md")

    unless File.exists?(system_path) do
      File.write!(system_path, "# System\n\nThis is the Canopy workspace system prompt.\n")
    end
  end

  defp init_canopy_dir(_), do: :ok

  defp serialize(%Workspace{} = w) do
    %{
      id: w.id,
      name: w.name,
      description: nil,
      directory: w.path,
      path: w.path,
      status: w.status,
      owner_id: w.owner_id,
      created_at: w.inserted_at,
      inserted_at: w.inserted_at,
      updated_at: w.updated_at
    }
  end

  defp serialize_agent(%Agent{} = a) do
    %{
      id: a.id,
      slug: a.slug,
      name: a.name,
      role: a.role,
      adapter: a.adapter,
      model: a.model,
      status: a.status,
      temperature: a.temperature,
      max_concurrent_runs: a.max_concurrent_runs,
      reports_to: a.reports_to,
      inserted_at: a.inserted_at,
      updated_at: a.updated_at
    }
  end

  defp serialize_skill(%Skill{} = s) do
    %{
      id: s.id,
      name: s.name,
      description: s.description,
      category: s.category,
      enabled: s.enabled,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
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
