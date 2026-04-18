defmodule Canopy.Files.FileRecord do
  @moduledoc """
  Ecto schema for an indexed file.

  Named `FileRecord` (not `File`) to avoid collision with the Elixir stdlib
  `File` module. The underlying table is `files`.

  A `FileRecord` is a metadata index entry — it does not store binary content.
  Binary content lives on the filesystem at `workspace.root_path <> "/" <> path`.
  `Canopy.Workspaces.Files` is the low-level I/O API for reading/writing bytes.

  ## Key fields

  - `workspace_id` — FK to `workspaces.id`. All files are workspace-scoped.
  - `path` — Relative path within the workspace root, e.g. `"docs/intro.md"`.
  - `name` — Filename component only, e.g. `"intro.md"`.
  - `sha256` — SHA-256 hex digest; used to detect content changes and skip
    redundant re-indexing in `Canopy.Files.index_workspace/1`.
  - `owner_type` — `"user"` | `"agent"` | `"system"`.
  - `tags` — User/agent-assignable labels for filtering.
  - `archived_at` — Soft-archive; file stays on disk, hidden from default listings.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Canopy.Workspaces.Workspace

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_owner_types ~w(user agent system)

  @derive {Jason.Encoder,
           only: [
             :id,
             :workspace_id,
             :path,
             :name,
             :extension,
             :mime_type,
             :size_bytes,
             :sha256,
             :owner_type,
             :owner_id,
             :tags,
             :last_indexed_at,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "files" do
    field :path, :string
    field :name, :string
    field :extension, :string
    field :mime_type, :string, default: "application/octet-stream"
    field :size_bytes, :integer, default: 0
    field :sha256, :string
    field :owner_type, :string, default: "system"
    field :owner_id, :string
    field :tags, {:array, :string}, default: []
    field :last_indexed_at, :utc_datetime
    field :archived_at, :utc_datetime

    belongs_to :workspace, Workspace

    has_many :activities, Canopy.Files.Activity, foreign_key: :file_id

    timestamps()
  end

  @required ~w(workspace_id path name mime_type)a
  @optional ~w(extension size_bytes sha256 owner_type owner_id tags last_indexed_at archived_at)a

  @doc "Changeset for creating a new file index entry."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(file, attrs) do
    file
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:path, min: 1, max: 2048)
    |> validate_length(:name, min: 1, max: 512)
    |> validate_inclusion(:owner_type, @valid_owner_types)
    |> validate_number(:size_bytes, greater_than_or_equal_to: 0)
    |> unique_constraint([:workspace_id, :path],
      name: :files_workspace_id_path_index,
      message: "file already indexed at this path"
    )
    |> foreign_key_constraint(:workspace_id)
  end

  @doc """
  Changeset for updating file metadata.

  Accepts: size, sha256, mime, extension, path, name, last_indexed_at, tags,
  owner fields. Used for re-indexing after content changes and for rename operations.
  """
  @spec update_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_changeset(file, attrs) do
    file
    |> cast(
      attrs,
      ~w(path name size_bytes sha256 mime_type extension last_indexed_at tags owner_type owner_id)a
    )
    |> validate_inclusion(:owner_type, @valid_owner_types)
    |> validate_number(:size_bytes, greater_than_or_equal_to: 0)
  end

  @doc "Changeset for archiving a file (soft-delete)."
  @spec archive_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def archive_changeset(file) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(file, archived_at: now)
  end

  @doc "Changeset for updating tags only."
  @spec tags_changeset(%__MODULE__{}, [String.t()]) :: Ecto.Changeset.t()
  def tags_changeset(file, tags) when is_list(tags) do
    change(file, tags: tags)
  end
end
