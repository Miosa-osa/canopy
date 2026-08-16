defmodule Canopy.SandboxesNg.Snapshot do
  @moduledoc """
  A captured snapshot of a sandbox's state.

  Three kinds with distinct retention semantics:

  - `"filesystem"` — full FS image, indefinite retention. Composable into
    new sandboxes via `sandbox.fork` or as a template.
  - `"directory"` — scoped to a path, 30-day default retention.
  - `"memory"` — full process state, 7-day default retention. Restores fast
    but expires fastest.

  Snapshots may be derived from other snapshots via `parent_snapshot_id`,
  forming a parent → child chain. Parents are locked while descendants
  exist (cannot be deleted without cascade).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(filesystem directory memory)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :sandbox_id,
             :kind,
             :name,
             :image_uri,
             :path,
             :size_bytes,
             :parent_snapshot_id,
             :created_by_agent_id,
             :workspace_slug,
             :retention_until,
             :reaped_at,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "sandbox_snapshots" do
    field :slug, :string
    field :sandbox_id, :string
    field :kind, :string
    field :name, :string
    field :image_uri, :string
    field :path, :string
    field :size_bytes, :integer
    field :parent_snapshot_id, :binary_id
    field :created_by_agent_id, :binary_id
    field :workspace_slug, :string
    field :retention_until, :utc_datetime_usec
    field :reaped_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required ~w(slug sandbox_id kind)a
  @optional ~w(name image_uri path size_bytes parent_snapshot_id created_by_agent_id workspace_slug retention_until reaped_at metadata)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:sandbox_id, max: 128)
    |> validate_inclusion(:kind, @kinds)
    |> validate_number(:size_bytes, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end

  def kinds, do: @kinds
end
