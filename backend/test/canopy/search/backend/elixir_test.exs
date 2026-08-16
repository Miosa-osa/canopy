defmodule Canopy.Search.Backend.ElixirTest do
  @moduledoc """
  Tests for the pure-Elixir search backend.

  No external dependencies — runs everywhere.
  """

  use ExUnit.Case, async: true

  alias Canopy.Search.Backend.Elixir, as: ElixirBackend

  defp tmpdir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-elixir-search-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp write!(dir, rel, content) do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  describe "search/3 — literal" do
    test "finds a single substring match" do
      dir = tmpdir()
      write!(dir, "a.txt", "alpha beta gamma\n")
      assert {:ok, [m]} = ElixirBackend.search(dir, "beta", limit: 100)
      assert m.file_path == "a.txt"
      assert m.line_number == 1
      assert m.line_text == "alpha beta gamma"
      assert m.match_start == 6
      assert m.match_end == 10
    end

    test "finds multiple matches per line" do
      dir = tmpdir()
      write!(dir, "a.txt", "ab ab ab\n")
      assert {:ok, matches} = ElixirBackend.search(dir, "ab", limit: 100)
      assert length(matches) == 3
      offsets = Enum.map(matches, & &1.match_start)
      assert offsets == [0, 3, 6]
    end

    test "finds matches across multiple lines" do
      dir = tmpdir()
      write!(dir, "a.txt", "first line\nsecond match\nthird line\n")
      assert {:ok, [m]} = ElixirBackend.search(dir, "match", limit: 100)
      assert m.line_number == 2
    end

    test "respects case sensitivity by default" do
      dir = tmpdir()
      write!(dir, "a.txt", "Hello\nhello\n")
      assert {:ok, matches} = ElixirBackend.search(dir, "hello", limit: 100)
      assert length(matches) == 1
    end

    test "case insensitive when requested" do
      dir = tmpdir()
      write!(dir, "a.txt", "Hello\nhello\nHELLO\n")

      assert {:ok, matches} =
               ElixirBackend.search(dir, "hello",
                 limit: 100,
                 case_sensitive: false
               )

      assert length(matches) == 3
    end

    test "respects limit" do
      dir = tmpdir()
      lines = Enum.map_join(1..50, "", fn _ -> "target\n" end)
      write!(dir, "a.txt", lines)

      assert {:ok, matches} = ElixirBackend.search(dir, "target", limit: 7)
      assert length(matches) == 7
    end
  end

  describe "search/3 — regex" do
    test "matches a regex pattern" do
      dir = tmpdir()
      write!(dir, "a.txt", "abc 123\ndef 456\n")

      assert {:ok, matches} =
               ElixirBackend.search(dir, "\\d+", limit: 100, regex: true)

      assert length(matches) == 2
    end

    test "invalid regex returns :invalid_regex" do
      dir = tmpdir()
      assert {:error, :invalid_regex} = ElixirBackend.search(dir, "[unclosed", regex: true)
    end

    test "case-insensitive regex" do
      dir = tmpdir()
      write!(dir, "a.txt", "FOO\nfoo\n")

      assert {:ok, matches} =
               ElixirBackend.search(dir, "foo",
                 limit: 100,
                 regex: true,
                 case_sensitive: false
               )

      assert length(matches) == 2
    end
  end

  describe "filtering" do
    test "skips binary files via NUL-byte sniff" do
      dir = tmpdir()
      write!(dir, "blob.bin", <<"target", 0, "more target">>)
      write!(dir, "ok.txt", "target\n")
      assert {:ok, matches} = ElixirBackend.search(dir, "target", limit: 100)
      assert Enum.all?(matches, &(&1.file_path == "ok.txt"))
    end

    test "skips empty files" do
      dir = tmpdir()
      write!(dir, "empty.txt", "")
      write!(dir, "full.txt", "target\n")
      assert {:ok, matches} = ElixirBackend.search(dir, "target", limit: 100)
      assert Enum.map(matches, & &1.file_path) == ["full.txt"]
    end

    test "skips ignored directories" do
      dir = tmpdir()
      write!(dir, "node_modules/x.txt", "target\n")
      write!(dir, "_build/x.txt", "target\n")
      write!(dir, ".git/HEAD", "target\n")
      write!(dir, ".next/x.txt", "target\n")
      write!(dir, "dist/x.txt", "target\n")
      write!(dir, "target/x.txt", "target\n")
      write!(dir, "src/x.txt", "target\n")

      assert {:ok, matches} = ElixirBackend.search(dir, "target", limit: 100)
      paths = Enum.map(matches, & &1.file_path) |> Enum.sort()
      assert paths == ["src/x.txt"]
    end

    test "include_glob filters by pattern" do
      dir = tmpdir()
      write!(dir, "a.md", "target\n")
      write!(dir, "b.txt", "target\n")

      assert {:ok, matches} =
               ElixirBackend.search(dir, "target", limit: 100, include_glob: "*.md")

      assert Enum.map(matches, & &1.file_path) == ["a.md"]
    end

    test "exclude_glob filters by pattern" do
      dir = tmpdir()
      write!(dir, "a.md", "target\n")
      write!(dir, "b.txt", "target\n")

      assert {:ok, matches} =
               ElixirBackend.search(dir, "target", limit: 100, exclude_glob: "*.md")

      assert Enum.map(matches, & &1.file_path) == ["b.txt"]
    end

    test "no matches returns empty list" do
      dir = tmpdir()
      write!(dir, "a.txt", "alpha\n")
      assert {:ok, []} = ElixirBackend.search(dir, "zzz", limit: 100)
    end
  end

  describe "subdirectories" do
    test "walks nested directories" do
      dir = tmpdir()
      write!(dir, "a/b/c/deep.txt", "target\n")
      assert {:ok, [m]} = ElixirBackend.search(dir, "target", limit: 100)
      assert m.file_path == "a/b/c/deep.txt"
    end
  end
end
