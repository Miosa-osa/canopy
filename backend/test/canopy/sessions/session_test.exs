defmodule Canopy.Sessions.SessionTest do
  @moduledoc """
  Changeset + schema tests for Canopy.Sessions.Session.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Sessions.Session

  describe "changeset/2 — valid attrs" do
    test "creates a valid changeset with minimum required fields" do
      attrs = %{runtime_type: "claude-local", cwd: "/home/user/project"}
      cs = Session.changeset(%Session{}, attrs)
      assert cs.valid?
    end

    test "defaults status to pending" do
      attrs = %{runtime_type: "claude-local", cwd: "/tmp"}
      cs = Session.changeset(%Session{}, attrs)
      data = Ecto.Changeset.apply_changes(cs)
      assert data.status == "pending"
    end

    test "defaults cost and token counts to zero" do
      attrs = %{runtime_type: "claude-local", cwd: "/tmp"}
      cs = Session.changeset(%Session{}, attrs)
      data = Ecto.Changeset.apply_changes(cs)
      assert Decimal.equal?(data.cost_usd, Decimal.new("0"))
      assert data.input_tokens == 0
      assert data.output_tokens == 0
      assert data.cache_read_tokens == 0
      assert data.cache_write_tokens == 0
    end

    test "accepts all optional fields" do
      attrs = %{
        runtime_type: "claude-local",
        cwd: "/tmp",
        model_id: "claude-sonnet-4-6",
        agent_slug: "senior-dev",
        workspace_slug: "my-project",
        status: "running",
        prompt: "Write a GenServer",
        prompt_bundle_key: String.duplicate("a", 64),
        wake_reason: "user",
        sequence_number: 2,
        external_session_id: "sess_abc123"
      }

      cs = Session.changeset(%Session{}, attrs)
      assert cs.valid?
    end
  end

  describe "changeset/2 — validation errors" do
    test "requires runtime_type" do
      cs = Session.changeset(%Session{}, %{cwd: "/tmp"})
      assert %{runtime_type: ["can't be blank"]} = errors_on(cs)
    end

    test "requires cwd" do
      cs = Session.changeset(%Session{}, %{runtime_type: "claude-local"})
      assert %{cwd: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects invalid status" do
      cs = Session.changeset(%Session{}, %{runtime_type: "x", cwd: "/", status: "bogus"})
      assert %{status: [_msg]} = errors_on(cs)
    end

    test "rejects prompt_bundle_key not 64 chars" do
      cs =
        Session.changeset(%Session{}, %{
          runtime_type: "x",
          cwd: "/",
          prompt_bundle_key: "tooshort"
        })

      assert %{prompt_bundle_key: [_msg]} = errors_on(cs)
    end
  end

  describe "parent-child chain" do
    test "child session references parent" do
      {:ok, parent} =
        Canopy.Repo.insert(
          Session.changeset(%Session{}, %{runtime_type: "claude-local", cwd: "/tmp"})
        )

      {:ok, child} =
        Canopy.Repo.insert(
          Session.changeset(%Session{}, %{
            runtime_type: "claude-local",
            cwd: "/tmp",
            parent_session_id: parent.id,
            sequence_number: 1
          })
        )

      assert child.parent_session_id == parent.id
      assert child.sequence_number == 1
    end
  end

  describe "status_changeset/2" do
    test "transitions status to running" do
      {:ok, session} =
        Canopy.Repo.insert(
          Session.changeset(%Session{}, %{runtime_type: "claude-local", cwd: "/tmp"})
        )

      cs = Session.status_changeset(session, %{status: "running", started_at: DateTime.utc_now()})
      assert cs.valid?
    end

    test "requires status in status_changeset" do
      # Force status to nil via explicit cast to verify validation fires
      session = %Session{}
      cs = Session.status_changeset(session, %{status: nil})
      assert %{status: ["can't be blank"]} = errors_on(cs)
    end
  end
end
