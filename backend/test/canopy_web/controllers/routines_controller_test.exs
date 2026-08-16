defmodule CanopyWeb.RoutinesControllerTest do
  @moduledoc "Controller tests for the Routines API."

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  # ---------------------------------------------------------------------------
  # GET /api/v1/routines
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/routines" do
    test "200 returns routine list", %{conn: conn} do
      insert(:routine, workspace_slug: "ctrl-routines-ws")
      conn = get(conn, "/api/v1/routines", workspace_slug: "ctrl-routines-ws")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["count"] >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/routines
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/routines" do
    test "201 creates and returns routine", %{conn: conn} do
      conn =
        post(conn, "/api/v1/routines", %{
          name: "Daily sync",
          cron: "0 9 * * *",
          prompt_template: "Run daily sync for {{workspace}}",
          workspace_slug: "default"
        })

      body = json_response(conn, 201)
      assert body["data"]["name"] == "Daily sync"
      assert String.starts_with?(body["data"]["short_id"], "R-")
      assert body["data"]["enabled"] == true
      assert body["data"]["run_count"] == 0
    end

    test "422 when required fields missing", %{conn: conn} do
      conn = post(conn, "/api/v1/routines", %{name: "Incomplete"})
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/routines/:id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/routines/:id" do
    test "200 returns routine by short_id", %{conn: conn} do
      routine = insert(:routine)
      conn = get(conn, "/api/v1/routines/#{routine.short_id}")
      body = json_response(conn, 200)
      assert body["data"]["short_id"] == routine.short_id
    end

    test "200 returns routine by uuid", %{conn: conn} do
      routine = insert(:routine)
      conn = get(conn, "/api/v1/routines/#{routine.id}")
      body = json_response(conn, 200)
      assert body["data"]["id"] == routine.id
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/routines/R-99999999")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /api/v1/routines/:id
  # ---------------------------------------------------------------------------

  describe "PATCH /api/v1/routines/:id" do
    test "200 updates the routine", %{conn: conn} do
      routine = insert(:routine)
      conn = patch(conn, "/api/v1/routines/#{routine.short_id}", %{name: "Updated name"})
      body = json_response(conn, 200)
      assert body["data"]["name"] == "Updated name"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = patch(conn, "/api/v1/routines/R-99999999", %{name: "X"})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/routines/:id/enable
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/routines/:id/enable" do
    test "200 enables the routine", %{conn: conn} do
      routine = insert(:routine, enabled: false)
      conn = post(conn, "/api/v1/routines/#{routine.short_id}/enable")
      body = json_response(conn, 200)
      assert body["data"]["enabled"] == true
    end

    test "404 for unknown routine", %{conn: conn} do
      conn = post(conn, "/api/v1/routines/R-99999999/enable")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/routines/:id/disable
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/routines/:id/disable" do
    test "200 disables the routine", %{conn: conn} do
      routine = insert(:routine, enabled: true)
      conn = post(conn, "/api/v1/routines/#{routine.short_id}/disable")
      body = json_response(conn, 200)
      assert body["data"]["enabled"] == false
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/routines/:id/fire
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/routines/:id/fire" do
    test "200 fires routine and returns created work-unit", %{conn: conn} do
      routine =
        insert(:routine,
          creates: "task",
          workspace_slug: "default",
          prompt_template: "Run {{name}} for {{workspace}}"
        )

      conn = post(conn, "/api/v1/routines/#{routine.short_id}/fire")
      body = json_response(conn, 200)
      assert body["data"]["routine"]["run_count"] == 1
      assert body["data"]["created"]["workspace_slug"] == "default"
    end

    test "404 for unknown routine", %{conn: conn} do
      conn = post(conn, "/api/v1/routines/R-99999999/fire")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/routines/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/routines/:id" do
    test "204 deletes the routine", %{conn: conn} do
      routine = insert(:routine)
      conn = delete(conn, "/api/v1/routines/#{routine.short_id}")
      assert response(conn, 204) == ""
    end

    test "404 for unknown routine", %{conn: conn} do
      conn = delete(conn, "/api/v1/routines/R-99999999")
      assert json_response(conn, 404)
    end
  end
end
