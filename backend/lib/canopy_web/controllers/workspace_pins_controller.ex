defmodule CanopyWeb.WorkspacePinsController do
  @moduledoc """
  HTTP API for pinned items in a workspace sidebar.

  Routes (registered in router.ex):
    GET    /api/v1/workspaces/:slug/pins           — list pins for workspace
    POST   /api/v1/workspaces/:slug/pins           — create pin
    DELETE /api/v1/workspaces/:slug/pins/:type/:ref — delete pin by type+ref
    PUT    /api/v1/workspaces/:slug/pins/reorder   — reorder (supply ordered list)
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces.PinnedItems

  action_fallback CanopyWeb.FallbackController

  tags ["workspaces"]

  operation :index,
    summary: "List pinned items for a workspace",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Pin list", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"slug" => slug}) do
    {:ok, pins} = PinnedItems.list(slug)
    json(conn, %{data: pins})
  end

  operation :create,
    summary: "Pin an item to a workspace",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [
      created: {"Pin created", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Validation error", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"slug" => slug, "item_type" => type, "item_ref" => ref}) do
    case PinnedItems.create(slug, type, ref) do
      {:ok, pin} ->
        conn
        |> put_status(:created)
        |> json(%{data: pin})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "item_type and item_ref are required"})
  end

  operation :delete,
    summary: "Unpin an item from a workspace",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      type: [in: :path, type: :string, required: true],
      ref: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: {"Deleted", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"slug" => slug, "type" => type, "ref" => ref}) do
    case PinnedItems.delete(slug, type, ref) do
      {:ok, _pin} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  operation :reorder,
    summary: "Reorder pinned items for a workspace",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Reordered", "application/json", %OpenApiSpex.Schema{type: :object}}]

  @spec reorder(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def reorder(conn, %{"slug" => slug, "items" => items}) when is_list(items) do
    :ok = PinnedItems.reorder(slug, items)
    json(conn, %{ok: true})
  end

  def reorder(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "items array is required"})
  end
end
