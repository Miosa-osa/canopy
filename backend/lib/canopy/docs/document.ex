defmodule Canopy.Docs.Document do
  @moduledoc """
  Ecto schema for a rich-text document.

  `body_text` is always derived from `body_json` by walking the ProseMirror
  node tree. `version` starts at 1 and bumps on every update (informational only
  — no optimistic lock).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :folder_id,
             :workspace_slug,
             :title,
             :body_json,
             :body_text,
             :summary,
             :author_type,
             :author_id,
             :last_editor_type,
             :last_editor_id,
             :published,
             :published_at,
             :tags,
             :version,
             :archived_at,
             :review_id,
             :inserted_at,
             :updated_at
           ]}

  schema "documents" do
    field :slug, :string
    field :workspace_slug, :string
    field :title, :string
    field :body_json, :map, default: %{}
    field :body_text, :string, default: ""
    field :summary, :string
    field :author_type, :string
    field :author_id, :string
    field :last_editor_type, :string
    field :last_editor_id, :string
    field :published, :boolean, default: false
    field :published_at, :utc_datetime
    field :tags, {:array, :string}, default: []
    field :version, :integer, default: 1
    field :archived_at, :utc_datetime
    field :review_id, :binary_id

    belongs_to :folder, Canopy.Docs.Folder

    timestamps()
  end

  @required ~w(slug workspace_slug title author_type author_id last_editor_type last_editor_id)a
  @optional ~w(folder_id body_json summary published published_at tags version archived_at review_id)a

  @doc "Changeset for creating a document. Derives body_text from body_json."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(document, attrs) do
    document
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, min: 1, max: 512)
    |> validate_length(:slug, min: 1, max: 255)
    |> validate_number(:version, greater_than: 0)
    |> derive_body_text()
    |> unique_constraint([:slug, :workspace_slug])
    |> foreign_key_constraint(:folder_id)
  end

  @doc "Changeset for updating a document. Bumps version and re-derives body_text."
  @spec update_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_changeset(document, attrs) do
    document
    |> cast(attrs, [
      :title,
      :body_json,
      :summary,
      :tags,
      :last_editor_type,
      :last_editor_id,
      :folder_id
    ])
    |> validate_length(:title, min: 1, max: 512)
    |> derive_body_text()
    |> bump_version()
    |> foreign_key_constraint(:folder_id)
  end

  @doc "Changeset for publishing a document."
  @spec publish_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def publish_changeset(document) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(document, published: true, published_at: now)
  end

  @doc "Changeset for unpublishing a document."
  @spec unpublish_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def unpublish_changeset(document) do
    change(document, published: false, published_at: nil)
  end

  @doc "Changeset for archiving a document."
  @spec archive_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def archive_changeset(document) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(document, archived_at: now)
  end

  @doc "Changeset for unarchiving a document."
  @spec unarchive_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def unarchive_changeset(document) do
    change(document, archived_at: nil)
  end

  # ---------------------------------------------------------------------------
  # Private — body_text derivation (walks ProseMirror JSON tree)
  # ---------------------------------------------------------------------------

  defp derive_body_text(changeset) do
    case get_change(changeset, :body_json) do
      nil ->
        if get_field(changeset, :body_text) == nil do
          put_change(changeset, :body_text, "")
        else
          changeset
        end

      body_json ->
        put_change(changeset, :body_text, extract_body_text(body_json))
    end
  end

  defp bump_version(changeset) do
    current = get_field(changeset, :version) || 1
    put_change(changeset, :version, current + 1)
  end

  defp extract_body_text(nil), do: ""
  defp extract_body_text(doc) when not is_map(doc), do: ""

  defp extract_body_text(doc) do
    doc
    |> walk()
    |> IO.iodata_to_binary()
    |> String.trim_trailing()
  end

  defp walk(%{"type" => "doc"} = node), do: walk_children(node)
  defp walk(%{"type" => "paragraph"} = node), do: [walk_children(node), "\n"]
  defp walk(%{"type" => "heading"} = node), do: [walk_children(node), "\n"]
  defp walk(%{"type" => "bulletList"} = node), do: walk_children(node)
  defp walk(%{"type" => "orderedList"} = node), do: walk_children(node)
  defp walk(%{"type" => "listItem"} = node), do: [walk_children(node), "\n"]
  defp walk(%{"type" => "codeBlock"} = node), do: [walk_children(node), "\n"]
  defp walk(%{"type" => "blockquote"} = node), do: walk_children(node)
  defp walk(%{"type" => "text", "text" => text}) when is_binary(text), do: text
  defp walk(_node), do: []

  defp walk_children(%{"content" => children}) when is_list(children) do
    Enum.map(children, &walk/1)
  end

  defp walk_children(_node), do: []
end
