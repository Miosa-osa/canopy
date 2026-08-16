defmodule Canopy.Workspaces.PinnedItems do
  @moduledoc """
  Context for pinned items within a workspace sidebar.

  Pins are ordered by `position ASC`. Reordering is a bulk replace — the caller
  supplies the desired full list and we write positions 0..n-1.
  """

  import Ecto.Query

  alias Canopy.Repo
  alias Canopy.Workspaces.PinnedItem

  @doc "List all pins for a workspace, ordered by position."
  @spec list(String.t()) :: {:ok, [PinnedItem.t()]}
  def list(workspace_slug) do
    pins =
      Repo.all(
        from p in PinnedItem,
          where: p.workspace_slug == ^workspace_slug,
          order_by: [asc: p.position]
      )

    {:ok, pins}
  end

  @doc "Create a new pin. Returns error on duplicate."
  @spec create(String.t(), String.t(), String.t()) ::
          {:ok, PinnedItem.t()} | {:error, Ecto.Changeset.t()}
  def create(workspace_slug, item_type, item_ref) do
    # Assign position = max(existing) + 1
    max_pos =
      Repo.one(
        from p in PinnedItem,
          where: p.workspace_slug == ^workspace_slug,
          select: max(p.position)
      ) || -1

    attrs = %{
      workspace_slug: workspace_slug,
      item_type: item_type,
      item_ref: item_ref,
      position: max_pos + 1
    }

    %PinnedItem{}
    |> PinnedItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Delete a specific pin by type + ref."
  @spec delete(String.t(), String.t(), String.t()) :: {:ok, PinnedItem.t()} | {:error, :not_found}
  def delete(workspace_slug, item_type, item_ref) do
    case Repo.one(
           from p in PinnedItem,
             where:
               p.workspace_slug == ^workspace_slug and
                 p.item_type == ^item_type and
                 p.item_ref == ^item_ref
         ) do
      nil -> {:error, :not_found}
      pin -> Repo.delete(pin)
    end
  end

  @doc """
  Reorder pins for a workspace.

  Accepts a list of `%{id: binary_id}` in the desired order. Assigns positions
  0..n-1 in that order. Items not present in the list are left untouched.
  """
  @spec reorder(String.t(), [%{id: String.t()}]) :: :ok
  def reorder(workspace_slug, ordered_ids) do
    ordered_ids
    |> Enum.with_index()
    |> Enum.each(fn {%{"id" => id}, pos} ->
      Repo.update_all(
        from(p in PinnedItem,
          where: p.id == ^id and p.workspace_slug == ^workspace_slug
        ),
        set: [position: pos]
      )
    end)

    :ok
  end
end
