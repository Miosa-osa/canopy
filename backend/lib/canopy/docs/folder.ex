defmodule Canopy.Docs.Folder do
  @moduledoc """
  Ecto schema for a document folder (hierarchical via self-referential FK).

  Folders organise documents within a workspace. The hierarchy is unbounded in
  the database (self-ref FK), but the application recommends a practical limit
  of 5 levels deep for UX clarity.

  ## Ownership

  A folder may be owned by either a user (`owner_user_id`) or an agent
  (`owner_agent_slug`). Both being nil means workspace-level (shared) ownership.
  The changeset does not enforce mutual exclusivity — either or both may be nil.

  ## Archiving

  Soft-archive via `archived_at`. `Canopy.Docs.archive_folder/1` sets this.
  Archived folders are excluded from `list_folders/1` by default.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :parent_id,
             :workspace_slug,
             :owner_user_id,
             :owner_agent_slug,
             :color,
             :sort_order,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "doc_folders" do
    field :name, :string
    field :workspace_slug, :string
    field :owner_user_id, :binary_id
    field :owner_agent_slug, :string
    field :color, :string
    field :sort_order, :integer, default: 0
    field :archived_at, :utc_datetime

    belongs_to :parent, Canopy.Docs.Folder, foreign_key: :parent_id
    has_many :children, Canopy.Docs.Folder, foreign_key: :parent_id
    has_many :documents, Canopy.Docs.Document, foreign_key: :folder_id

    timestamps()
  end

  @required ~w(name workspace_slug)a
  @optional ~w(parent_id owner_user_id owner_agent_slug color sort_order archived_at)a

  @doc "Changeset for creating or updating a folder."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(folder, attrs) do
    folder
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 1, max: 255)
    |> foreign_key_constraint(:parent_id)
  end

  @doc "Changeset for archiving a folder (sets archived_at to now)."
  @spec archive_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def archive_changeset(folder) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(folder, archived_at: now)
  end
end
