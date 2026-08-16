defmodule CanopyWeb.SkillCuratorControllerTest do
  @moduledoc """
  Tests for /api/v1/skill-curator/* endpoints.

  Focus: input validation (slug, version, hash), error responses, and
  end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Skills
  alias Canopy.Skills.Curator

  defp seed_skill(slug) do
    {:ok, skill} =
      Skills.create(%{
        "slug" => slug,
        "name" => slug,
        "content" => "# #{slug}\n",
        "source" => "local",
        "provider_format" => "generic"
      })

    skill
  end

  # ---------------------------------------------------------------------------
  # Lockfile
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skill-curator/lockfile" do
    test "returns empty data when no entries", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/skill-curator/lockfile")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by workspace_slug", %{conn: conn} do
      _ = seed_skill("ws-filter")
      Curator.lock_skill("ws-a", "ws-filter", %{locked_version: "1", content_hash: "a"})
      Curator.lock_skill("ws-b", "ws-filter", %{locked_version: "1", content_hash: "b"})

      conn = get(conn, ~p"/api/v1/skill-curator/lockfile?workspace_slug=ws-a")
      assert %{"data" => entries} = json_response(conn, 200)
      assert length(entries) == 1
      assert hd(entries)["workspace_slug"] == "ws-a"
    end

    test "rejects invalid workspace_slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/skill-curator/lockfile?workspace_slug=BAD!!")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/skill-curator/lockfile" do
    test "creates a lockfile entry", %{conn: conn} do
      _ = seed_skill("lock-create")

      body = %{
        workspace_slug: "default",
        skill_slug: "lock-create",
        locked_version: "1.0.0",
        content_hash: "abc123"
      }

      conn = post(conn, ~p"/api/v1/skill-curator/lockfile", body)
      assert %{"locked_version" => "1.0.0"} = json_response(conn, 201)
    end

    test "rejects invalid version", %{conn: conn} do
      _ = seed_skill("bad-ver")

      body = %{
        skill_slug: "bad-ver",
        locked_version: "",
        content_hash: "abc"
      }

      conn = post(conn, ~p"/api/v1/skill-curator/lockfile", body)
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid content_hash", %{conn: conn} do
      _ = seed_skill("bad-hash")

      body = %{
        skill_slug: "bad-hash",
        locked_version: "1.0.0",
        content_hash: "NOT-HEX!"
      }

      conn = post(conn, ~p"/api/v1/skill-curator/lockfile", body)
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid skill_slug", %{conn: conn} do
      body = %{
        skill_slug: "BAD SLUG",
        locked_version: "1.0.0",
        content_hash: "abc"
      }

      conn = post(conn, ~p"/api/v1/skill-curator/lockfile", body)
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/skill-curator/lockfile/:workspace_slug/:skill_slug" do
    test "removes an existing entry", %{conn: conn} do
      _ = seed_skill("delete-me")

      Curator.lock_skill("default", "delete-me", %{
        locked_version: "1.0.0",
        content_hash: "h"
      })

      conn = delete(conn, ~p"/api/v1/skill-curator/lockfile/default/delete-me")
      assert json_response(conn, 200)
    end

    test "returns 404 when entry not found", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/skill-curator/lockfile/default/ghost")
      assert %{"error" => "lockfile_entry_not_found"} = json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Versions
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skill-curator/skills/:slug/versions" do
    test "returns version history newest first", %{conn: conn} do
      skill = seed_skill("ver-test")

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "ver-test",
        version: "1.0.0",
        content_hash: "a"
      })

      Process.sleep(10)

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "ver-test",
        version: "1.1.0",
        content_hash: "b"
      })

      conn = get(conn, ~p"/api/v1/skill-curator/skills/ver-test/versions")
      assert %{"data" => versions} = json_response(conn, 200)
      assert length(versions) == 2
      assert hd(versions)["version"] == "1.1.0"
    end

    test "returns empty list when none recorded", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/skill-curator/skills/ghost/versions")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/skill-curator/skills/:slug/diff" do
    test "diffs two versions", %{conn: conn} do
      skill = seed_skill("diff-test")

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "diff-test",
        version: "1.0.0",
        content_hash: "aaa"
      })

      Curator.record_version(%{
        skill_id: skill.id,
        skill_slug: "diff-test",
        version: "2.0.0",
        content_hash: "bbb"
      })

      conn = get(conn, ~p"/api/v1/skill-curator/skills/diff-test/diff?from=1.0.0&to=2.0.0")

      assert %{"hash_changed" => true} = json_response(conn, 200)
    end

    test "returns 404 when version not found", %{conn: conn} do
      _ = seed_skill("diff-missing")

      conn = get(conn, ~p"/api/v1/skill-curator/skills/diff-missing/diff?from=1&to=2")

      assert %{"error" => "version_not_found"} = json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Verification
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/skill-curator/skills/:slug/verify" do
    test "marks skill as verified", %{conn: conn} do
      _ = seed_skill("verify-via-api")

      conn =
        post(conn, ~p"/api/v1/skill-curator/skills/verify-via-api/verify", %{
          verified_by: "rhl"
        })

      assert %{"verified" => true, "verified_by" => "rhl"} = json_response(conn, 200)
    end

    test "rejects missing verified_by", %{conn: conn} do
      _ = seed_skill("missing-by")

      conn = post(conn, ~p"/api/v1/skill-curator/skills/missing-by/verify", %{})
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns 404 for unknown skill", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/skill-curator/skills/ghost/verify", %{
          verified_by: "rhl"
        })

      assert %{"error" => "skill_not_found"} = json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/skill-curator/skills/:slug/verify" do
    test "clears verification", %{conn: conn} do
      _ = seed_skill("clear-it")
      Curator.verify_skill("clear-it", "rhl")

      conn = delete(conn, ~p"/api/v1/skill-curator/skills/clear-it/verify")
      assert %{"verified" => false} = json_response(conn, 200)
    end

    test "returns 404 for unknown skill", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/skill-curator/skills/ghost/verify")
      assert %{"error" => "skill_not_found"} = json_response(conn, 404)
    end
  end

  describe "GET /api/v1/skill-curator/unverified" do
    test "lists unverified skill slugs", %{conn: conn} do
      _ = seed_skill("not-yet")
      _ = seed_skill("also-not")
      _ = seed_skill("done-already")
      Curator.verify_skill("done-already", "rhl")

      conn = get(conn, ~p"/api/v1/skill-curator/unverified")
      assert %{"data" => slugs, "count" => count} = json_response(conn, 200)
      assert count == length(slugs)
      assert "not-yet" in slugs
      assert "also-not" in slugs
      refute "done-already" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # Sources
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/skill-curator/sources" do
    test "returns the configured sources list", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/skill-curator/sources")
      assert %{"sources" => sources} = json_response(conn, 200)
      assert is_list(sources)
    end
  end

  describe "POST /api/v1/skill-curator/sources" do
    test "adds a new source", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/skill-curator/sources", %{
          name: "test-source-#{System.unique_integer([:positive])}",
          url: "https://example.com/registry"
        })

      assert %{"name" => name} = json_response(conn, 201)
      assert is_binary(name)
    end

    test "rejects missing url", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/skill-curator/sources", %{
          name: "no-url"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid url scheme", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/skill-curator/sources", %{
          name: "ftp-source",
          url: "ftp://example.com/registry"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/skill-curator/sources/refresh" do
    test "returns refresh result", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/skill-curator/sources/refresh", %{})
      assert %{"refreshed" => _, "errors" => _} = json_response(conn, 200)
    end
  end
end
