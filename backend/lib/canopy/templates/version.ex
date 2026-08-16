defmodule Canopy.Templates.Version do
  @moduledoc """
  Snapshot of a template at a specific version.

  Created on every `templates.publish` call and on internal version bumps.
  Stores the full body + parameter schema at the moment of versioning so
  diffs against future versions are deterministic — even if the underlying
  template row changes.

  Diff is captured separately as a structured map (added / removed /
  modified per file) so the UI can render upgrade paths without recomputing
  the diff on every read.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @derive {Jason.Encoder,
           only: [
             :id,
             :template_id,
             :version,
             :diff,
             :body_snapshot,
             :parameters_snapshot,
             :changelog,
             :sha256,
             :authored_by,
             :authored_by_agent_id,
             :inserted_at,
             :updated_at
           ]}

  schema "template_versions" do
    field :template_id, :binary_id
    field :version, :string
    field :diff, :map, default: %{}
    field :body_snapshot, :map, default: %{}
    field :parameters_snapshot, :map, default: %{}
    field :changelog, :string
    field :sha256, :string
    field :authored_by, :string
    field :authored_by_agent_id, :binary_id

    timestamps()
  end

  @required ~w(template_id version)a
  @optional ~w(diff body_snapshot parameters_snapshot changelog sha256 authored_by authored_by_agent_id)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:version, max: 32)
    |> validate_length(:sha256, is: 64)
    |> unique_constraint([:template_id, :version])
  end
end
