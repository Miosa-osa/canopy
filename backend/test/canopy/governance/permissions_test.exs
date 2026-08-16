defmodule Canopy.Governance.PermissionsTest do
  @moduledoc """
  Tests for the 5-scope tool permission grant system.

  Covers:
    - Changeset validation for all 5 scopes
    - Scope semantics: once (consumed on use), today (expires_at auto-set),
      forever (no expiry), never (deny), session (session-scoped)
    - Priority ordering: never > forever > today > session > once
    - cleanup_expired!/0 removes consumed and past-deadline grants
    - check_permission/3 returns :allowed, :denied, :ask correctly
  """

  use Canopy.DataCase, async: true

  alias Canopy.Governance.{Permissions, ToolPermissionGrant}
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp grant(extra \\ %{}) do
    base = %{
      "agent_slug" => "test-agent",
      "tool_name" => "file_write",
      "scope" => "forever"
    }

    Map.merge(base, extra)
  end

  defp insert_grant(extra \\ %{}) do
    {:ok, g} = Permissions.grant_permission(grant(extra))
    g
  end

  # ---------------------------------------------------------------------------
  # Changeset validation
  # ---------------------------------------------------------------------------

  describe "ToolPermissionGrant.changeset/2" do
    test "accepts all valid scopes" do
      for scope <- ~w(once session today forever never) do
        cs = ToolPermissionGrant.changeset(%ToolPermissionGrant{}, grant(%{"scope" => scope}))
        assert cs.valid?, "expected scope #{scope} to be valid, errors: #{inspect(cs.errors)}"
      end
    end

    test "rejects an unknown scope" do
      cs = ToolPermissionGrant.changeset(%ToolPermissionGrant{}, grant(%{"scope" => "whenever"}))
      refute cs.valid?
      assert {:scope, _} = List.keyfind(cs.errors, :scope, 0)
    end

    test "requires agent_slug" do
      cs =
        ToolPermissionGrant.changeset(%ToolPermissionGrant{}, %{
          "tool_name" => "x",
          "scope" => "once"
        })

      refute cs.valid?
      assert {:agent_slug, _} = List.keyfind(cs.errors, :agent_slug, 0)
    end

    test "requires tool_name" do
      cs =
        ToolPermissionGrant.changeset(%ToolPermissionGrant{}, %{
          "agent_slug" => "a",
          "scope" => "once"
        })

      refute cs.valid?
      assert {:tool_name, _} = List.keyfind(cs.errors, :tool_name, 0)
    end
  end

  # ---------------------------------------------------------------------------
  # grant_permission/1
  # ---------------------------------------------------------------------------

  describe "grant_permission/1" do
    test "creates a forever grant with no expires_at" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "forever"}))
      assert g.scope == "forever"
      assert is_nil(g.expires_at)
      assert g.used == false
    end

    test "creates a today grant with expires_at set to end of current UTC day" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "today"}))
      assert g.scope == "today"
      refute is_nil(g.expires_at)
      assert g.expires_at.hour == 23
      assert g.expires_at.minute == 59
      assert g.expires_at.second == 59

      today = Date.utc_today()
      assert g.expires_at.year == today.year
      assert g.expires_at.month == today.month
      assert g.expires_at.day == today.day
    end

    test "creates an once grant with no expires_at and used false" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "once"}))
      assert g.scope == "once"
      assert is_nil(g.expires_at)
      assert g.used == false
    end

    test "creates a never grant" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "never"}))
      assert g.scope == "never"
    end

    test "creates a session grant" do
      session_id = Ecto.UUID.generate()

      {:ok, g} =
        Permissions.grant_permission(grant(%{"scope" => "session", "session_id" => session_id}))

      assert g.scope == "session"
      assert g.session_id == session_id
    end

    test "returns error changeset for invalid attrs" do
      assert {:error, cs} = Permissions.grant_permission(%{"scope" => "bad"})
      refute cs.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # revoke_permission/1
  # ---------------------------------------------------------------------------

  describe "revoke_permission/1" do
    test "deletes an existing grant" do
      g = insert_grant()
      assert {:ok, _} = Permissions.revoke_permission(g.id)
      assert is_nil(Repo.get(ToolPermissionGrant, g.id))
    end

    test "returns not_found for unknown id" do
      assert {:error, :not_found} = Permissions.revoke_permission(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # check_permission/3 — scope semantics
  # ---------------------------------------------------------------------------

  describe "check_permission/3 scope semantics" do
    test "returns :ask when no grants exist" do
      assert :ask == Permissions.check_permission("no-agent", "no-tool")
    end

    test "forever scope allows" do
      insert_grant(%{"scope" => "forever"})
      assert :allowed == Permissions.check_permission("test-agent", "file_write")
    end

    test "never scope denies" do
      insert_grant(%{"scope" => "never"})
      assert :denied == Permissions.check_permission("test-agent", "file_write")
    end

    test "today scope allows when not expired" do
      insert_grant(%{"scope" => "today"})
      assert :allowed == Permissions.check_permission("test-agent", "file_write")
    end

    test "today scope denies when expires_at is in the past" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "today"}))

      past = %{g.expires_at | year: g.expires_at.year - 1}
      g |> ToolPermissionGrant.changeset(%{expires_at: past}) |> Repo.update!()

      assert :ask == Permissions.check_permission("test-agent", "file_write")
    end

    test "session scope allows when session_id matches" do
      sid = Ecto.UUID.generate()
      insert_grant(%{"scope" => "session", "session_id" => sid})
      assert :allowed == Permissions.check_permission("test-agent", "file_write", session_id: sid)
    end

    test "session scope returns :ask when session_id does not match" do
      sid = Ecto.UUID.generate()
      insert_grant(%{"scope" => "session", "session_id" => sid})

      assert :ask ==
               Permissions.check_permission("test-agent", "file_write",
                 session_id: Ecto.UUID.generate()
               )
    end

    test "once scope allows and marks grant as used" do
      g = insert_grant(%{"scope" => "once"})
      assert :allowed == Permissions.check_permission("test-agent", "file_write")

      updated = Repo.get!(ToolPermissionGrant, g.id)
      assert updated.used == true
    end

    test "once scope not reusable after consumed" do
      insert_grant(%{"scope" => "once"})
      assert :allowed == Permissions.check_permission("test-agent", "file_write")
      assert :ask == Permissions.check_permission("test-agent", "file_write")
    end
  end

  # ---------------------------------------------------------------------------
  # check_permission/3 — priority ordering
  # ---------------------------------------------------------------------------

  describe "check_permission/3 priority ordering" do
    test "never overrides forever" do
      insert_grant(%{"scope" => "never"})
      insert_grant(%{"scope" => "forever"})
      assert :denied == Permissions.check_permission("test-agent", "file_write")
    end

    test "never overrides today" do
      insert_grant(%{"scope" => "never"})
      insert_grant(%{"scope" => "today"})
      assert :denied == Permissions.check_permission("test-agent", "file_write")
    end

    test "never overrides session" do
      sid = Ecto.UUID.generate()
      insert_grant(%{"scope" => "never"})
      insert_grant(%{"scope" => "session", "session_id" => sid})
      assert :denied == Permissions.check_permission("test-agent", "file_write", session_id: sid)
    end

    test "never overrides once" do
      insert_grant(%{"scope" => "never"})
      insert_grant(%{"scope" => "once"})
      assert :denied == Permissions.check_permission("test-agent", "file_write")
    end

    test "forever overrides today" do
      insert_grant(%{"scope" => "forever"})
      insert_grant(%{"scope" => "today"})
      # Both allow — forever should be the decisive one (but result is still :allowed)
      assert :allowed == Permissions.check_permission("test-agent", "file_write")
    end
  end

  # ---------------------------------------------------------------------------
  # list_grants/1
  # ---------------------------------------------------------------------------

  describe "list_grants/1" do
    test "returns all grants without filters" do
      insert_grant(%{"scope" => "forever"})
      insert_grant(%{"agent_slug" => "other-agent", "scope" => "never"})
      grants = Permissions.list_grants()
      assert length(grants) >= 2
    end

    test "filters by agent_slug" do
      insert_grant(%{"scope" => "forever"})
      insert_grant(%{"agent_slug" => "other-agent", "scope" => "never"})
      grants = Permissions.list_grants(agent_slug: "test-agent")
      assert Enum.all?(grants, &(&1.agent_slug == "test-agent"))
    end

    test "filters by tool_name" do
      insert_grant(%{"scope" => "forever"})
      insert_grant(%{"tool_name" => "shell_exec", "scope" => "forever"})
      grants = Permissions.list_grants(tool_name: "file_write")
      assert Enum.all?(grants, &(&1.tool_name == "file_write"))
    end

    test "filters by scope" do
      insert_grant(%{"scope" => "forever"})
      insert_grant(%{"scope" => "never"})
      grants = Permissions.list_grants(scope: "never")
      assert Enum.all?(grants, &(&1.scope == "never"))
    end

    test "filters by workspace_slug" do
      insert_grant(%{"scope" => "forever", "workspace_slug" => "ws-a"})
      insert_grant(%{"scope" => "forever", "workspace_slug" => "ws-b"})
      grants = Permissions.list_grants(workspace_slug: "ws-a")
      assert Enum.all?(grants, &(&1.workspace_slug == "ws-a"))
    end
  end

  # ---------------------------------------------------------------------------
  # cleanup_expired!/0
  # ---------------------------------------------------------------------------

  describe "cleanup_expired!/0" do
    test "removes consumed once grants" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "once"}))
      g |> ToolPermissionGrant.changeset(%{used: true}) |> Repo.update!()

      Permissions.cleanup_expired!()
      assert is_nil(Repo.get(ToolPermissionGrant, g.id))
    end

    test "removes expired today grants" do
      {:ok, g} = Permissions.grant_permission(grant(%{"scope" => "today"}))
      past = %{g.expires_at | year: g.expires_at.year - 1}
      g |> ToolPermissionGrant.changeset(%{expires_at: past}) |> Repo.update!()

      Permissions.cleanup_expired!()
      assert is_nil(Repo.get(ToolPermissionGrant, g.id))
    end

    test "preserves active forever grants" do
      g = insert_grant(%{"scope" => "forever"})
      Permissions.cleanup_expired!()
      assert Repo.get(ToolPermissionGrant, g.id)
    end

    test "preserves unconsumed once grants" do
      g = insert_grant(%{"scope" => "once"})
      Permissions.cleanup_expired!()
      assert Repo.get(ToolPermissionGrant, g.id)
    end

    test "returns count of removed grants" do
      {:ok, g1} = Permissions.grant_permission(grant(%{"scope" => "once"}))
      g1 |> ToolPermissionGrant.changeset(%{used: true}) |> Repo.update!()

      {:ok, g2} = Permissions.grant_permission(grant(%{"scope" => "today"}))
      past = %{g2.expires_at | year: g2.expires_at.year - 1}
      g2 |> ToolPermissionGrant.changeset(%{expires_at: past}) |> Repo.update!()

      {count, nil} = Permissions.cleanup_expired!()
      assert count >= 2
    end
  end
end
