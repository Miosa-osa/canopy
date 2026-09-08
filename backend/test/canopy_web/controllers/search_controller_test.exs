defmodule CanopyWeb.SearchControllerTest do
  @moduledoc """
  Tests for `GET /api/v1/search`.

  These tests assume the route has been wired in `router.ex` per
  `wiring/search-wiring.md`. Path strings are written verbatim (not via
  `~p`) so the test file compiles cleanly even before that wiring lands.
  """

  use CanopyWeb.ConnCase, async: false

  alias Canopy.Workspaces

  setup do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-search-ctrl-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    slug = "search-ctrl-#{System.unique_integer([:positive])}"

    {:ok, _ws} =
      Workspaces.create(%{
        slug: slug,
        name: "Search Controller Test",
        root_path: dir
      })

    # Force the deterministic backend so tests don't depend on rg.
    prev = Application.get_env(:canopy, :search_backend)
    Application.put_env(:canopy, :search_backend, :elixir)
    on_exit(fn -> Application.put_env(:canopy, :search_backend, prev) end)

    {:ok, dir: dir, slug: slug}
  end

  defp write!(dir, rel, content) do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  defp do_get(conn, query_params) do
    qs = URI.encode_query(query_params)
    get(conn, "/api/v1/search?#{qs}")
  end

  describe "validation" do
    test "missing q returns 400", %{conn: conn, slug: slug} do
      conn = do_get(conn, %{"workspace_slug" => slug})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "empty q returns 400", %{conn: conn, slug: slug} do
      conn = do_get(conn, %{"q" => "", "workspace_slug" => slug})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "missing workspace_slug returns 400", %{conn: conn} do
      conn = do_get(conn, %{"q" => "hello"})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "invalid workspace_slug format returns 400", %{conn: conn} do
      conn = do_get(conn, %{"q" => "hello", "workspace_slug" => "INVALID slug"})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "q exceeding 512 chars returns 400", %{conn: conn, slug: slug} do
      long = String.duplicate("a", 513)
      conn = do_get(conn, %{"q" => long, "workspace_slug" => slug})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "unknown workspace returns 404", %{conn: conn} do
      conn = do_get(conn, %{"q" => "hi", "workspace_slug" => "no-such-workspace"})
      assert %{"error" => "workspace_not_found"} = json_response(conn, 404)
    end

    test "invalid regex returns 400", %{conn: conn, slug: slug} do
      conn = do_get(conn, %{"q" => "[unclosed", "workspace_slug" => slug, "regex" => "true"})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "happy path" do
    test "returns matches with backend + elapsed_ms + truncated", %{
      conn: conn,
      slug: slug,
      dir: dir
    } do
      write!(dir, "a.txt", "alpha beta\n")

      conn = do_get(conn, %{"q" => "beta", "workspace_slug" => slug})
      body = json_response(conn, 200)

      assert %{
               "data" => [match],
               "backend" => "elixir",
               "elapsed_ms" => elapsed,
               "truncated" => false
             } = body

      assert is_integer(elapsed) and elapsed >= 0
      assert match["file_path"] == "a.txt"
      assert match["line_number"] == 1
      assert match["line_text"] == "alpha beta"
      assert match["match_start"] == 6
      assert match["match_end"] == 10
    end

    test "case_sensitive=false returns case-insensitive matches", %{
      conn: conn,
      slug: slug,
      dir: dir
    } do
      write!(dir, "a.txt", "Hello\nhello\nHELLO\n")

      conn =
        do_get(conn, %{
          "q" => "hello",
          "workspace_slug" => slug,
          "case_sensitive" => "false"
        })

      assert %{"data" => matches} = json_response(conn, 200)
      assert length(matches) == 3
    end

    test "regex=true enables regex matching", %{conn: conn, slug: slug, dir: dir} do
      write!(dir, "a.txt", "x123\nyabc\n")

      conn =
        do_get(conn, %{
          "q" => "\\d+",
          "workspace_slug" => slug,
          "include_glob" => "a.txt",
          "regex" => "true"
        })

      assert %{"data" => [match]} = json_response(conn, 200)
      assert match["line_text"] == "x123"
    end

    test "limit caps results", %{conn: conn, slug: slug, dir: dir} do
      lines = Enum.map_join(1..50, "", fn _ -> "target\n" end)
      write!(dir, "a.txt", lines)

      conn =
        do_get(conn, %{
          "q" => "target",
          "workspace_slug" => slug,
          "limit" => "5"
        })

      assert %{"data" => matches} = json_response(conn, 200)
      assert length(matches) == 5
    end

    test "limit=999999 is clamped to 1000", %{conn: conn, slug: slug, dir: dir} do
      write!(dir, "a.txt", "target\n")

      conn =
        do_get(conn, %{
          "q" => "target",
          "workspace_slug" => slug,
          "limit" => "999999"
        })

      assert %{"data" => matches} = json_response(conn, 200)
      assert length(matches) <= 1000
    end

    test "no matches returns empty data", %{conn: conn, slug: slug, dir: dir} do
      write!(dir, "a.txt", "nothing useful\n")

      conn = do_get(conn, %{"q" => "zzzNoMatch", "workspace_slug" => slug})

      assert %{"data" => [], "backend" => "elixir", "truncated" => false} =
               json_response(conn, 200)
    end
  end
end
