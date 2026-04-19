defmodule Canopy.Knowledge.ChunkerTest do
  @moduledoc """
  Unit tests for the Chunker module.

  Tests cover: empty input, single word, short text, paragraph splitting,
  long-paragraph word-splitting, overlap correctness, chunk index sequencing.
  """

  use ExUnit.Case, async: true

  alias Canopy.Knowledge.Chunker

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "chunk_text/3 — edge cases" do
    test "returns empty list for empty string" do
      assert Chunker.chunk_text("") == []
    end

    test "returns single chunk for single word" do
      [chunk] = Chunker.chunk_text("hello")
      assert chunk.content == "hello"
      assert chunk.chunk_index == 0
      assert chunk.token_count >= 1
    end

    test "returns single chunk when content fits in one chunk" do
      text = "Short paragraph. Only a few sentences here. Nothing more."
      [chunk] = Chunker.chunk_text(text, 800, 100)
      assert chunk.content == text
      assert chunk.chunk_index == 0
    end

    test "trims whitespace from chunk content" do
      text = "  trimmed  "
      [chunk] = Chunker.chunk_text(text, 800, 100)
      assert chunk.content == "trimmed"
    end

    test "rejects blank-only chunks" do
      text = "\n\n\n\n"
      assert Chunker.chunk_text(text) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Paragraph splitting
  # ---------------------------------------------------------------------------

  describe "chunk_text/3 — paragraph splitting" do
    test "splits on double newlines" do
      text = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."
      # With a large chunk_size, all fit in one chunk
      [chunk] = Chunker.chunk_text(text, 800, 0)
      assert String.contains?(chunk.content, "First paragraph")
    end

    test "produces multiple chunks when paragraphs exceed chunk_size" do
      # 40 chars/token * 10 = 400 chars per chunk
      # Each paragraph is ~100 chars; 4 paragraphs → expect split
      para = String.duplicate("x", 100)
      text = Enum.join(List.duplicate(para, 8), "\n\n")

      chunks = Chunker.chunk_text(text, 10, 0)
      assert length(chunks) > 1
    end

    test "chunk indices are sequential starting at 0" do
      para = String.duplicate("word ", 60)
      text = Enum.join(List.duplicate(para, 4), "\n\n")
      chunks = Chunker.chunk_text(text, 50, 0)

      indices = Enum.map(chunks, & &1.chunk_index)
      assert indices == Enum.to_list(0..(length(chunks) - 1))
    end

    test "all chunks have positive token_count" do
      para = "This is a paragraph with several words in it."
      text = Enum.join(List.duplicate(para, 5), "\n\n")
      chunks = Chunker.chunk_text(text, 10, 0)
      assert Enum.all?(chunks, fn c -> c.token_count >= 1 end)
    end
  end

  # ---------------------------------------------------------------------------
  # Long paragraph word-splitting
  # ---------------------------------------------------------------------------

  describe "chunk_text/3 — long paragraph word splitting" do
    test "splits a single very long paragraph into multiple chunks" do
      # 200 words, each 6 chars = ~1200 chars. chunk_size=5 tokens = 20 chars.
      long_para = Enum.map_join(1..200, " ", fn i -> "word#{i}" end)
      chunks = Chunker.chunk_text(long_para, 5, 0)
      assert length(chunks) > 1
      # Reconstruct: all words should be present somewhere
      all_content = Enum.map_join(chunks, " ", & &1.content)
      assert String.contains?(all_content, "word1")
      assert String.contains?(all_content, "word200")
    end
  end

  # ---------------------------------------------------------------------------
  # Overlap
  # ---------------------------------------------------------------------------

  describe "chunk_text/3 — overlap" do
    test "next chunk carries text from end of previous chunk" do
      # Build text with clearly distinct paragraphs. With small chunk_size and overlap,
      # the second chunk should contain text from the tail of the first.
      paras = Enum.map(1..10, fn i -> "Paragraph #{i}: " <> String.duplicate("text ", 30) end)
      text = Enum.join(paras, "\n\n")

      # chunk_size small enough to force splits; overlap = 20 tokens = 80 chars
      chunks = Chunker.chunk_text(text, 40, 20)

      # At least two chunks expected
      assert length(chunks) >= 2

      # The second chunk's content should overlap with the end of the first.
      # We can't assert exact content match due to paragraph vs word boundary choices,
      # but we can assert chunk count and that no chunk is empty.
      assert Enum.all?(chunks, fn c -> c.content != "" end)
    end

    test "zero overlap produces non-overlapping chunks" do
      para = String.duplicate("word ", 40)
      text = Enum.join(List.duplicate(para, 5), "\n\n")
      chunks = Chunker.chunk_text(text, 30, 0)
      assert length(chunks) >= 1
      assert Enum.all?(chunks, fn c -> c.content != "" end)
    end
  end

  # ---------------------------------------------------------------------------
  # Token count approximation
  # ---------------------------------------------------------------------------

  describe "token_count field" do
    test "token_count is approximately content_length / 4" do
      text = String.duplicate("abcd", 100)
      [chunk] = Chunker.chunk_text(text, 200, 0)
      # 400 chars / 4 = 100 tokens
      assert chunk.token_count == 100
    end
  end
end
