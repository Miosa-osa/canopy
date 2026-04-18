defmodule Canopy.Notifications.Notification do
  @moduledoc """
  Ecto schema for a persisted notification.

  A notification is a discrete event surfaced to a user (or agent inbox) across
  one or more delivery channels. `read_at` tracks in-app dismissal. `delivered_channels`
  records which adapters have already fired (in_app, email, system).

  `user_id` and `agent_slug` are both nullable: exactly one should be set.
  Future agent-inbox work uses `agent_slug`; current Phase 3 work uses `user_id`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :user_id,
             :agent_slug,
             :type,
             :title,
             :body,
             :icon,
             :link_path,
             :payload,
             :read_at,
             :delivered_channels,
             :inserted_at,
             :updated_at
           ]}

  schema "notifications" do
    field :user_id, :binary_id
    field :agent_slug, :string
    field :type, :string
    field :title, :string
    field :body, :string
    field :icon, :string
    field :link_path, :string
    field :payload, :map, default: %{}
    field :read_at, :utc_datetime
    field :delivered_channels, {:array, :string}, default: []

    timestamps()
  end

  @required ~w(type title body)a
  @optional ~w(user_id agent_slug icon link_path payload read_at delivered_channels)a

  @doc "Changeset for creating a new notification."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:title, max: 255)
    |> validate_length(:type, max: 100)
  end

  @doc "Changeset for marking a notification read."
  @spec mark_read_changeset(%__MODULE__{}, DateTime.t()) :: Ecto.Changeset.t()
  def mark_read_changeset(notification, read_at) do
    change(notification, read_at: read_at)
  end
end
