defmodule CanopyWeb.Plugs.WorkspaceAuth do
  @moduledoc """
  Validates that the current user owns (or has access to) the workspace
  referenced in the request params.

  Extracts `workspace_id` from:
    1. `params["workspace_id"]` (query string or body)
    2. Resource's `workspace_id` for show/update/delete on nested resources

  If no `workspace_id` is present in the request, the plug passes through
  (the endpoint may not be workspace-scoped). When a `workspace_id` IS
  present, the plug verifies the authenticated user owns that workspace.

  Must be placed AFTER `CanopyWeb.Plugs.Auth` in the pipeline so that
  `conn.assigns.current_user` is available.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]
  import Ecto.Query

  alias Canopy.Repo
  alias Canopy.Schemas.Workspace

  def init(opts), do: opts

  def call(conn, _opts) do
    workspace_id = conn.params["workspace_id"]
    user = conn.assigns[:current_user]

    cond do
      # No workspace_id in params — scope to all workspaces owned by the current user
      is_nil(workspace_id) or workspace_id == "" ->
        user_workspace_ids =
          Repo.all(from w in Workspace, where: w.owner_id == ^user.id, select: w.id)

        assign(conn, :user_workspace_ids, user_workspace_ids)

      # Validate ownership when workspace_id is present
      true ->
        case Repo.get(Workspace, workspace_id) do
          %Workspace{owner_id: owner_id} = workspace when owner_id == user.id ->
            conn
            |> assign(:workspace, workspace)
            |> assign(:user_workspace_ids, [workspace_id])

          %Workspace{} ->
            conn
            |> put_status(403)
            |> json(%{error: "forbidden", message: "You do not have access to this workspace"})
            |> halt()

          nil ->
            conn
            |> put_status(404)
            |> json(%{error: "not_found", message: "Workspace not found"})
            |> halt()
        end
    end
  end
end
