defmodule Canopy.Knowledge.Chunker do
  @moduledoc """
  Naive paragraph-first text chunker.

  Algorithm:
    1. Split on double newlines (paragraph boundaries).
    2. Accumulate paragraphs into a chunk until `chunk_size` tokens would be exceeded.
    3. When a single paragraph exceeds `chunk_size` alone, split it on whitespace into
       word-level sub-chunks of `chunk_size` tokens.
    4. Carry the last `overlap` tokens of the previous chunk forward into the next.

  Token approximation: 1 token ≈ 4 characters. This is the GPT-3/4 rule-of-thumb and
  is accurate within ~15% for English prose. Replace with a real tokenizer when
  embedding provider is wired.

  Returns a list of maps:
    %{content: String.t(), chunk_index: non_neg_integer(), token_count: non_neg_integer()}
  """

  @type chunk_result :: %{
          content: String.t(),
          chunk_index: non_neg_integer(),
          token_count: non_neg_integer()
        }

  @chars_per_token 4

  @doc """
  Chunks `content` into overlapping text segments.

  - `chunk_size` — target token count per chunk (default 800)
  - `overlap` — token overlap between consecutive chunks (default 100)
  """
  @spec chunk_text(String.t(), pos_integer(), non_neg_integer()) :: [chunk_result()]
  def chunk_text(content, chunk_size \\ 800, overlap \\ 100)

  def chunk_text("", _chunk_size, _overlap), do: []

  def chunk_text(content, chunk_size, overlap) when is_binary(content) do
    char_limit = chunk_size * @chars_per_token
    overlap_chars = overlap * @chars_per_token

    content
    |> split_paragraphs()
    |> build_chunks(char_limit, overlap_chars)
    |> Enum.with_index()
    |> Enum.map(fn {text, idx} ->
      trimmed = String.trim(text)
      %{content: trimmed, chunk_index: idx, token_count: token_count(trimmed)}
    end)
    |> Enum.reject(fn %{content: c} -> c == "" end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec split_paragraphs(String.t()) :: [String.t()]
  defp split_paragraphs(content) do
    content
    |> String.split(~r/\n{2,}/)
    |> Enum.reject(&(String.trim(&1) == ""))
  end

  @spec build_chunks([String.t()], pos_integer(), non_neg_integer()) :: [String.t()]
  defp build_chunks(paragraphs, char_limit, overlap_chars) do
    paragraphs
    |> Enum.flat_map(&maybe_split_long_paragraph(&1, char_limit))
    |> accumulate_chunks(char_limit, overlap_chars, [], "")
  end

  # A paragraph longer than char_limit is split on whitespace boundaries.
  @spec maybe_split_long_paragraph(String.t(), pos_integer()) :: [String.t()]
  defp maybe_split_long_paragraph(paragraph, char_limit) do
    if String.length(paragraph) <= char_limit do
      [paragraph]
    else
      paragraph
      |> String.split(~r/\s+/)
      |> Enum.reject(&(&1 == ""))
      |> Enum.reduce({[], ""}, fn word, {chunks, current} ->
        candidate = if current == "", do: word, else: current <> " " <> word

        if String.length(candidate) > char_limit do
          {[current | chunks], word}
        else
          {chunks, candidate}
        end
      end)
      |> then(fn {chunks, last} ->
        all = if last != "", do: [last | chunks], else: chunks
        Enum.reverse(all)
      end)
    end
  end

  @spec accumulate_chunks(
          [String.t()],
          pos_integer(),
          non_neg_integer(),
          [String.t()],
          String.t()
        ) ::
          [String.t()]
  defp accumulate_chunks([], _limit, _overlap, acc, current) do
    final_chunks = if current != "", do: [current | acc], else: acc
    Enum.reverse(final_chunks)
  end

  defp accumulate_chunks([para | rest], limit, overlap_chars, acc, current) do
    separator = if current == "", do: "", else: "\n\n"
    candidate = current <> separator <> para

    if String.length(candidate) > limit and current != "" do
      # Current chunk is full — close it and start next with overlap
      overlap_text = build_overlap(current, overlap_chars)
      new_current = if overlap_text == "", do: para, else: overlap_text <> "\n\n" <> para
      accumulate_chunks(rest, limit, overlap_chars, [current | acc], new_current)
    else
      accumulate_chunks(rest, limit, overlap_chars, acc, candidate)
    end
  end

  # Extract the last `overlap_chars` characters from a chunk as the carry-forward.
  @spec build_overlap(String.t(), non_neg_integer()) :: String.t()
  defp build_overlap(_text, 0), do: ""

  defp build_overlap(text, overlap_chars) do
    len = String.length(text)

    if len <= overlap_chars do
      text
    else
      String.slice(text, (len - overlap_chars)..-1//1)
    end
  end

  @spec token_count(String.t()) :: non_neg_integer()
  defp token_count(""), do: 0
  defp token_count(text), do: max(1, div(String.length(text), @chars_per_token))
end
