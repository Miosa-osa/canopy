defmodule CanopyWeb.Plugs.LocalTrustedAuthTest do
  @moduledoc """
  E-02: Tests for CanopyWeb.Plugs.LocalTrustedAuth (sprint-01 A-02 deliverable).

  ## Sprint-01 Status (as of qa audit)
  - Module EXISTS: lib/canopy_web/plugs/local_trusted_auth.ex ✓
  - Router wired: `plug CanopyWeb.Plugs.LocalTrustedAuth` in :authenticated pipeline ✓
  - auth.ex updated: short-circuits when current_user already assigned ✓

  ## P1 Gap Found
  The plug sets conn.assigns[:current_user] and conn.assigns[:claims] but does NOT
  set conn.private[:guardian_default_resource]. The sprint spec required Guardian
  compatibility via that private key. Test 2b documents this gap.

  ## Integration Gap (P1)
  GET /api/v1/agents in local_trusted mode returns 200 only if WorkspaceAuth does
  not block requests without a real workspace_id. Test 3 verifies end-to-end flow.
  """
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers
  import Plug.Conn

  alias CanopyWeb.Plugs.LocalTrustedAuth

  # ── Test 1: local_trusted mode sets current_user assign ──────────────────

  describe "when auth_mode is local_trusted" do
    setup do
      Application.put_env(:canopy, :auth_mode, "local_trusted")
      on_exit(fn -> Application.delete_env(:canopy, :auth_mode) end)
      :ok
    end

    test "plug sets conn.assigns.current_user to a map with id, role, email", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))

      assert conn.assigns[:current_user] != nil,
             "current_user must be set in local_trusted mode"

      user = conn.assigns.current_user
      assert Map.has_key?(user, :id), "current_user must have :id key"
      assert Map.has_key?(user, :role), "current_user must have :role key"
      assert Map.has_key?(user, :email), "current_user must have :email key"
    end

    test "current_user has non-nil, non-empty id", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))
      user = conn.assigns.current_user

      assert user.id != nil
      assert user.id != ""
    end

    test "current_user has admin role", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))
      user = conn.assigns.current_user

      # Role must be :admin or "admin" (either atom or string is acceptable)
      assert user.role in [:admin, "admin"],
             "local_trusted user must have admin role, got: #{inspect(user.role)}"
    end

    test "plug also sets conn.assigns.claims for downstream compatibility", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))

      assert conn.assigns[:claims] != nil,
             "claims assign must be set for Guardian-compatible downstream plugs"

      claims = conn.assigns.claims
      assert is_map(claims)
      assert Map.has_key?(claims, "sub"), "claims must have 'sub' field"
    end

    test "plug does not halt the connection", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))
      refute conn.halted, "LocalTrustedAuth must not halt the connection"
    end
  end

  # ── Test 2a: default auth_mode is a passthrough ───────────────────────────

  describe "when auth_mode is not local_trusted (default)" do
    setup do
      Application.delete_env(:canopy, :auth_mode)
      :ok
    end

    test "plug does not set current_user", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))
      refute Map.has_key?(conn.assigns, :current_user),
             "current_user must not be set when auth_mode != local_trusted"
    end

    test "plug does not modify any existing assigns", %{conn: conn} do
      conn = assign(conn, :existing_key, "existing_value")
      conn_after = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))

      assert conn_after.assigns[:existing_key] == "existing_value",
             "LocalTrustedAuth must not modify existing assigns in passthrough mode"

      # Only the pre-existing key — no new keys added
      assert map_size(conn_after.assigns) == map_size(conn.assigns),
             "Passthrough mode must not add any new assigns. " <>
               "Before: #{inspect(Map.keys(conn.assigns))}, " <>
               "After: #{inspect(Map.keys(conn_after.assigns))}"
    end

    test "plug does not halt the connection", %{conn: conn} do
      conn = LocalTrustedAuth.call(conn, LocalTrustedAuth.init([]))
      refute conn.halted
    end
  end

  # ── Test 2b: guardian_default_resource (P1 gap documentation) ────────────

  describe "guardian_default_resource compatibility (P1 gap)" do
    setup do
      Application.put_env(:canopy, :auth_mode, "local_trusted")
      on_exit(fn -> Application.delete_env(:canopy, :auth_mode) end)
      :ok
    end

    test "conn.private[:guardian_default_resource] is set for Guardian compat" do
      conn = LocalTrustedAuth.call(%Plug.Conn{}, LocalTrustedAuth.init([]))

      resource = conn.private[:guardian_default_resource]

      assert resource != nil,
             "guardian_default_resource must be set for Guardian-compatible downstream plugins"

      assert is_binary(resource.id)
      assert resource.role == :admin
    end
  end

  # ── Test 3: integration — GET /api/v1/agents returns 200 ─────────────────

  describe "integration: authenticated endpoint without Authorization header" do
    setup do
      user = insert_user()
      _workspace = insert_workspace(user)

      Application.put_env(:canopy, :auth_mode, "local_trusted")
      Application.put_env(:canopy, :local_trusted_user_id, user.id)

      on_exit(fn ->
        Application.delete_env(:canopy, :auth_mode)
        Application.delete_env(:canopy, :local_trusted_user_id)
      end)

      :ok
    end

    test "GET /api/v1/agents returns 200 with no Authorization header", %{conn: conn} do
      # In local_trusted mode, LocalTrustedAuth sets current_user before Auth runs.
      # Auth.call/2 short-circuits when current_user is already assigned.
      # WorkspaceAuth uses the current_user to scope the workspace query.
      conn = get(conn, "/api/v1/agents")

      assert conn.status in [200, 204],
             "Expected 200 or 204 from GET /api/v1/agents in local_trusted mode " <>
               "with no Authorization header. Got #{conn.status}. " <>
               "Possible causes:\n" <>
               "  - LocalTrustedAuth not wired into :authenticated pipeline\n" <>
               "  - WorkspaceAuth blocking due to no workspace_id header\n" <>
               "  - Auth.call not short-circuiting on pre-set current_user"
    end
  end
end
