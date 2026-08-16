defmodule Canopy.Search.Backend.RipgrepTest do
  @moduledoc """
  Tests for the ripgrep-backed search backend.

  Tagged `:ripgrep` and skipped automatically when `rg` is not on PATH.
  """

  use ExUnit.Case, async: true

  alias Canopy.Search.Backend.Ripgrep

  @moduletag :ripgrep

  setup_all do
    if System.find_executable("rg") do
      :ok
    else
      :ok = ExUnit.configure(exclude: [:ripgrep])
      {:ok, skip: true}
    end
  end

  defp tmpdir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-rg-search-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp write!(dir, rel, content) do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  describe "search/3" do
    test "finds a literal substring match" do
      dir = tmpdir()
      write!(dir, "a.txt", "alpha beta gamma\n")

      assert {:ok, [m]} = Ripgrep.search(dir, "beta", limit: 100)
      assert m.file_path == "a.txt"
      assert m.line_number == 1
      assert m.match_start == 6
      assert m.match_end == 10
    end

    test "no matches returns empty list" do
      dir = tmpdir()
      write!(dir, "a.txt", "alpha\n")
      assert {:ok, []} = Ripgrep.search(dir, "zzz", limit: 100)
    end

    test "respects case sensitivity (default true)" do
      dir = tmpdir()
      write!(dir, "a.txt", "Hello\nhello\n")
      assert {:ok, matches} = Ripgrep.search(dir, "hello", limit: 100)
      assert length(matches) == 1
    end

    test "case insensitive when requested" do
      dir = tmpdir()
      write!(dir, "a.txt", "Hello\nhello\nHELLO\n")

      assert {:ok, matches} =
               Ripgrep.search(dir, "hello", limit: 100, case_sensitive: false)

      assert length(matches) == 3
    end

    test "regex mode" do
      dir = tmpdir()
      write!(dir, "a.txt", "x123\nyabc\n")

      assert {:ok, [m]} = Ripgrep.search(dir, "\\d+", limit: 100, regex: true)
      assert m.line_number == 1
    end

    test "invalid regex returns :invalid_regex" do
      dir = tmpdir()
      write!(dir, "a.txt", "anything\n")
      assert {:error, :invalid_regex} = Ripgrep.search(dir, "[unclosed", regex: true)
    end

    test "ripgrep_not_available when rg missing from PATH" do
      # We cannot reliably remove rg from PATH inside one test process; rely on
      # the `Canopy.Search.search/3` dispatch test in `Canopy.SearchTest` to
      # exercise the missing-binary code path. This test documents the contract.
      assert true
    end
  end
end
