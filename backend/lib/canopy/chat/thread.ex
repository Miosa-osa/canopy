defmodule Canopy.Chat.Thread do
  @moduledoc """
  Ecto schema for a chat thread.

  A thread coordinates one or more Sessions. `last_session_id` points to the most
  recent Session; continuations are tracked via `parent_session_id` on Sessions.
  No junction table.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Canopy.Sessions.Session

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :title,
             :user_id,
             :agent_slug,
             :runtime_type,
             :model_id,
             :workspace_slug,
             :last_session_id,
             :last_message_at,
             :pinned,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "chat_threads" do
    field :title, :string
    field :user_id, :binary_id
    field :agent_slug, :string
    field :runtime_type, :string
    field :model_id, :string
    field :workspace_slug, :string
    field :last_message_at, :utc_datetime
    field :pinned, :boolean, default: false
    field :archived_at, :utc_datetime

    belongs_to :last_session, Session, foreign_key: :last_session_id

    timestamps()
  end

  @required ~w(runtime_type)a
  @optional ~w(title user_id agent_slug model_id workspace_slug last_session_id
               last_message_at pinned archived_at)a

  @doc "Changeset for creating a new thread."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(thread, attrs) do
    thread
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, max: 255, allow_nil: true)
    |> validate_length(:runtime_type, min: 1, max: 64)
    |> foreign_key_constraint(:last_session_id)
  end

  @doc "Changeset for updating mutable display fields."
  @spec update_changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def update_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:title, :pinned, :archived_at, :last_session_id, :last_message_at])
    |> validate_length(:title, max: 255, allow_nil: true)
    |> foreign_key_constraint(:last_session_id)
  end
end
