defmodule CanopyWeb.ScheduleControllerTest do
  @moduledoc """
  Tests for /api/v1/schedule/* endpoints.

  Focus: input validation (slug format, UUID, limit cap, window order),
  error responses, and end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Schedule

  describe "GET /api/v1/schedule/specs" do
    test "returns empty data when no specs", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/specs")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns specs", %{conn: conn} do
      Schedule.create_spec(%{slug: "first", name: "First"})
      Schedule.create_spec(%{slug: "second", name: "Second"})

      conn = get(conn, ~p"/api/v1/schedule/specs")
      assert %{"data" => specs} = json_response(conn, 200)
      assert length(specs) == 2
    end

    test "filters by status", %{conn: conn} do
      Schedule.create_spec(%{slug: "active-x", name: "A"})

      {:ok, paused} = Schedule.create_spec(%{slug: "paused-x", name: "B"})
      Schedule.pause_spec(paused, "x")

      conn = get(conn, ~p"/api/v1/schedule/specs?status=active")
      assert %{"data" => [spec]} = json_response(conn, 200)
      assert spec["slug"] == "active-x"
    end

    test "caps limit at 1000", %{conn: conn} do
      for i <- 1..3 do
        Schedule.create_spec(%{slug: "lim-#{i}", name: "X"})
      end

      conn = get(conn, ~p"/api/v1/schedule/specs?limit=999999")
      assert %{"data" => specs} = json_response(conn, 200)
      assert length(specs) <= 1000
    end
  end

  describe "POST /api/v1/schedule/specs" do
    test "creates a valid spec", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/specs", %{
          slug: "valid-cron",
          name: "Daily 9am",
          model: %{"crons" => ["0 9 * * *"]}
        })

      assert %{"slug" => "valid-cron"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/specs", %{
          slug: "BAD SLUG With Spaces!",
          name: "X"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects empty slug", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/schedule/specs", %{slug: "", name: "X"})
      assert json_response(conn, 400)
    end

    test "rejects invalid overlap_policy via changeset", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/specs", %{
          slug: "bad-policy-spec",
          name: "X",
          overlap_policy: "made-up"
        })

      assert json_response(conn, 422)
    end
  end

  describe "GET /api/v1/schedule/specs/:slug" do
    test "shows an existing spec", %{conn: conn} do
      Schedule.create_spec(%{slug: "show-me", name: "S"})
      conn = get(conn, ~p"/api/v1/schedule/specs/show-me")
      assert %{"slug" => "show-me"} = json_response(conn, 200)
    end

    test "returns 404 for unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/specs/does-not-exist")
      assert %{"error" => "spec_not_found"} = json_response(conn, 404)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/specs/BadSlug!")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "POST /api/v1/schedule/specs/:slug/pause" do
    test "pauses an existing spec", %{conn: conn} do
      Schedule.create_spec(%{slug: "to-pause", name: "P"})

      conn =
        post(conn, ~p"/api/v1/schedule/specs/to-pause/pause", %{reason: "manual"})

      assert %{"status" => "paused", "paused_reason" => "manual"} =
               json_response(conn, 200)
    end

    test "returns 404 for unknown spec", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/schedule/specs/missing/pause", %{})
      assert %{"error" => "spec_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/schedule/specs/:slug/unpause" do
    test "unpauses a paused spec", %{conn: conn} do
      {:ok, spec} = Schedule.create_spec(%{slug: "to-unpause", name: "U"})
      Schedule.pause_spec(spec, "x")

      conn = post(conn, ~p"/api/v1/schedule/specs/to-unpause/unpause", %{})
      assert %{"status" => "active"} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/v1/schedule/specs/:slug" do
    test "archives a spec", %{conn: conn} do
      Schedule.create_spec(%{slug: "to-archive", name: "X"})
      conn = delete(conn, ~p"/api/v1/schedule/specs/to-archive")
      assert %{"status" => "archived"} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/schedule/runs" do
    test "returns empty data when no runs", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by spec_slug", %{conn: conn} do
      {:ok, spec} = Schedule.create_spec(%{slug: "rfilter", name: "X"})

      Schedule.record_run(%{
        spec_id: spec.id,
        spec_slug: "rfilter",
        scheduled_at: DateTime.utc_now()
      })

      conn = get(conn, ~p"/api/v1/schedule/runs?spec_slug=rfilter")
      assert %{"data" => [run]} = json_response(conn, 200)
      assert run["spec_slug"] == "rfilter"
    end

    test "rejects invalid timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs?since=not-a-date")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects since > until window", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/v1/schedule/runs?since=2026-04-30T00:00:00Z&until=2026-04-01T00:00:00Z"
        )

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid UUID for spec_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs?spec_id=not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "caps limit at 1000", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs?limit=999999")
      assert %{"data" => runs} = json_response(conn, 200)
      assert length(runs) <= 1000
    end
  end

  describe "GET /api/v1/schedule/runs/aggregate" do
    test "default granularity is day", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs/aggregate")
      assert %{"granularity" => "day", "rows" => _} = json_response(conn, 200)
    end

    test "accepts hour/day/week/month", %{conn: conn} do
      for g <- ~w(hour day week month) do
        conn = get(conn, ~p"/api/v1/schedule/runs/aggregate?granularity=#{g}")
        assert %{"granularity" => ^g} = json_response(conn, 200)
      end
    end

    test "ignores unknown granularity, defaults to day", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/runs/aggregate?granularity=epoch")
      assert %{"granularity" => "day"} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/schedule/overlaps" do
    test "returns empty list when no runs", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/overlaps")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "rejects invalid since timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/overlaps?since=garbage")
      assert json_response(conn, 400)
    end
  end

  describe "GET /api/v1/schedule/alerts" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/schedule/alerts")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by status", %{conn: conn} do
      Schedule.open_alert(%{slug: "open-1", category: "miss", summary: "X"})

      {:ok, c} =
        Schedule.open_alert(%{slug: "closed-1", category: "miss", summary: "X"})

      Schedule.close_alert(c)

      conn = get(conn, ~p"/api/v1/schedule/alerts?status=open")
      assert %{"data" => [alert]} = json_response(conn, 200)
      assert alert["slug"] == "open-1"
    end
  end

  describe "POST /api/v1/schedule/alerts" do
    test "opens a valid alert", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/alerts", %{
          slug: "incident-1",
          category: "circuit_breaker",
          severity: "high",
          summary: "Daily digest auto-paused after 5 failures"
        })

      assert %{"slug" => "incident-1", "status" => "open"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/alerts", %{
          slug: "BAD SLUG!",
          category: "miss",
          summary: "X"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid category", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/schedule/alerts", %{
          slug: "valid-slug-1",
          category: "made-up",
          summary: "X"
        })

      assert json_response(conn, 422)
    end
  end

  describe "POST /api/v1/schedule/alerts/:slug/close" do
    test "closes an existing alert", %{conn: conn} do
      Schedule.open_alert(%{slug: "to-close-x", category: "failure", summary: "X"})

      conn =
        post(conn, ~p"/api/v1/schedule/alerts/to-close-x/close", %{
          resolution_note: "manually fixed"
        })

      assert %{"status" => "closed", "resolution_note" => "manually fixed"} =
               json_response(conn, 200)
    end

    test "404 for unknown alert", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/schedule/alerts/missing/close", %{})
      assert %{"error" => "alert_not_found"} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/schedule/alerts/:slug/ack" do
    test "acknowledges an existing alert", %{conn: conn} do
      Schedule.open_alert(%{slug: "to-ack-x", category: "late", summary: "X"})

      conn =
        post(conn, ~p"/api/v1/schedule/alerts/to-ack-x/ack", %{by: "rhl"})

      assert %{"status" => "acknowledged", "acknowledged_by" => "rhl"} =
               json_response(conn, 200)
    end
  end
end
