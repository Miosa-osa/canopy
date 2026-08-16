defmodule Canopy.Drive.Entry do
  @moduledoc """
  Polymorphic Drive entry.

  Drive is the unified shell over Canopy's typed knowledge primitives. An
  entry's `kind` field selects the body interpretation; for kinds that point
  at existing primitives, the body is a foreign-key envelope — the primitive
  itself is **not** duplicated.

  ## Kinds and body shapes

  | kind         | body                                                          |
  |--------------|---------------------------------------------------------------|
  | `folder`     | `%{}` (organizational only — name + parent are top-level)     |
  | `workflow`   | `%{"routine_id" => uuid}` link to `Canopy.Routines.Routine`   |
  | `prompt`     | `%{"body" => string, "variables" => [...]}` (new primitive)   |
  | `notebook`   | `%{"session_id" => uuid, "block_ids" => [uuid]}` link to Block|
  | `env_vars`   | `%{"vault_secret_ids" => [string]}` link to `Canopy.Vault`    |
  | `mcp_server` | `%{"mcp_server_id" => string}` link to MCP registry (Phase B) |
  | `rule`       | `%{"body" => string, "applies_to" => [slug]}` (new primitive) |

  ## Scopes

  - `personal` — visible only to `owner_id`
  - `team`     — workspace-shared

  ## Slug uniqueness

  Slugs are unique within `(scope, parent_id)`. The same slug can exist in
  Personal vs Team, or in two different folders.

  ## Position and tree

  `position` is an integer per `(scope, parent_id)` group used for drag-to-
  reorder. The `Canopy.Drive` context preserves contiguous integer order on
  reorder; the schema only enforces non-negative.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @kinds ~w(folder workflow prompt notebook env_vars mcp_server rule)
  @scopes ~w(personal team)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :kind,
             :scope,
             :parent_id,
             :body,
             :owner_id,
             :tags,
             :position,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "drive_entries" do
    field :slug, :string
    field :name, :string
    field :kind, :string
    field :scope, :string, default: "personal"
    field :parent_id, :binary_id
    field :body, :map, default: %{}
    field :owner_id, :binary_id
    field :tags, {:array, :string}, default: []
    field :position, :integer, default: 0
    field :archived_at, :utc_datetime_usec

    timestamps()
  end

  @required ~w(slug name kind scope)a
  @optional ~w(parent_id body owner_id tags position archived_at)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, max: 128)
    |> validate_length(:name, max: 256)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:scope, @scopes)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/,
      message: "must be lowercase alphanumeric, dashes, underscores; max 128 chars"
    )
    |> validate_body_for_kind()
    |> unique_constraint(:slug,
      name: :drive_entries_scope_parent_slug_index,
      message: "has already been taken in this scope and folder"
    )
  end

  # Body shape validation — minimal, enforces that the foreign-key envelopes
  # are present for link-kinds. Standalone kinds (folder/prompt/rule) accept
  # any map; deeper validation is the caller's job.
  defp validate_body_for_kind(changeset) do
    case get_field(changeset, :kind) do
      "workflow" -> require_body_keys(changeset, ["routine_id"])
      "notebook" -> require_body_keys(changeset, ["session_id"])
      "env_vars" -> require_body_keys(changeset, ["vault_secret_ids"])
      "mcp_server" -> require_body_keys(changeset, ["mcp_server_id"])
      _ -> changeset
    end
  end

  defp require_body_keys(changeset, keys) do
    body = get_field(changeset, :body) || %{}

    missing =
      Enum.reject(keys, fn key ->
        Map.has_key?(body, key) or Map.has_key?(body, String.to_atom(key))
      end)

    if missing == [] do
      changeset
    else
      add_error(changeset, :body, "missing required keys for kind: #{Enum.join(missing, ", ")}")
    end
  end

  def kinds, do: @kinds
  def scopes, do: @scopes
end
