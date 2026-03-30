defmodule CanopyWeb.AuthSecurityRedTeamTest do
  @moduledoc """
  Red-team adversarial security tests for the Canopy auth system.

  ## Audit Reference
  These tests document CONFIRMED vulnerabilities found during the sprint-01
  security audit. Each test is tagged :security and carries a CVE-style
  identifier matching the audit report:

    S-02  Missing RBAC — any authenticated user can call admin-only endpoints
    S-04  Role injection — registration endpoint accepts role: "admin" in params
    S-05  SSE token in query param — Bearer bypass on streaming routes

  ## Design intent
  Tests in this file are MEANT TO PASS against the current (vulnerable)
  codebase. They prove the vulnerability is exploitable today. When a fix is
  shipped each test must be inverted (or deleted and replaced by a
  positive security test) to confirm the fix holds.

  ## Running
      mix test test/canopy_web/plugs/auth_security_red_team_test.exs
      mix test --only security

  ## Do NOT modify source files
  This file only creates new tests. No source files were changed.
  The file local_trusted_auth_test.exs already exists and covers the
  LocalTrustedAuth plug's functional spec. This file covers the
  adversarial/red-team surface orthogonal to that spec.
  """
  use CanopyWeb.ConnCase

  import Canopy.TestHelpers

  @moduletag :security

  # ────────────────────────────────────────────────────────────────────────────
  # S-04: Role injection via registration endpoint
  #
  # Vulnerability: POST /api/v1/auth/register passes the raw params map
  # directly to User.changeset/2. The changeset casts :role from user input
  # (see user.ex line 25: cast(attrs, [:name, :email, :password, :role, ...])).
  # Any caller can therefore self-assign role: "admin" at registration time
  # without any privilege.
  #
  # Root cause: User.changeset/2 includes :role in the cast list and there is
  # no allowlist guard in the controller to strip :role from untrusted input
  # before passing it to the changeset.
  #
  # Expected fix: Remove :role from the cast list in User.changeset/2 and
  # provide a separate admin-only update_role changeset; OR strip :role from
  # registration params in the controller before calling the changeset.
  # ────────────────────────────────────────────────────────────────────────────

  describe "S-04: role injection via registration" do
    @tag :security
    @tag :s04_role_injection
    test "POST /api/v1/auth/register accepts role: admin and persists it", %{conn: conn} do
      # VULNERABILITY PROOF:
      # A fresh, unauthenticated caller registers with role "admin" in the body.
      # The controller passes params directly to User.changeset/2, which casts
      # :role without stripping it. The created user has role "admin".
      #
      # This test PASSES against the current codebase, proving the injection works.
      # It should FAIL (return a user with role "member") once the fix is applied.

      unique = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

      conn =
        post(conn, "/api/v1/auth/register", %{
          "name" => "Attacker #{unique}",
          "email" => "attacker-#{unique}@evil.test",
          "password" => "password123",
          # The injection vector — no authenticated session, no admin privilege
          "role" => "admin"
        })

      # The registration succeeds (201) and the response contains role: "admin".
      # A properly secured endpoint would either return 422 (role not allowed) or
      # silently ignore the role field and return role: "member".
      assert conn.status == 201,
             "S-04: Registration with role injection should currently succeed (201). " <>
               "If this returns 422, the fix may already be in place — verify and invert this test."

      body = Jason.decode!(conn.resp_body)

      assert body["user"]["role"] == "admin",
             "S-04: The injected role 'admin' was NOT persisted — vulnerability may be fixed. " <>
               "Current role: #{inspect(body["user"]["role"])}. " <>
               "If this assertion fails, the fix is confirmed — invert this test."
    end

    @tag :security
    @tag :s04_role_injection
    test "injected admin user can authenticate and receive admin role in JWT claims", %{
      conn: conn
    } do
      # VULNERABILITY PROOF (second stage):
      # After self-promoting to admin via registration, the attacker's JWT will
      # embed role: "admin" in its claims (see auth_controller.ex line 54:
      # encode_and_sign(user, %{"role" => user.role}, ...)).
      # Any downstream plug reading claims["role"] will see "admin".

      unique = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
      email = "attacker2-#{unique}@evil.test"
      password = "password123"

      # Step 1: inject admin role at registration
      reg_conn =
        post(conn, "/api/v1/auth/register", %{
          "name" => "Attacker2 #{unique}",
          "email" => email,
          "password" => password,
          "role" => "admin"
        })

      if reg_conn.status != 201 do
        # Fix already deployed — skip second-stage check
        :ok
      else
        reg_body = Jason.decode!(reg_conn.resp_body)

        if reg_body["user"]["role"] == "admin" do
          # Step 2: log in and verify the JWT carries admin role
          login_conn =
            post(build_conn(), "/api/v1/auth/login", %{
              "email" => email,
              "password" => password
            })

          assert login_conn.status == 200,
                 "S-04 stage 2: Login after injection should succeed"

          login_body = Jason.decode!(login_conn.resp_body)

          assert login_body["user"]["role"] == "admin",
                 "S-04 stage 2: Login response must reflect persisted admin role. " <>
                   "Got: #{inspect(login_body["user"]["role"])}"
        end
      end
    end

    @tag :security
    @tag :s04_role_injection
    test "registration with role: viewer also persists (confirming open cast)", %{conn: conn} do
      # SUPPORTING EVIDENCE: The cast is fully open — any valid role string is
      # accepted. This shows the vector is not limited to "admin".
      unique = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)

      conn =
        post(conn, "/api/v1/auth/register", %{
          "name" => "RoleTest #{unique}",
          "email" => "roletest-#{unique}@evil.test",
          "password" => "password123",
          "role" => "viewer"
        })

      if conn.status == 201 do
        body = Jason.decode!(conn.resp_body)

        assert body["user"]["role"] == "viewer",
               "S-04: Role 'viewer' was also injected via registration params. " <>
                 "Got: #{inspect(body["user"]["role"])}"
      end
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # S-02: Missing RBAC — DELETE /api/v1/users/:id
  #
  # Vulnerability: The router places /users under the :authenticated pipeline
  # with no additional RBAC plug. Any authenticated user (including "member"
  # role) can call DELETE /api/v1/users/:id to delete any other user account.
  #
  # Root cause: The :authenticated pipeline contains no role guard. The
  # UserController#delete action does not check current_user.role.
  #
  # Expected fix: Add a :require_admin plug to the /users resource scope; or
  # add an explicit role check in UserController#delete and #update.
  # ────────────────────────────────────────────────────────────────────────────

  describe "S-02: missing RBAC on DELETE /api/v1/users/:id" do
    @tag :security
    @tag :s02_missing_rbac
    test "member-role user can delete another user account", %{conn: conn} do
      # VULNERABILITY PROOF:
      # A "member" user authenticates and issues DELETE /api/v1/users/:id
      # targeting a victim user. The endpoint has no RBAC guard so the delete
      # succeeds. The member has effectively escalated to admin privilege for
      # this operation.

      # Create the victim user (admin)
      victim = insert_user(%{role: "admin"})

      # Create the attacker as a regular member
      attacker = insert_user(%{role: "member"})
      attacker_conn = authenticated_conn(conn, attacker)

      conn = delete(attacker_conn, "/api/v1/users/#{victim.id}")

      # The delete should be REJECTED (403 or 404) by a properly secured endpoint.
      # Currently it returns 200/204, proving the vulnerability.
      refute conn.status == 403,
             "S-02: Expected a 403 Forbidden for a member deleting another user, " <>
               "but got #{conn.status}. " <>
               "This confirms the RBAC gap: no role check on DELETE /users/:id. " <>
               "Once fixed this test must be inverted to assert conn.status == 403."

      # Confirm the delete went through (200 or 204 means actual deletion occurred)
      assert conn.status in [200, 204],
             "S-02: DELETE /api/v1/users/#{victim.id} by a member returned #{conn.status}. " <>
               "Expected 200/204 (proving the vulnerability). " <>
               "If this fails with 403, the fix is in place — invert this test."
    end

    @tag :security
    @tag :s02_missing_rbac
    test "member-role user can delete their own account (confirming endpoint reachability)", %{
      conn: conn
    } do
      # SUPPLEMENTARY: Confirms the endpoint is reachable at all for non-admin users.
      # A member deleting their own account is permissible, but the fact that
      # the same code path allows deleting others is the vulnerability.
      user = insert_user(%{role: "member"})
      authed_conn = authenticated_conn(conn, user)

      conn = delete(authed_conn, "/api/v1/users/#{user.id}")

      assert conn.status in [200, 204],
             "S-02 supplementary: DELETE /api/v1/users/:id is reachable for member role. " <>
               "Got: #{conn.status}"
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # S-02: Missing RBAC — PUT /api/v1/users/:id (role escalation via update)
  #
  # Vulnerability: Any authenticated user can PUT /api/v1/users/:id with
  # role: "admin" in the body. The UserController#update action passes params
  # to User.changeset/2, which casts :role (same vector as S-04). Combined with
  # no RBAC guard on the endpoint, any member can silently escalate their own
  # role (or another user's role) to "admin" post-registration.
  # ────────────────────────────────────────────────────────────────────────────

  describe "S-02: missing RBAC on PUT /api/v1/users/:id (role escalation)" do
    @tag :security
    @tag :s02_missing_rbac
    test "member-role user can escalate own role to admin via PUT", %{conn: conn} do
      # VULNERABILITY PROOF:
      # A "member" user calls PUT /api/v1/users/:own_id with role: "admin".
      # Because (a) any authenticated user can reach this endpoint and
      # (b) the changeset casts :role from input, the user's row is updated to admin.

      user = insert_user(%{role: "member"})
      authed_conn = authenticated_conn(conn, user)

      conn =
        put(authed_conn, "/api/v1/users/#{user.id}", %{
          "role" => "admin"
        })

      # 200 (success) proves the vulnerability is exploitable.
      # 403 means RBAC is enforced — fix is in place, invert this test.
      case conn.status do
        200 ->
          body = Jason.decode!(conn.resp_body)

          assert body["user"]["role"] == "admin",
                 "S-02: Member escalated to admin via PUT /users/:id. " <>
                   "Got role: #{inspect(body["user"]["role"])}. " <>
                   "Fix: enforce role-change requires admin; strip :role from update params for non-admin users."

        403 ->
          flunk(
            "S-02: Got 403 — RBAC may already be enforced. " <>
              "Verify and invert this test once confirmed fixed."
          )

        other ->
          # Any non-403 response on a non-admin role-change request indicates missing guard
          # (422 would only fire if the changeset rejects the role value, not because of RBAC)
          assert other in [200, 204],
                 "S-02: Unexpected status #{other} — investigate whether the fix addresses RBAC."
      end
    end

    @tag :security
    @tag :s02_missing_rbac
    test "member-role user can change another user's role via PUT", %{conn: conn} do
      # VULNERABILITY PROOF (cross-user):
      # Attacker (member) targets victim (also member) and escalates victim to admin.
      # The endpoint has no ownership check either.

      victim = insert_user(%{role: "member"})
      attacker = insert_user(%{role: "member"})
      attacker_conn = authenticated_conn(conn, attacker)

      conn =
        put(attacker_conn, "/api/v1/users/#{victim.id}", %{
          "role" => "admin"
        })

      # A 200 response here means both missing RBAC AND missing ownership check.
      refute conn.status == 403,
             "S-02 cross-user: Expected missing RBAC (no 403). " <>
               "Got #{conn.status}. " <>
               "Fix requires: (1) admin-only endpoint guard, (2) ownership check for non-admin updates."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # S-05: SSE token in query param — Bearer bypass on streaming routes
  #
  # Vulnerability: auth.ex extract_token/1 falls through to conn.params["token"]
  # when is_streaming_request?/1 returns true. is_streaming_request?/1 returns
  # true when:
  #   - The request path contains "/stream", OR
  #   - The Accept header contains "text/event-stream"
  #
  # The second condition is the bypass vector: any request to ANY endpoint
  # (including non-streaming ones) can skip Bearer header auth by:
  #   1. Adding ?token=<valid_jwt> to the URL query string, AND
  #   2. Setting Accept: text/event-stream
  #
  # This bypasses the "Bearer in Authorization header" requirement and leaks
  # tokens into server access logs, proxy logs, and browser history.
  #
  # Root cause: is_streaming_request?/1 checks Accept header content, meaning
  # any request can self-identify as a streaming request.
  #
  # Expected fix: Restrict query-param token acceptance to an explicit list of
  # known SSE route paths (e.g., "/activity/stream", "/logs/stream",
  # "/sessions/:id/stream") rather than trusting the Accept header.
  # ────────────────────────────────────────────────────────────────────────────

  describe "S-05: SSE token accepted in query param via Accept header bypass" do
    @tag :security
    @tag :s05_sse_token_bypass
    test "query param token authenticates a non-streaming endpoint when Accept: text/event-stream",
         %{conn: conn} do
      # VULNERABILITY PROOF:
      # A GET /api/v1/agents request (a JSON REST endpoint, NOT a streaming route)
      # is authenticated using only a ?token= query param. No Authorization header.
      # This succeeds because the Accept: text/event-stream header tricks
      # is_streaming_request?/1 into returning true.
      #
      # The token appearing in the URL is the security concern: it will appear in:
      #   - Web server access logs
      #   - Nginx/proxy access logs
      #   - Browser URL history
      #   - Referrer headers on any redirect
      #   - Shared bookmarks / copy-paste URL sharing
      #
      # This test proves the bypass works on a standard JSON endpoint.

      user = insert_user()
      _workspace = insert_workspace(user)
      token = generate_token(user)

      conn =
        conn
        # No Authorization header — the bypass uses query param only
        |> put_req_header("accept", "text/event-stream")
        |> get("/api/v1/agents?token=#{token}")

      # 200 proves authentication succeeded via query param — the bypass works.
      # 401 means the fix is in place — invert this test.
      assert conn.status == 200,
             "S-05: Expected 200 (query-param auth bypass works). Got #{conn.status}. " <>
               "If 401, the fix is in place — verify is_streaming_request?/1 no longer " <>
               "trusts the Accept header alone, then invert this test."
    end

    @tag :security
    @tag :s05_sse_token_bypass
    test "query param token does NOT authenticate a request without streaming signals", %{
      conn: conn
    } do
      # GUARD TEST: Without the bypass conditions (no streaming path, no SSE Accept),
      # a query-param-only token must be REJECTED. This confirms the fallback in
      # extract_token/1 is conditional, not global.

      user = insert_user()
      _workspace = insert_workspace(user)
      token = generate_token(user)

      conn =
        conn
        # Standard JSON Accept — does not trigger the streaming fallback
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/agents?token=#{token}")

      assert conn.status == 401,
             "S-05 guard: A non-streaming request with only a query-param token must be rejected (401). " <>
               "Got #{conn.status}. " <>
               "This confirms is_streaming_request?/1 is conditional. " <>
               "If this also returns 200, the query-param fallback is unconditional — severity is higher."
    end

    @tag :security
    @tag :s05_sse_token_bypass
    test "query param token authenticates the actual SSE stream endpoint", %{conn: conn} do
      # BASELINE: Confirm the query-param mechanism is working for its intended
      # purpose (actual SSE streaming endpoints). This test is positive-security —
      # it proves SSE clients can authenticate without a Bearer header.
      # The vulnerability is that the same mechanism leaks to non-SSE endpoints.

      user = insert_user()
      _workspace = insert_workspace(user)
      token = generate_token(user)

      conn =
        conn
        |> put_req_header("accept", "text/event-stream")
        |> get("/api/v1/activity/stream?token=#{token}")

      # The actual SSE endpoint may return 200 or attempt to stream.
      # We accept any non-401 status as proof that query-param auth works for SSE.
      refute conn.status == 401,
             "S-05 baseline: The SSE streaming endpoint /activity/stream must accept query-param " <>
               "token (used by SSE clients that cannot set Authorization headers). " <>
               "Got 401 — the SSE feature may be broken for non-WebSocket clients."
    end

    @tag :security
    @tag :s05_sse_token_bypass
    test "any path containing /stream accepts query param token (path-based bypass)", %{
      conn: conn
    } do
      # SECONDARY VECTOR: is_streaming_request?/1 also returns true when the
      # request path contains "/stream". An attacker can bypass Bearer auth on
      # a request to /api/v1/agents by crafting a path like
      # /api/v1/stream/../agents (if path traversal is not normalized) or by
      # registering a path with "stream" in the name.
      #
      # This test verifies the PATH-based trigger, separate from the Accept-based one.

      user = insert_user()
      _workspace = insert_workspace(user)
      token = generate_token(user)

      # The actual /activity/stream endpoint uses path-based trigger.
      # Authenticate with query param only (no Authorization header).
      conn =
        conn
        |> get("/api/v1/activity/stream?token=#{token}")

      # Any non-401 confirms path-based query-param auth works.
      refute conn.status == 401,
             "S-05 path vector: /activity/stream must accept query-param token. Got 401."
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # S-02 supplementary: Unauthenticated access to /users endpoints
  #
  # Confirm that the :authenticated pipeline does block completely unauthenticated
  # requests to /users. This is a sanity check — the RBAC vulnerability is that
  # authenticated-but-low-privilege users can reach admin endpoints, not that
  # authentication itself is missing.
  # ────────────────────────────────────────────────────────────────────────────

  describe "S-02 supplementary: authentication guard on /users endpoints" do
    @tag :security
    test "DELETE /api/v1/users/:id requires authentication", %{conn: conn} do
      # SANITY CHECK: Unauthenticated DELETE must return 401.
      # This confirms the :authenticated pipeline is wired to /users.
      fake_id = Ecto.UUID.generate()
      conn = delete(conn, "/api/v1/users/#{fake_id}")

      assert conn.status == 401,
             "DELETE /api/v1/users/:id must require authentication. Got #{conn.status}."
    end

    @tag :security
    test "PUT /api/v1/users/:id requires authentication", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = put(conn, "/api/v1/users/#{fake_id}", %{"role" => "admin"})

      assert conn.status == 401,
             "PUT /api/v1/users/:id must require authentication. Got #{conn.status}."
    end
  end
end
