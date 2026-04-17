defmodule Canopy.Runtimes.Runtime do
  @moduledoc """
  Ecto schema representing a discovered AI runtime on the user's machine.

  Each runtime corresponds to one adapter type (e.g., `"claude-local"`) and
  tracks detection state: whether the binary exists, what version it reports,
  where it lives on disk, and which adapter capabilities are available.

  Detection is performed by the Rust sidecar (PATH scanning) and written back
  via `Canopy.Runtimes.upsert_from_detection/1`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :type,
             :kind,
             :name,
             :enabled,
             :installed,
             :version,
             :binary_path,
             :config,
             :capabilities,
             :last_detected_at,
             :inserted_at,
             :updated_at
           ]}

  @valid_kinds ~w(cli api mcp)

  schema "runtimes" do
    field :type, :string
    field :kind, :string
    field :name, :string
    field :enabled, :boolean, default: true
    field :installed, :boolean, default: false
    field :version, :string
    field :binary_path, :string
    field :config, :map, default: %{}
    field :capabilities, {:array, :string}, default: []
    field :last_detected_at, :utc_datetime

    timestamps()
  end

  @required ~w(type kind name)a
  @optional ~w(enabled installed version binary_path config capabilities last_detected_at)a

  @doc "Changeset for creating or updating a runtime record."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(runtime, attrs) do
    runtime
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:type, min: 1, max: 64)
    |> validate_length(:name, min: 1, max: 128)
    |> validate_inclusion(:kind, @valid_kinds)
    |> unique_constraint(:type)
  end
end
