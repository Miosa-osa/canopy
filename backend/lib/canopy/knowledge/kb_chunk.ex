defmodule Canopy.Knowledge.KbChunk do
  @moduledoc """
  Ecto schema for a single chunk within a knowledge base.

  Each chunk holds a slice of text derived from a source file (or direct upload),
  its SHA256 content hash for deduplication, an approximate token count, and a
  pgvector `embedding` for cosine-similarity search.

  The `source_file_id` FK is nullable — chunks sourced from Files.FileRecord carry
  the ID; directly-uploaded content leaves it NULL and uses `source_path` only.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime]

  @derive {Jason.Encoder,
           only: [
             :id,
             :kb_id,
             :source_file_id,
             :source_path,
             :chunk_index,
             :content,
             :content_hash,
             :token_count,
             :metadata,
             :inserted_at
           ]}

  schema "kb_chunks" do
    belongs_to :knowledge_base, Canopy.Knowledge.KnowledgeBase, foreign_key: :kb_id

    field :source_file_id, :binary_id
    field :source_path, :string
    field :chunk_index, :integer
    field :content, :string
    field :content_hash, :string
    field :token_count, :integer, default: 0
    field :embedding, Pgvector.Ecto.Vector
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  @required ~w(kb_id source_path chunk_index content content_hash)a
  @optional ~w(source_file_id token_count embedding metadata)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_number(:chunk_index, greater_than_or_equal_to: 0)
    |> validate_number(:token_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:kb_id, :source_path, :chunk_index],
      name: :kb_chunks_kb_source_chunk_idx
    )
  end
end
