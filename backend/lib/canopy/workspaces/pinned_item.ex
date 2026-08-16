defmodule Canopy.Workspaces.PinnedItem do
  @moduledoc """
  Ecto schema for a pinned item in a workspace sidebar.

  Each row represents a user-pinned reference (task, issue, doc, etc.) within a
  specific workspace, ordered by `position` for drag-to-reorder support.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [:id, :workspace_slug, :item_type, :item_ref, :position, :inserted_at]}

  schema "pinned_items" do
    field :workspace_slug, :string
    field :item_type, :string
    field :item_ref, :string
    field :position, :integer, default: 0

    timestamps()
  end

  @required ~w(workspace_slug item_type item_ref)a
  @optional ~w(position)a

  @doc "Changeset for creating a pinned item."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(pin, attrs) do
    pin
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:workspace_slug, min: 1, max: 128)
    |> validate_inclusion(:item_type, ~w(task issue doc session project))
    |> validate_length(:item_ref, min: 1, max: 256)
    |> unique_constraint([:workspace_slug, :item_type, :item_ref],
         name: :pinned_items_workspace_type_ref_idx
       )
  end
end
