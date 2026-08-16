defmodule CanopyWeb.MCPControllerTest do
  @moduledoc """
  Tests for the MCP read-views controller:
    GET /api/v1/mcp/servers
    GET /api/v1/mcp/tool-calls
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory

  alias Canopy.Agents.ToolCall
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_tool_call(attrs) do
    session = insert(:session, status: "running")

    base = %{
      session_id: session.id,
      agent_id: "mcp-test-agent",
      tool_name: "analytics.query_telemetry",
      params: %{},
      status: "ok"
    }

    %ToolCall{}
    |> ToolCall.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/mcp/servers
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/mcp/servers" do
    test "returns an empty data list (Phase A stub)", %{conn: conn} do
      conn = get(conn, "/api/v1/mcp/servers")
      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/mcp/tool-calls
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/mcp/tool-calls" do
    test "returns an empty list when there are no tool calls", %{conn: conn} do
      # Clean any leftovers from prior tests in async: false suite.
      Repo.delete_all(ToolCall)

      conn = get(conn, "/api/v1/mcp/tool-calls")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "lists rows with the expected serialized shape", %{conn: conn} do
      Repo.delete_all(ToolCall)

      tc =
        insert_tool_call(%{
          tool_name: "analytics.query_telemetry",
          params: %{"limit" => 5}
        })

      conn = get(conn, "/api/v1/mcp/tool-calls")
      assert %{"data" => [row]} = json_response(conn, 200)

      assert row["id"] == tc.id
      assert row["tool_name"] == "analytics.query_telemetry"
      assert row["status"] == "ok"
      assert row["params"] == %{"limit" => 5}
      assert is_binary(row["session_id"])
      assert row["error"] == nil
    end

    test "filters by status when valid", %{conn: conn} do
      Repo.delete_all(ToolCall)

      _ok = insert_tool_call(%{tool_name: "a.ok", status: "ok"})
      err = insert_tool_call(%{tool_name: "a.err", status: "error", error: "boom"})

      conn = get(conn, "/api/v1/mcp/tool-calls?status=error")
      assert %{"data" => rows} = json_response(conn, 200)
      assert length(rows) == 1
      assert hd(rows)["id"] == err.id
      assert hd(rows)["error"] == "boom"
    end

    test "ignores invalid status values", %{conn: conn} do
      Repo.delete_all(ToolCall)

      insert_tool_call(%{tool_name: "a.ok", status: "ok"})

      conn = get(conn, "/api/v1/mcp/tool-calls?status=bogus")
      assert %{"data" => rows} = json_response(conn, 200)
      assert length(rows) == 1
    end

    test "caps limit at 1000", %{conn: conn} do
      conn = get(conn, "/api/v1/mcp/tool-calls?limit=999999")
      # Should not crash; just returns up to the cap.
      assert %{"data" => _} = json_response(conn, 200)
    end

    test "treats non-integer limit as default", %{conn: conn} do
      conn = get(conn, "/api/v1/mcp/tool-calls?limit=abc")
      assert %{"data" => _} = json_response(conn, 200)
    end
  end
end
