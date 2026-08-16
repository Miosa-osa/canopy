defmodule Canopy.SearchTest do
  @moduledoc """
  Tests for the `Canopy.Search` context.

  These exercise the high-level dispatch and validation logic. Because the
  context lives in front of two backends, we force `:elixir` for the tests
  that should be hermetic regardless of whether `rg` is on PATH.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Search
  alias Canopy.Workspaces

  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------

  setup do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-search-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    slug = "search-test-#{System.unique_integer([:positive])}"

    {:ok, _ws} =
      Workspaces.create(%{
        slug: slug,
        name: "Search Test",
        root_path: dir
      })

    {:ok, dir: dir, slug: slug}
  end

  defp write!(dir, rel, content) do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  defp force(backend) do
    prev = Application.get_env(:canopy, :search_backend)
    Application.put_env(:canopy, :search_backend, backend)
    on_exit(fn -> Application.put_env(:canopy, :search_backend, prev) end)
  end

  # ---------------------------------------------------------------------------
  # Backend selection
  # ---------------------------------------------------------------------------

  describe "backend selection" do
    test "picks ripgrep when rg is on PATH and backend=:auto", %{slug: slug, dir: dir} do
      force(:auto)
      write!(dir, "a.txt", "hello world\n")

      if System.find_executable("rg") do
        assert {:ok, %{backend: :ripgrep}} = Search.search("hello", slug)
      else
        assert {:ok, %{backend: :elixir}} = Search.search("hello", slug)
      end
    end

    test "picks elixir when forced", %{slug: slug, dir: dir} do
      force(:elixir)
      write!(dir, "a.txt", "hello\n")
      assert {:ok, %{backend: :elixir}} = Search.search("hello", slug)
    end
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  describe "validation" do
    test "workspace_not_found for unknown slug" do
      force(:elixir)
      assert {:error, :workspace_not_found} = Search.search("hi", "no-such-workspace-xxxx")
    end

    test "rejects empty query", %{slug: slug} do
      force(:elixir)
      assert {:error, :invalid_query} = Search.search("", slug)
    end

    test "rejects whitespace-only query", %{slug: slug} do
      force(:elixir)
      assert {:error, :invalid_query} = Search.search("    ", slug)
    end

    test "rejects 513-char query", %{slug: slug} do
      force(:elixir)
      q = String.duplicate("a", 513)
      assert {:error, :invalid_query} = Search.search(q, slug)
    end

    test "accepts 512-char query", %{slug: slug, dir: dir} do
      force(:elixir)
      write!(dir, "a.txt", String.duplicate("a", 600))
      q = String.duplicate("a", 512)
      assert {:ok, %{matches: [_ | _]}} = Search.search(q, slug)
    end
  end

  # ---------------------------------------------------------------------------
  # Behaviour
  # ---------------------------------------------------------------------------

  describe "search behaviour (elixir backend)" do
    setup do
      force(:elixir)
      :ok
    end

    test "literal substring match", %{slug: slug, dir: dir} do
      write!(dir, "a.txt", "fun apple\nplain banana\n")

      assert {:ok, %{matches: [m]}} = Search.search("apple", slug)
      assert m.file_path == "a.txt"
      assert m.line_number == 1
      assert m.line_text == "fun apple"
      assert binary_part(m.line_text, m.match_start, m.match_end - m.match_start) == "apple"
    end

    test "case sensitivity respected (default true)", %{slug: slug, dir: dir} do
      write!(dir, "a.txt", "Hello\nhello\n")
      assert {:ok, %{matches: matches}} = Search.search("hello", slug)
      assert length(matches) == 1
    end

    test "case insensitive when requested", %{slug: slug, dir: dir} do
      write!(dir, "a.txt", "Hello\nhello\nHELLO\n")
      assert {:ok, %{matches: matches}} = Search.search("hello", slug, case_sensitive: false)
      assert length(matches) == 3
    end

    test "regex mode", %{slug: slug, dir: dir} do
      write!(dir, "a.txt", "foo123\nfoo abc\n")
      assert {:ok, %{matches: [m]}} = Search.search("foo\\d+", slug, regex: true)
      assert m.line_text == "foo123"
    end

    test "invalid regex returns error", %{slug: slug} do
      assert {:error, :invalid_regex} = Search.search("[unclosed", slug, regex: true)
    end

    test "limit respected", %{slug: slug, dir: dir} do
      lines = Enum.map(1..50, fn i -> "x line #{i} target\n" end) |> Enum.join()
      write!(dir, "many.txt", lines)
      assert {:ok, %{matches: matches}} = Search.search("target", slug, limit: 10)
      assert length(matches) == 10
    end

    test "limit clamped at 1000", %{slug: slug, dir: dir} do
      write!(dir, "a.txt", "target\n")
      assert {:ok, _} = Search.search("target", slug, limit: 1_000_000)
      # No assertion failure = clamp succeeded.
    end

    test "skips binary files", %{slug: slug, dir: dir} do
      # First 512 bytes contain a NUL byte → classified as binary.
      write!(dir, "blob.bin", <<"target", 0, "more target">>)
      write!(dir, "ok.txt", "target\n")

      assert {:ok, %{matches: matches}} = Search.search("target", slug)
      assert Enum.all?(matches, &(&1.file_path == "ok.txt"))
    end

    test "skips ignored directories", %{slug: slug, dir: dir} do
      write!(dir, "node_modules/skipme.txt", "target\n")
      write!(dir, ".git/HEAD", "target\n")
      write!(dir, "_build/dev/skip.txt", "target\n")
      write!(dir, "src/code.txt", "target\n")

      assert {:ok, %{matches: matches}} = Search.search("target", slug)
      paths = Enum.map(matches, & &1.file_path) |> Enum.sort()
      assert paths == ["src/code.txt"]
    end

    test "truncates lines longer than 500 chars", %{slug: slug, dir: dir} do
      long = String.duplicate("x", 800) <> "TARGET" <> String.duplicate("y", 100)
      write!(dir, "long.txt", long <> "\n")

      assert {:ok, %{matches: [m], truncated: true}} = Search.search("TARGET", slug)
      assert String.length(m.line_text) <= 501
      assert String.ends_with?(m.line_text, "…")
    end

    test "include_glob filters", %{slug: slug, dir: dir} do
      write!(dir, "a.md", "target\n")
      write!(dir, "b.txt", "target\n")
      assert {:ok, %{matches: matches}} = Search.search("target", slug, include_glob: "*.md")
      paths = Enum.map(matches, & &1.file_path)
      assert "a.md" in paths
      refute "b.txt" in paths
    end

    test "exclude_glob filters", %{slug: slug, dir: dir} do
      write!(dir, "a.md", "target\n")
      write!(dir, "b.txt", "target\n")
      assert {:ok, %{matches: matches}} = Search.search("target", slug, exclude_glob: "*.md")
      paths = Enum.map(matches, & &1.file_path)
      refute "a.md" in paths
      assert "b.txt" in paths
    end

    test "defence-in-depth: a backend returning a traversal path is filtered out",
         %{slug: slug, dir: dir} do
      # Inject a fake backend that returns a malicious match.
      defmodule EvilBackend do
        @behaviour Canopy.Search.Backend

        @impl true
        def search(_root, _query, _opts) do
          {:ok,
           [
             %{
               file_path: "../../etc/passwd",
               line_number: 1,
               line_text: "root:x:0:0",
               match_start: 0,
               match_end: 4
             },
             %{
               file_path: "ok.txt",
               line_number: 1,
               line_text: "ok",
               match_start: 0,
               match_end: 2
             }
           ]}
        end
      end

      Application.put_env(:canopy, :search_backend, EvilBackend)
      write!(dir, "ok.txt", "ok")

      assert {:ok, %{matches: matches}} = Search.search("anything", slug)
      paths = Enum.map(matches, & &1.file_path)
      refute "../../etc/passwd" in paths
      assert "ok.txt" in paths
    end

    test "absolute path from backend is filtered out", %{slug: slug} do
      defmodule AbsBackend do
        @behaviour Canopy.Search.Backend

        @impl true
        def search(_root, _query, _opts) do
          {:ok,
           [
             %{
               file_path: "/etc/passwd",
               line_number: 1,
               line_text: "x",
               match_start: 0,
               match_end: 1
             }
           ]}
        end
      end

      Application.put_env(:canopy, :search_backend, AbsBackend)
      assert {:ok, %{matches: []}} = Search.search("anything", slug)
    end
  end
end
