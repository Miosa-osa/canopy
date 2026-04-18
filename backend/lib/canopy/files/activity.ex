defmodule Canopy.Files.Activity do
  @moduledoc """
  Ecto schema for file activity log entries.

  The `file_activity` table is append-only. Rows are never updated or deleted
  (soft or otherwise). The application layer must enforce this convention.

  ## Actions

  - `"created"` — file was first indexed
  - `"updated"` — file content changed (sha256 differed on re-index)
  - `"read"` — file content was read (throttled: once per actor per hour)
  - `"deleted"` — file was archived (soft-delete)
  - `"renamed"` — file was moved; metadata contains `old_path` and `new_path`
  - `"tagged"` — tags were updated; metadata contains `added` and `removed` lists

  ## Actor types

  `actor_type` is `"user"` | `"agent"` | `"system"`. `actor_id` is the
  UUID or slug of the specific actor.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @valid_actions ~w(created updated read deleted renamed tagged)
  @valid_actor_types ~w(user agent system)

  @derive {Jason.Encoder,
           only: [
             :id,
             :file_id,
             :actor_type,
             :actor_id,
             :action,
             :metadata,
             :occurred_at,
             :inserted_at
           ]}

  schema "file_activity" do
    field :actor_type, :string
    field :actor_id, :string
    field :action, :string
    field :metadata, :map, default: %{}
    field :occurred_at, :utc_datetime_usec

    belongs_to :file, Canopy.Files.FileRecord

    # Append-only — no updated_at
    timestamps(type: :utc_datetime, updated_at: false)
  end

  # actor_id is required for user and agent actors but empty-string is valid
  # for system actors (no specific entity). DB column is NOT NULL — we store
  # empty string "" for system events rather than nil.
  @required ~w(file_id actor_type action occurred_at)a
  @optional ~w(actor_id metadata)a

  @doc "Changeset for inserting an activity log entry."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:action, @valid_actions,
      message: "must be one of: #{Enum.join(@valid_actions, ", ")}"
    )
    |> validate_inclusion(:actor_type, @valid_actor_types,
      message: "must be one of: #{Enum.join(@valid_actor_types, ", ")}"
    )
    |> put_default_actor_id()
    |> foreign_key_constraint(:file_id)
  end

  # Ensures actor_id is never nil — system events get "" as actor_id.
  defp put_default_actor_id(changeset) do
    case get_field(changeset, :actor_id) do
      nil -> put_change(changeset, :actor_id, "")
      _ -> changeset
    end
  end
end
