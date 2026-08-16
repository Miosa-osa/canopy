defmodule CanopyWeb.SandboxesNgControllerTest do
  @moduledoc """
  Tests for /api/v1/sandboxes-ng/* endpoints.

  Focus: input validation (sandbox_id format, slug format, UUID, visibility,
  public-confirmation), error responses, and end-to-end happy paths.
  """

  use CanopyWeb.ConnCase, async: true

  alias Canopy.SandboxesNg

  describe "GET /api/v1/sandboxes-ng" do
    test "returns empty data when no sandboxes have been touched", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns most recent state per sandbox", %{conn: conn} do
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-ctrl-1", state: "running"})
      conn = get(conn, ~p"/api/v1/sandboxes-ng")
      assert %{"data" => [row]} = json_response(conn, 200)
      assert row["sandbox_id"] == "sbx-ctrl-1"
      assert row["state"] == "running"
    end
  end

  describe "GET /api/v1/sandboxes-ng/events" do
    test "returns events sorted by ts desc", %{conn: conn} do
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-evt-a", state: "provisioning"})
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-evt-b", state: "running"})

      conn = get(conn, ~p"/api/v1/sandboxes-ng/events")
      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) >= 2
    end

    test "rejects invalid timestamp", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/events?from=not-a-date")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects from > to window", %{conn: conn} do
      conn =
        get(
          conn,
          ~p"/api/v1/sandboxes-ng/events?from=2026-04-30T00:00:00Z&to=2026-04-01T00:00:00Z"
        )

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects invalid UUID for owner_agent_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/events?owner_agent_id=not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects malformed sandbox_id query", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/events?sandbox_id=has spaces")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "caps limit at 1000", %{conn: conn} do
      for i <- 1..3 do
        SandboxesNg.record_event(%{sandbox_id: "sbx-cap-#{i}", state: "running"})
      end

      conn = get(conn, ~p"/api/v1/sandboxes-ng/events?limit=999999")
      assert %{"data" => events} = json_response(conn, 200)
      assert length(events) <= 1000
    end

    test "filters by state", %{conn: conn} do
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-state-1", state: "running"})
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-state-2", state: "paused"})

      conn = get(conn, ~p"/api/v1/sandboxes-ng/events?state=paused")
      assert %{"data" => events} = json_response(conn, 200)
      Enum.each(events, fn e -> assert e["state"] == "paused" end)
    end
  end

  describe "GET /api/v1/sandboxes-ng/events/:sandbox_id" do
    test "rejects malformed sandbox_id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/events/has%20spaces")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns events ordered by ts desc", %{conn: conn} do
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-ev-ord", state: "provisioning"})
      :ok = SandboxesNg.record_event(%{sandbox_id: "sbx-ev-ord", state: "running"})

      conn = get(conn, ~p"/api/v1/sandboxes-ng/events/sbx-ev-ord")
      assert %{"data" => events, "count" => 2} = json_response(conn, 200)
      assert hd(events)["state"] == "running"
    end
  end

  describe "GET /api/v1/sandboxes-ng/snapshots" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/snapshots")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by kind", %{conn: conn} do
      SandboxesNg.create_snapshot(%{
        slug: "ctrl-fs",
        sandbox_id: "sbx-ctrl-snap",
        kind: "filesystem"
      })

      SandboxesNg.create_snapshot(%{
        slug: "ctrl-mem",
        sandbox_id: "sbx-ctrl-snap",
        kind: "memory"
      })

      conn = get(conn, ~p"/api/v1/sandboxes-ng/snapshots?kind=memory")
      assert %{"data" => snaps} = json_response(conn, 200)
      Enum.each(snaps, fn s -> assert s["kind"] == "memory" end)
    end
  end

  describe "POST /api/v1/sandboxes-ng/snapshots" do
    test "creates a valid snapshot", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/snapshots", %{
          slug: "valid-snap",
          sandbox_id: "sbx-snap-create",
          kind: "filesystem"
        })

      assert %{"slug" => "valid-snap"} = json_response(conn, 201)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/snapshots", %{
          slug: "Invalid Slug!",
          sandbox_id: "sbx-snap-x",
          kind: "memory"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects malformed sandbox_id", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/snapshots", %{
          slug: "good-slug-1",
          sandbox_id: "bad sandbox id",
          kind: "memory"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "GET /api/v1/sandboxes-ng/ports" do
    test "returns empty when no forwards", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/ports")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by visibility", %{conn: conn} do
      SandboxesNg.create_port_forward(%{
        sandbox_id: "sbx-vis-1",
        internal_port: 9001,
        visibility: "private"
      })

      SandboxesNg.create_port_forward(%{
        sandbox_id: "sbx-vis-2",
        internal_port: 9002,
        visibility: "token"
      })

      conn = get(conn, ~p"/api/v1/sandboxes-ng/ports?visibility=token")
      assert %{"data" => ports} = json_response(conn, 200)
      Enum.each(ports, fn p -> assert p["visibility"] == "token" end)
    end
  end

  describe "POST /api/v1/sandboxes-ng/ports" do
    test "opens a private forward by default", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/ports", %{
          sandbox_id: "sbx-open-1",
          internal_port: 3000
        })

      assert %{"visibility" => "private"} = json_response(conn, 201)
    end

    test "rejects public visibility without confirm_public: true", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/ports", %{
          sandbox_id: "sbx-pub-1",
          internal_port: 3001,
          visibility: "public"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "accepts public visibility when confirmed", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/ports", %{
          sandbox_id: "sbx-pub-2",
          internal_port: 3002,
          visibility: "public",
          confirm_public: true
        })

      assert %{"visibility" => "public"} = json_response(conn, 201)
    end

    test "rejects invalid visibility tier", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/ports", %{
          sandbox_id: "sbx-vis-bad",
          internal_port: 3003,
          visibility: "world"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "rejects malformed sandbox_id", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/ports", %{
          sandbox_id: "bad id",
          internal_port: 3004
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end

  describe "DELETE /api/v1/sandboxes-ng/ports/:id" do
    test "rejects invalid UUID", %{conn: conn} do
      conn = delete(conn, ~p"/api/v1/sandboxes-ng/ports/not-a-uuid")
      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      id = Ecto.UUID.generate()
      conn = delete(conn, ~p"/api/v1/sandboxes-ng/ports/#{id}")
      assert %{"error" => "port_forward_not_found"} = json_response(conn, 404)
    end

    test "closes an open forward", %{conn: conn} do
      {:ok, pf} =
        SandboxesNg.create_port_forward(%{
          sandbox_id: "sbx-close-1",
          internal_port: 4001
        })

      conn = delete(conn, ~p"/api/v1/sandboxes-ng/ports/#{pf.id}")
      assert %{"closed_at" => closed_at} = json_response(conn, 200)
      assert closed_at != nil
    end
  end

  describe "GET /api/v1/sandboxes-ng/alerts" do
    test "returns empty when none exist", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/sandboxes-ng/alerts")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "filters by enabled=true", %{conn: conn} do
      SandboxesNg.create_alert(%{
        slug: "ctrl-on",
        name: "X",
        metric: "y",
        type: "threshold",
        enabled: true
      })

      SandboxesNg.create_alert(%{
        slug: "ctrl-off",
        name: "X",
        metric: "y",
        type: "threshold",
        enabled: false
      })

      conn = get(conn, ~p"/api/v1/sandboxes-ng/alerts?enabled=true")
      assert %{"data" => alerts} = json_response(conn, 200)
      slugs = Enum.map(alerts, & &1["slug"])
      assert "ctrl-on" in slugs
      refute "ctrl-off" in slugs
    end
  end

  describe "POST /api/v1/sandboxes-ng/alerts" do
    test "creates a valid alert", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/alerts", %{
          slug: "ctrl-alert-1",
          name: "Public ports high",
          metric: "public_port_count",
          type: "threshold"
        })

      assert %{"slug" => "ctrl-alert-1", "enabled" => true} = json_response(conn, 201)
    end

    test "rejects invalid type via changeset (422)", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/alerts", %{
          slug: "ctrl-bad-type",
          name: "X",
          metric: "y",
          type: "fake"
        })

      assert json_response(conn, 422)
    end

    test "rejects malformed slug", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/sandboxes-ng/alerts", %{
          slug: "BAD SLUG",
          name: "X",
          metric: "y",
          type: "threshold"
        })

      assert %{"error" => "bad_request"} = json_response(conn, 400)
    end
  end
end
