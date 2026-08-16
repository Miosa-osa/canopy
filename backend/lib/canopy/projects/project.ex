defmodule Canopy.Projects.Project do
  @moduledoc "Ecto schema for a project — a named container for Issues, Tasks, and Goals."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_statuses ~w(active paused archived)
  @valid_owner_types ~w(agent human)

  @derive {Jason.Encoder,
           only: [
             :id,
             :slug,
             :name,
             :description,
             :workspace_slug,
             :status,
             :color,
             :icon,
             :owner_type,
             :owner_id,
             :target_date,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "projects" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :workspace_slug, :string
    field :status, :string, default: "active"
    field :color, :string
    field :icon, :string
    field :owner_type, :string
    field :owner_id, :string
    field :target_date, :utc_datetime
    field :archived_at, :utc_datetime

    timestamps()
  end

  @required ~w(name workspace_slug)a
  @optional ~w(slug description status color icon owner_type owner_id target_date archived_at)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(project, attrs) do
    project
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:name, min: 1, max: 200)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$/,
      message: "must be lowercase alphanumeric with hyphens"
    )
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/, message: "must be a 6-digit hex color")
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:owner_type, @valid_owner_types, message: "must be agent or human")
    |> put_slug_if_missing()
    |> unique_constraint(:slug)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp put_slug_if_missing(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name) || get_field(changeset, :name)

        if name do
          slug = slugify(name)
          put_change(changeset, :slug, slug)
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp slugify(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s]+/, "-")
    |> String.replace(~r/-{2,}/, "-")
    |> String.trim("-")
    |> then(fn s ->
      if String.length(s) < 2, do: s <> "-project", else: s
    end)
  end
end
