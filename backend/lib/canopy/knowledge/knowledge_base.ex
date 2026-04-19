defmodule Canopy.Knowledge.KnowledgeBase do
  @moduledoc """
  Ecto schema for a knowledge base.

  A knowledge base is a named collection of chunked, embedded documents.
  Chunks are stored in `kb_chunks` with pgvector embeddings for cosine-similarity
  retrieval. KBs are optionally scoped to a workspace and assigned to agents via
  `kb_agent_assignments`.
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
             :workspace_slug,
             :embedding_model,
             :dimensions,
             :chunk_size,
             :chunk_overlap,
             :archived_at,
             :inserted_at,
             :updated_at
           ]}

  schema "knowledge_bases" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :workspace_slug, :string

    field :embedding_model, :string, default: "text-embedding-3-small"
    field :dimensions, :integer, default: 1536
    field :chunk_size, :integer, default: 800
    field :chunk_overlap, :integer, default: 100

    field :archived_at, :utc_datetime

    has_many :chunks, Canopy.Knowledge.KbChunk, foreign_key: :kb_id
    has_many :assignments, Canopy.Knowledge.KbAgentAssignment, foreign_key: :kb_id

    timestamps()
  end

  @required ~w(slug name)a
  @optional ~w(description workspace_slug embedding_model dimensions chunk_size chunk_overlap archived_at)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(kb, attrs) do
    kb
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:slug, min: 1, max: 128)
    |> validate_format(:slug, ~r/\A[a-z0-9][a-z0-9\-]*[a-z0-9]\z|\A[a-z0-9]\z/)
    |> validate_length(:name, min: 1, max: 256)
    |> validate_number(:dimensions, greater_than: 0)
    |> validate_number(:chunk_size, greater_than: 0)
    |> validate_number(:chunk_overlap, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
  end
end
