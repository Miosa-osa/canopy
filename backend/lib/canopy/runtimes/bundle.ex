defmodule Canopy.Runtimes.Bundle do
  @moduledoc """
  Shared utilities for RuntimeAdapter implementations.

  Provides two primitives used by any adapter that supports content-addressed
  prompt bundles and session-ID generation:

  - `compute_key/2` — SHA-256 over the agent markdown + skills list, producing
    a 64-character hex string.  When the stored key matches the computed key on
    a resume, the adapter can skip re-sending the system prompt file, saving
    5–10K tokens per heartbeat.

  - `generate_id/0` — cryptographically random 32-character lowercase hex
    string, suitable for session IDs and other opaque identifiers.
  """

  @doc """
  Computes a SHA-256 content-addressed key from `agents_md` and `skills`.

  The key is stable: given the same agent markdown and skills list the same
  hex string is always returned.  Use it to detect whether the prompt bundle
  has changed between sessions.

  Returns `{:ok, sha256_hex}` where `sha256_hex` is a 64-character lowercase
  hexadecimal string.
  """
  @spec compute_key(String.t(), [String.t()]) :: {:ok, String.t()}
  def compute_key(agents_md, skills) when is_binary(agents_md) and is_list(skills) do
    skills_blob = Enum.join(skills, "\n")
    combined = agents_md <> "\n" <> skills_blob

    key =
      :crypto.hash(:sha256, combined)
      |> Base.encode16(case: :lower)

    {:ok, key}
  end

  @doc """
  Generates a cryptographically random, lowercase hex session ID.

  Returns a 32-character string (16 random bytes encoded as hex).
  """
  @spec generate_id() :: String.t()
  def generate_id do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end
end
