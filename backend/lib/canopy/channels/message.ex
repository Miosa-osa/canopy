defmodule Canopy.Channels.Message do
  @moduledoc """
  Ecto schema for the `channel_messages` table.

  Changesets:
  - `changeset/2` — create message: channel_id, author_type, author_id, body_markdown,
    optional reply_to_id, attachments.
  - `edit_changeset/2` — update body_markdown, sets edited_at.
  - `soft_delete_changeset/1` — sets deleted_at, clears body to "[deleted]". Irreversible.
  - `increment_thread_count/1` — add 1 to thread_count (applied via Repo.update_all in tx).
  - `set_mentions_changeset/2` — stores parsed mention slugs.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias __MODULE__

  @type t :: %Message{
          id: Ecto.UUID.t() | nil,
          channel_id: Ecto.UUID.t() | nil,
          author_type: String.t() | nil,
          author_id: String.t() | nil,
          body_markdown: String.t() | nil,
          body_rendered_html: String.t() | nil,
          reply_to_id: Ecto.UUID.t() | nil,
          thread_count: non_neg_integer() | nil,
          edited_at: DateTime.t() | nil,
          deleted_at: DateTime.t() | nil,
          mentions: [String.t()] | nil,
          attachments: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
           only: [
             :id,
             :channel_id,
             :author_type,
             :author_id,
             :body_markdown,
             :body_rendered_html,
             :reply_to_id,
             :thread_count,
             :edited_at,
             :deleted_at,
             :mentions,
             :attachments,
             :inserted_at,
             :updated_at
           ]}

  schema "channel_messages" do
    field :channel_id, :binary_id
    field :author_type, :string
    field :author_id, :string
    field :body_markdown, :string
    field :body_rendered_html, :string
    field :reply_to_id, :binary_id
    field :thread_count, :integer, default: 0
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime
    field :mentions, {:array, :string}, default: []
    field :attachments, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @required [:channel_id, :author_type, :body_markdown]
  @optional [:author_id, :reply_to_id, :body_rendered_html, :attachments, :mentions]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%Message{} = message, attrs) do
    message
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:author_type, ["user", "agent", "system"])
    |> validate_length(:body_markdown, min: 1)
  end

  @spec edit_changeset(t(), map()) :: Ecto.Changeset.t()
  def edit_changeset(%Message{} = message, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    message
    |> cast(attrs, [:body_markdown, :body_rendered_html])
    |> validate_required([:body_markdown])
    |> validate_length(:body_markdown, min: 1)
    |> put_change(:edited_at, now)
  end

  @spec soft_delete_changeset(t()) :: Ecto.Changeset.t()
  def soft_delete_changeset(%Message{} = message) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    message
    |> change(
      deleted_at: now,
      body_markdown: "[deleted]",
      body_rendered_html: nil,
      mentions: [],
      attachments: %{}
    )
  end

  @spec set_mentions_changeset(t(), [String.t()]) :: Ecto.Changeset.t()
  def set_mentions_changeset(%Message{} = message, mentions) when is_list(mentions) do
    change(message, mentions: mentions)
  end
end
