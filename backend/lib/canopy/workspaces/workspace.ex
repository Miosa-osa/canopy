defmodule Canopy.Workspaces.Workspace do
  @moduledoc """
  Ecto schema for a Canopy workspace (Week 1 minimal stub).

  A workspace is a directory on the user's filesystem (or MIOSA sandbox) that
  follows the Canopy Workspace Protocol: structured markdown folders defining
  org context, goals, agent assignments, and active tasks.

  The `slug` is the stable URL-safe identifier. The `root_path` is the absolute
  filesystem path that the workspace protocol maps onto.

  Full workspace protocol parsing and MIOSA sandbox integration are Week 2 scope.
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
             :name,
             :description,
             :root_path,
             :template,
             :deleted_at,
             :inserted_at,
             :updated_at
           ]}

  schema "workspaces" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :root_path, :string
    field :template, :string
    field :deleted_at, :utc_datetime

    timestamps()
  end

  @required ~w(slug name root_path)a
  @optional ~w(description template)a

  @doc "Changeset for creating or updating a workspace."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, min: 1, max: 128)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/)
    |> validate_length(:name, min: 1, max: 256)
    |> validate_length(:root_path, min: 1, max: 1024)
    |> unique_constraint(:slug)
  end

  @doc "Changeset for soft-deleting a workspace."
  @spec delete_changeset(%__MODULE__{}) :: Ecto.Changeset.t()
  def delete_changeset(workspace) do
    change(workspace, deleted_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
