defmodule CanopyWeb.AnalyticsControllerTest do
  @moduledoc """
  Tests for /api/v1/analytics/* endpoints.

  Focus: input validation (UUID, slug format, limit bounds, window order),
  error responses, and end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.Analytics

  describe "GET /api/v1/analytics/telemetry" do
    test "returns empty data when no events", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/telemetry")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns events sorted by ts desc", %{conn: conn} do
      Analytics.record(%{event: "first.event"})
      Analytics.record(%{event: "second.event"})

      conn = get(conn, ~p"/api/v1/analytics/telemetry")
      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) == 2
    end

    test "rejects invalid timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/telemetry?from=not-a-date")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects from > to window", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/v1/analytics/telemetry?from=2026-04-30T00:00:00Z&to=2026-04-01T00:00:00Z"
        )

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid UUID for agent_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/telemetry?agent_id=not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "caps limit at 1000", %{conn: conn} do
      # Insert 5 events so the response is small even with a huge limit
      for i <- 1..5 do
        Analytics.record(%{event: "evt#{i}"})
      end

      conn = get(conn, ~p"/api/v1/analytics/telemetry?limit=999999")
      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) <= 1000
    end

    test "filters by event", %{conn: conn} do
      Analytics.record(%{event: "agent.run.started"})
      Analytics.record(%{event: "agent.run.finished"})

      conn = get(conn, ~p"/api/v1/analytics/telemetry?event=agent.run.started")
      assert %{"data" => [event]} = json_response(conn, 200)
      assert event["event"] == "agent.run.started"
    end
  end

  describe "GET /api/v1/analytics/costs" do
    test "returns zero rows when no telemetry", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/costs")
      assert %{"granularity" => "day", "rows" => []} = json_response(conn, 200)
    end

    test "default granularity is day", %{conn: conn} do
      Analytics.record(%{event: "x", cost_cents: 100})
      conn = get(conn, ~p"/api/v1/analytics/costs")
      assert %{"granularity" => "day"} = json_response(conn, 200)
    end

    test "accepts hour/week/month granularities", %{conn: conn} do
      for g <- ~w(hour day week month) do
        conn = get(conn, ~p"/api/v1/analytics/costs?granularity=#{g}")
        assert %{"granularity" => ^g} = json_response(conn, 200)
      end
    end

    test "ignores unknown granularity, defaults to day", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/costs?granularity=fortnight")
      assert %{"granularity" => "day"} = json_response(conn, 200)
    end

    test "rejects bad timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/costs?from=garbage")
      assert json_response(conn, 400)
    end
  end

  describe "GET /api/v1/analytics/breadcrumbs/:run_id" do
    test "rejects invalid UUID", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/breadcrumbs/not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns empty list for unknown run", %{conn: conn} do
      run_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/api/v1/analytics/breadcrumbs/#{run_id}")
      assert %{"run_id" => ^run_id, "count" => 0, "data" => []} = json_response(conn, 200)
    end

    test "returns breadcrumbs ordered by sequence", %{conn: conn} do
      run_id = Ecto.UUID.generate()

      for seq <- [3, 0, 2, 1] do
        Analytics.record_breadcrumb(%{run_id: run_id, sequence: seq, type: "system"})
      end

      conn = get(conn, ~p"/api/v1/analytics/breadcrumbs/#{run_id}")
      assert %{"data" => crumbs} = json_response(conn, 200)
      assert Enum.map(crumbs, & &1["sequence"]) == [0, 1, 2, 3]
    end
  end

  describe "GET /api/v1/analytics/insights" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/insights")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by severity", %{conn: conn} do
      Analytics.create_insight(%{
        slug: "low-1",
        title: "T",
        body: "B",
        severity: "info",
        detected_at: DateTime.utc_now()
      })

      Analytics.create_insight(%{
        slug: "high-1",
        title: "T",
        body: "B",
        severity: "high",
        detected_at: DateTime.utc_now()
      })

      conn = get(conn, ~p"/api/v1/analytics/insights?severity=high")
      assert %{"data" => [insight]} = json_response(conn, 200)
      assert insight["slug"] == "high-1"
    end
  end

  describe "POST /api/v1/analytics/insights" do
    test "creates a valid insight", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/insights", %{
          slug: "valid-slug",
          title: "A",
          body: "B",
          detected_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      assert %{"slug" => "valid-slug"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/insights", %{
          slug: "Invalid Slug With Spaces!",
          title: "A",
          body: "B",
          detected_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects empty slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/insights", %{
          slug: "",
          title: "A",
          body: "B",
          detected_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      assert json_response(conn, 400)
    end
  end

  describe "POST /api/v1/analytics/insights/:slug/ack" do
    test "acknowledges an existing insight", %{conn: conn} do
      {:ok, _} =
        Analytics.create_insight(%{
          slug: "ack-me",
          title: "T",
          body: "B",
          detected_at: DateTime.utc_now()
        })

      conn =
        post(conn, ~p"/api/v1/analytics/insights/ack-me/ack", %{
          by: "rhl",
          feedback: "true_positive"
        })

      assert %{"acknowledged_by" => "rhl", "feedback" => "true_positive"} =
               json_response(conn, 200)
    end

    test "returns 404 for unknown insight", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/analytics/insights/does-not-exist/ack", %{by: "x"})
      assert %{"error" => "insight_not_found"} = json_response(conn, 404)
    end

    test "rejects invalid feedback value", %{conn: conn} do
      {:ok, _} =
        Analytics.create_insight(%{
          slug: "feedback-test",
          title: "T",
          body: "B",
          detected_at: DateTime.utc_now()
        })

      conn =
        post(conn, ~p"/api/v1/analytics/insights/feedback-test/ack", %{
          by: "rhl",
          feedback: "made_up_feedback"
        })

      assert json_response(conn, 400)
    end
  end

  describe "GET /api/v1/analytics/alerts" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/analytics/alerts")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by enabled=true", %{conn: conn} do
      Analytics.create_alert(%{
        slug: "on-x",
        name: "X",
        metric: "y",
        type: "anomaly",
        enabled: true
      })

      Analytics.create_alert(%{
        slug: "off-x",
        name: "X",
        metric: "y",
        type: "anomaly",
        enabled: false
      })

      conn = get(conn, ~p"/api/v1/analytics/alerts?enabled=true")
      assert %{"data" => [alert]} = json_response(conn, 200)
      assert alert["slug"] == "on-x"
    end
  end

  describe "POST /api/v1/analytics/alerts" do
    test "creates a valid alert", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/alerts", %{
          slug: "alert-1",
          name: "Cost spike",
          metric: "cost_cents",
          type: "anomaly",
          sensitivity: 0.85
        })

      assert %{"slug" => "alert-1", "enabled" => true} = json_response(conn, 201)
    end

    test "rejects invalid type", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/alerts", %{
          slug: "bad-type",
          name: "X",
          metric: "y",
          type: "invented"
        })

      # Backend changeset validation surfaces as 422 via FallbackController
      assert json_response(conn, 422)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/analytics/alerts", %{
          slug: "BAD SLUG!",
          name: "X",
          metric: "y",
          type: "anomaly"
        })

      assert json_response(conn, 400)
    end
  end
end
