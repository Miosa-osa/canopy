defmodule Canopy.Repo do
  use Ecto.Repo,
    otp_app: :canopy,
    adapter: Ecto.Adapters.Postgres

  # Register pgvector Postgrex extension so the `vector` type is handled.
  # Required for file_embeddings.embedding (vector(1536)) queries.
  def init(_type, config) do
    {:ok, Keyword.put(config, :types, Canopy.PostgrexTypes)}
  end
end

# Custom Postgrex types module that includes the pgvector extension.
# Defined here to keep pgvector registration co-located with the Repo.
Postgrex.Types.define(
  Canopy.PostgrexTypes,
  [Pgvector.Extensions.Vector] ++ Ecto.Adapters.Postgres.extensions(),
  []
)
