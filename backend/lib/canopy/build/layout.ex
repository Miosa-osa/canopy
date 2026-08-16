defmodule Canopy.Build.Layout do
  @moduledoc """
  A saved Mosaic layout for the **Build super-super-module**.

  Build is the agentic development cockpit at `/build`. It composes the
  existing Mosaic layout, the Block Stream, the Code Editor / File Viewer /
  Diff / Terminal / MCP panes, the Composer footer, and a runtime agent
  (Conductor) into a single operational environment. A `Layout` record is
  the persisted snapshot of one such configuration — the user's saved
  arrangement plus default pane preferences.

  ## Scopes

  - `"personal"` — owned by a single user
  - `"team"` — shared inside an org boundary
  - `"workspace"` — pinned to a specific workspace_slug

  Slug uniqueness is enforced per (slug, scope, owner_id) so two users can
  both have a `"review-pr"` personal layout without colliding.

  ## Density

  Affects pane chrome / line-height. Three steps mirroring the global
  density preference:

  - `"compact"` — minimal padding, denser tabs
  - `"comfortable"` — default
  - `"roomy"` — generous padding, larger fonts

  ## Pane title format

  Determines what a pane titles itself by:

  - `"command"` — the command being run (terminal) or file basename
  - `"cwd"` — the current working directory
  - `"branch"` — the active git branch

  ## Use telemetry

  `last_used_at` and `use_count` feed `Canopy.Build.suggest_layout/1` —
  the Conductor uses these to rank candidate layouts when the user states
  an intent (e.g. "fix bug" → suggest the layout with the highest
  recent-use score whose name or description matches).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @scopes ~w(personal team workspace)
  @densities ~w(compact comfortable roomy)
  @title_formats ~w(command cwd branch)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :scope,
             :owner_id,
             :workspace_slug,
             :layout_json,
             :default_pane_kind,
             :density,
             :pane_title_format,
             :description,
             :archived_at,
             :last_used_at,
             :use_count,
             :inserted_at,
             :updated_at
           ]}

  schema "build_layouts" do
    field :slug, :string
    field :name, :string
    field :scope, :string, default: "personal"
    field :owner_id, :binary_id
    field :workspace_slug, :string
    field :layout_json, :map, default: %{}
    field :default_pane_kind, :string
    field :density, :string, default: "comfortable"
    field :pane_title_format, :string, default: "command"
    field :description, :string
    field :archived_at, :utc_datetime_usec
    field :last_used_at, :utc_datetime_usec
    field :use_count, :integer, default: 0

    timestamps()
  end

  @required ~w(slug name)a
  @optional ~w(scope owner_id workspace_slug layout_json default_pane_kind density pane_title_format description archived_at last_used_at use_count)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_inclusion(:scope, @scopes)
    |> validate_inclusion(:density, @densities)
    |> validate_inclusion(:pane_title_format, @title_formats)
    |> validate_number(:use_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:slug, :scope, :owner_id],
      name: :build_layouts_slug_scope_owner_index
    )
  end

  def scopes, do: @scopes
  def densities, do: @densities
  def title_formats, do: @title_formats
end
