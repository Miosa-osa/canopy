defmodule Canopy.Templates.Instantiation do
  @moduledoc """
  Audit + provenance record of a single template instantiation.

  Every time `templates.instantiate` runs, an Instantiation row is written
  recording: the source template (id + slug + version), the resolved
  parameter map, the target workspace slug / path, what got created (file /
  agent / skill counts), the success status, and the actor (an agent id for
  programmatic instantiations, or a string identifier for user-driven ones).

  Status lifecycle:

  - `"pending"` — accepted, render in progress
  - `"success"` — workspace materialized, all sub-installs succeeded
  - `"partial"` — workspace materialized, some sub-installs failed (recorded
    in `error`)
  - `"failed"` — instantiation aborted; no files written

  These records back the `instantiated_from: <slug>@<version>` provenance
  contract that every materialized workspace claims in its `company.yaml`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @statuses ~w(pending success partial failed)

  @derive {Jason.Encoder,
           only: [
             :id,
             :template_id,
             :template_slug,
             :template_version,
             :target_workspace_slug,
             :target_path,
             :params,
             :files_written,
             :agents_created,
             :skills_installed,
             :status,
             :error,
             :instantiated_by_agent_id,
             :instantiated_by,
             :inserted_at,
             :updated_at
           ]}

  schema "template_instantiations" do
    field :template_id, :binary_id
    field :template_slug, :string
    field :template_version, :string
    field :target_workspace_slug, :string
    field :target_path, :string
    field :params, :map, default: %{}
    field :files_written, :integer, default: 0
    field :agents_created, :integer, default: 0
    field :skills_installed, :integer, default: 0
    field :status, :string, default: "pending"
    field :error, :string
    field :instantiated_by_agent_id, :binary_id
    field :instantiated_by, :string

    timestamps()
  end

  @required ~w(template_slug template_version status)a
  @optional ~w(template_id target_workspace_slug target_path params files_written agents_created skills_installed error instantiated_by_agent_id instantiated_by)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:template_slug, max: 128)
    |> validate_length(:template_version, max: 32)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:files_written, greater_than_or_equal_to: 0)
    |> validate_number(:agents_created, greater_than_or_equal_to: 0)
    |> validate_number(:skills_installed, greater_than_or_equal_to: 0)
  end

  def statuses, do: @statuses
end
