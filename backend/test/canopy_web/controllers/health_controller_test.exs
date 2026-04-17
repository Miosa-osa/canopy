defmodule CanopyWeb.HealthControllerTest do
  use CanopyWeb.ConnCase, async: true

  describe "GET /api/v1/health" do
    test "returns 200 with status and version", %{conn: conn} do
      conn = get(conn, "/api/v1/health")

      assert response = json_response(conn, 200)
      assert response["status"] == "ok"
      assert is_binary(response["version"])
      assert String.length(response["version"]) > 0
    end
  end
end
