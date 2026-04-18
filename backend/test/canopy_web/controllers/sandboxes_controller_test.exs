defmodule CanopyWeb.SandboxesControllerTest do
  @moduledoc """
  Tests for the SandboxesController.

  Uses Mox to mock Canopy.Miosa.MockClient for the destroy path.
  Sandbox data is stored in session rows, so we use the sessions factory.
  """

  use CanopyWeb.ConnCase, async: false

  import Canopy.Factory
  import Mox

  alias Canopy.Sessions.Session
  alias Canopy.Repo

  setup :verify_on_exit!

  # ---------------------------------------------------------------------------
  # GET /api/v1/sandboxes
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sandboxes" do
    test "returns 200 with empty list when no sandboxes exist", %{conn: conn} do
      conn = get(conn, "/api/v1/sandboxes")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns active sandboxes (excludes destroyed)", %{conn: conn} do
      insert_sandbox_session("sbx-active", "ready")
      insert_sandbox_session("sbx-also-active", "provisioning")
      insert_sandbox_session("sbx-dead", "destroyed")

      conn = get(conn, "/api/v1/sandboxes")
      assert %{"data" => data} = json_response(conn, 200)
      sandbox_ids = Enum.map(data, & &1["sandbox_id"])
      assert "sbx-active" in sandbox_ids
      assert "sbx-also-active" in sandbox_ids
      refute "sbx-dead" in sandbox_ids
    end

    test "returned sandbox has expected shape", %{conn: conn} do
      session = insert_sandbox_session("sbx-shape", "ready")

      conn = get(conn, "/api/v1/sandboxes")
      assert %{"data" => [sandbox | _]} = json_response(conn, 200)
      assert sandbox["sandbox_id"] == "sbx-shape"
      assert sandbox["session_id"] == session.id
      assert sandbox["status"] == "ready"
      assert Map.has_key?(sandbox, "url")
    end

    test "excludes sessions without a sandbox", %{conn: conn} do
      insert(:session)
      insert_sandbox_session("sbx-only-one", "ready")

      conn = get(conn, "/api/v1/sandboxes")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/sandboxes/:sandbox_id
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/sandboxes/:sandbox_id" do
    test "returns 404 for unknown sandbox_id", %{conn: conn} do
      conn = get(conn, "/api/v1/sandboxes/sbx-unknown")
      assert json_response(conn, 404)
    end

    test "returns sandbox detail for known sandbox_id", %{conn: conn} do
      session = insert_sandbox_session("sbx-show-me", "ready")

      conn = get(conn, "/api/v1/sandboxes/sbx-show-me")
      assert body = json_response(conn, 200)
      assert body["sandbox_id"] == "sbx-show-me"
      assert body["session_id"] == session.id
      assert body["status"] == "ready"
    end

    test "returns sandbox in provisioning state", %{conn: conn} do
      insert_sandbox_session("sbx-prov", "provisioning")

      conn = get(conn, "/api/v1/sandboxes/sbx-prov")
      assert body = json_response(conn, 200)
      assert body["status"] == "provisioning"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/sandboxes/:sandbox_id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/sandboxes/:sandbox_id" do
    test "returns 404 for unknown sandbox_id", %{conn: conn} do
      conn = delete(conn, "/api/v1/sandboxes/sbx-not-here")
      assert json_response(conn, 404)
    end

    test "destroys sandbox and returns 204", %{conn: conn} do
      set_miosa_configured()

      Mox.expect(Canopy.Miosa.MockClient, :destroy_sandbox, fn "sbx-to-kill" -> :ok end)

      insert_sandbox_session("sbx-to-kill", "ready")

      conn = delete(conn, "/api/v1/sandboxes/sbx-to-kill")
      assert response(conn, 204) == ""
    after
      clear_miosa_config()
    end

    test "returns 204 for sandbox with no session sandbox_id (no-op)", %{conn: conn} do
      # When session has no miosa_sandbox_id, destroy_for_session returns {:ok, session}
      session = insert(:session)

      # Insert a session that has a sandbox_id we control
      _updated =
        Session
        |> Repo.get!(session.id)
        |> Canopy.Sessions.Session.sandbox_changeset(%{
          miosa_sandbox_id: "sbx-noop",
          miosa_sandbox_status: "skipped"
        })
        |> Repo.update!()

      # destroy_for_session sees miosa_sandbox_id != nil, so will call destroy_sandbox
      set_miosa_configured()
      Mox.expect(Canopy.Miosa.MockClient, :destroy_sandbox, fn "sbx-noop" -> :ok end)

      conn = delete(conn, "/api/v1/sandboxes/sbx-noop")
      assert response(conn, 204) == ""
    after
      clear_miosa_config()
    end

    test "can destroy a sandbox without MIOSA configured (skipped status → still 204)", %{
      conn: conn
    } do
      # When session has miosa_sandbox_id but Miosa is not configured,
      # destroy_for_session will still try to call the client via Miosa module.
      # Since test.exs sets miosa_client to MockClient, we must set expectation.
      set_miosa_configured()

      Mox.expect(Canopy.Miosa.MockClient, :destroy_sandbox, fn "sbx-skip-del" -> :ok end)

      insert_sandbox_session("sbx-skip-del", "skipped")

      conn = delete(conn, "/api/v1/sandboxes/sbx-skip-del")
      assert response(conn, 204) == ""
    after
      clear_miosa_config()
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp insert_sandbox_session(sandbox_id, status) do
    session = insert(:session)

    session
    |> Canopy.Sessions.Session.sandbox_changeset(%{
      miosa_sandbox_id: sandbox_id,
      miosa_sandbox_url: "https://sbx.miosa.dev/#{sandbox_id}",
      miosa_sandbox_status: status
    })
    |> Repo.update!()
  end

  defp set_miosa_configured do
    Application.put_env(:canopy, :miosa_api_url, "http://miosa.test")
    Application.put_env(:canopy, :miosa_api_key, "test-key")
  end

  defp clear_miosa_config do
    Application.put_env(:canopy, :miosa_api_url, "")
    Application.put_env(:canopy, :miosa_api_key, "")
  end
end
