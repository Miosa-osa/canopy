defmodule Canopy.Channels.Channel do
  @moduledoc """
  Ecto schema for the `channels` table.

  Changesets:
  - `changeset/2` — create/update: slug, name, description, visibility, icon, color.
  - `archive_changeset/1` — sets archived_at to now.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type t :: %Channel{
          id: Ecto.UUID.t() | nil,
          slug: String.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil,
          visibility: String.t() | nil,
          workspace_slug: String.t() | nil,
          icon: String.t() | nil,
          color: String.t() | nil,
          created_by_user_id: Ecto.UUID.t() | nil,
          archived_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :visibility,
             :workspace_slug,
             :icon,
             :color,
             :created_by_user_id,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "channels" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :visibility, :string, default: "public"
    field :workspace_slug, :string
    field :icon, :string
    field :color, :string
    field :created_by_user_id, :binary_id
    field :archived_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @required [:slug, :name, :visibility]
  @optional [:description, :workspace_slug, :icon, :color, :created_by_user_id]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%Channel{} = channel, attrs) do
    channel
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:visibility, ["public", "private"])
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase alphanumeric with hyphens only"
    )
    |> validate_length(:name, min: 1, max: 80)
    |> unique_constraint(:slug)
  end

  @spec archive_changeset(t()) :: Ecto.Changeset.t()
  def archive_changeset(%Channel{} = channel) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    change(channel, archived_at: now)
  end
end
