defmodule CanopyWeb.GovernanceControllerTest do
  @moduledoc """
  Controller tests for GovernanceController.

  Covers all 8 endpoints: rules CRUD, approvals index, approve, reject, audit log.
  """

  use CanopyWeb.ConnCase, async: true

  import Canopy.Factory

  alias Canopy.Governance

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp rule_attrs(overrides) do
    Map.merge(
      %{
        "name" => "ctrl-rule-#{System.unique_integer([:positive])}",
        "action" => "log",
        "enabled" => true,
        "priority" => 0,
        "conditions" => %{}
      },
      overrides
    )
  end

  defp create_rule!(overrides) do
    {:ok, rule} = Governance.create_rule(rule_attrs(overrides))
    rule
  end

  defp session_id, do: insert(:session).id

  # ---------------------------------------------------------------------------
  # GET /api/v1/governance/rules
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/governance/rules" do
    test "returns 200 with empty list when no rules", %{conn: conn} do
      conn = get(conn, "/api/v1/governance/rules")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns all rules", %{conn: conn} do
      create_rule!(%{"name" => "rule-a"})
      create_rule!(%{"name" => "rule-b"})

      conn = get(conn, "/api/v1/governance/rules")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 2
    end

    test "enabled_only=true filters disabled rules", %{conn: conn} do
      create_rule!(%{"name" => "enabled-ctrl", "enabled" => true})
      create_rule!(%{"name" => "disabled-ctrl", "enabled" => false})

      conn = get(conn, "/api/v1/governance/rules?enabled_only=true")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["enabled"] == true))
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/governance/rules
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/governance/rules" do
    test "creates a rule and returns 201", %{conn: conn} do
      params = rule_attrs(%{"action" => "block", "conditions" => %{"prompt_regex" => "deploy"}})

      conn = post(conn, "/api/v1/governance/rules", params)
      assert %{"id" => id, "action" => "block"} = json_response(conn, 201)
      assert is_binary(id)
    end

    test "returns 422 on validation error", %{conn: conn} do
      conn = post(conn, "/api/v1/governance/rules", %{"action" => "block"})
      assert json_response(conn, 422)
    end

    test "returns 422 on invalid action", %{conn: conn} do
      params = rule_attrs(%{"action" => "explode"})
      conn = post(conn, "/api/v1/governance/rules", params)
      assert json_response(conn, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/v1/governance/rules/:id
  # ---------------------------------------------------------------------------

  describe "PUT /api/v1/governance/rules/:id" do
    test "updates rule and returns 200", %{conn: conn} do
      rule = create_rule!(%{"priority" => 5})

      conn = put(conn, "/api/v1/governance/rules/#{rule.id}", %{"priority" => 99})
      assert %{"priority" => 99} = json_response(conn, 200)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = put(conn, "/api/v1/governance/rules/#{Ecto.UUID.generate()}", %{"priority" => 1})
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /api/v1/governance/rules/:id
  # ---------------------------------------------------------------------------

  describe "DELETE /api/v1/governance/rules/:id" do
    test "deletes rule and returns 204", %{conn: conn} do
      rule = create_rule!(%{})

      conn = delete(conn, "/api/v1/governance/rules/#{rule.id}")
      assert response(conn, 204)
    end

    test "returns 404 for unknown id", %{conn: conn} do
      conn = delete(conn, "/api/v1/governance/rules/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/governance/approvals
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/governance/approvals" do
    test "returns 200 with empty list when none", %{conn: conn} do
      conn = get(conn, "/api/v1/governance/approvals")
      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns pending approvals by default", %{conn: conn} do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, _approval} = Governance.request_approval(rule.id, sid)

      conn = get(conn, "/api/v1/governance/approvals")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
      assert Enum.all?(data, &(&1["status"] == "pending"))
    end

    test "filters by status", %{conn: conn} do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, approval} = Governance.request_approval(rule.id, sid)
      {:ok, _} = Governance.approve(approval.id, "roberto", "ok")

      conn = get(conn, "/api/v1/governance/approvals?status=approved")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["status"] == "approved"))
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/governance/approvals/:id/approve
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/governance/approvals/:id/approve" do
    setup do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, approval} = Governance.request_approval(rule.id, sid)
      %{approval: approval}
    end

    test "approves approval and returns 200", %{conn: conn, approval: approval} do
      params = %{"decided_by" => "roberto", "reason" => "looks good"}

      conn = post(conn, "/api/v1/governance/approvals/#{approval.id}/approve", params)
      assert %{"status" => "approved", "decided_by" => "roberto"} = json_response(conn, 200)
    end

    test "returns 404 for unknown approval id", %{conn: conn} do
      params = %{"decided_by" => "roberto", "reason" => "ok"}
      conn = post(conn, "/api/v1/governance/approvals/#{Ecto.UUID.generate()}/approve", params)
      assert json_response(conn, 404)
    end

    test "returns 422 when already decided", %{conn: conn, approval: approval} do
      params = %{"decided_by" => "roberto", "reason" => "first"}
      post(conn, "/api/v1/governance/approvals/#{approval.id}/approve", params)

      conn2 = build_conn()
      conn2 = post(conn2, "/api/v1/governance/approvals/#{approval.id}/approve", params)
      assert json_response(conn2, 422)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/governance/approvals/:id/reject
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/governance/approvals/:id/reject" do
    setup do
      rule = create_rule!(%{"action" => "require_approval"})
      sid = session_id()
      {:ok, approval} = Governance.request_approval(rule.id, sid)
      %{approval: approval}
    end

    test "rejects approval and returns 200", %{conn: conn, approval: approval} do
      params = %{"decided_by" => "roberto", "reason" => "too risky"}

      conn = post(conn, "/api/v1/governance/approvals/#{approval.id}/reject", params)

      assert %{"status" => "rejected", "decision_reason" => "too risky"} =
               json_response(conn, 200)
    end

    test "returns 404 for unknown approval id", %{conn: conn} do
      params = %{"decided_by" => "roberto", "reason" => "nope"}
      conn = post(conn, "/api/v1/governance/approvals/#{Ecto.UUID.generate()}/reject", params)
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/governance/audit
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/governance/audit" do
    test "returns 200 with empty list initially", %{conn: conn} do
      conn = get(conn, "/api/v1/governance/audit")
      assert %{"data" => _} = json_response(conn, 200)
    end

    test "returns audit entries after evaluate", %{conn: conn} do
      create_rule!(%{"action" => "block", "conditions" => %{"prompt_regex" => "destroy"}})
      Governance.evaluate(%{"prompt" => "destroy everything"})

      conn = get(conn, "/api/v1/governance/audit")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
    end

    test "filters by event_type", %{conn: conn} do
      Governance.evaluate(%{"prompt" => "hello"})

      conn = get(conn, "/api/v1/governance/audit?event_type=policy_bypassed")
      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.all?(data, &(&1["event_type"] == "policy_bypassed"))
    end

    test "filters by since datetime", %{conn: conn} do
      since = DateTime.utc_now() |> DateTime.to_iso8601()
      Governance.evaluate(%{"prompt" => "test after since"})

      conn = get(conn, "/api/v1/governance/audit?since=#{URI.encode(since)}")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) >= 1
    end
  end
end
