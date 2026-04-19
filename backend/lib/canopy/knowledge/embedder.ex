defmodule Canopy.Knowledge.Embedder do
  @moduledoc """
  Embedding provider interface — Phase 5 Wave 2 STUB.

  Returns a deterministic zero vector of the configured dimensionality.
  Replace the `embed/2` implementation with a real provider call to swap in
  OpenAI, Anthropic, or a local model — the signature and return shape are
  stable and designed for that one-file swap.

  # TODO: wire real embedding provider
  #
  # Swap pattern:
  #   1. Replace the zero-vector body of `embed/2` with an HTTP call:
  #        Req.post!("https://api.openai.com/v1/embeddings",
  #          json: %{input: text, model: model},
  #          headers: [{"authorization", "Bearer " <> api_key}]
  #        )
  #   2. Extract the vector from the response: `body["data"][0]["embedding"]`
  #   3. Return `{:ok, vector}` or `{:error, reason}` — no callers change.
  #   4. Add retry / backoff in this module only (no changes in Knowledge context).
  #
  # All callers use: `{:ok, vec} = Embedder.embed(text, 1536)`
  """

  @doc """
  Embeds `text` into a float vector of `dimensions` length.

  STUB: returns a zero vector. Cosine similarity between two zero vectors is
  undefined / degenerate — search results with the stub will be ordered by
  insertion order (chunk_index ascending) rather than semantic relevance.

  ## Parameters
    - `text` — the string to embed
    - `dimensions` — output vector size (default 1536 for text-embedding-3-small)

  ## Returns
    `{:ok, [float()]}` — always succeeds with stub.
  """
  @spec embed(String.t(), pos_integer()) :: {:ok, [float()]}
  def embed(_text, dimensions \\ 1536) do
    # TODO: wire real embedding provider — replace this line only
    vector = List.duplicate(0.0, dimensions)
    {:ok, vector}
  end
end
