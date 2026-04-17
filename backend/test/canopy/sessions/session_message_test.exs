defmodule Canopy.Sessions.SessionMessageTest do
  @moduledoc """
  Changeset + schema tests for Canopy.Sessions.SessionMessage.
  Verifies append-only semantics and sequence uniqueness.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Sessions.{Session, SessionMessage}

  defp create_session! do
    {:ok, session} =
      Canopy.Repo.insert(
        Session.changeset(%Session{}, %{runtime_type: "claude-local", cwd: "/tmp"})
      )

    session
  end

  describe "changeset/2 — valid attrs" do
    test "creates a valid message changeset" do
      session = create_session!()

      attrs = %{
        session_id: session.id,
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "Hello"},
        emitted_at: DateTime.utc_now()
      }

      cs = SessionMessage.changeset(%SessionMessage{}, attrs)
      assert cs.valid?
    end

    test "accepts all valid kind values" do
      session = create_session!()
      kinds = ~w(assistant thinking tool_call tool_result diff stderr stdout system user)

      for {kind, seq} <- Enum.with_index(kinds) do
        attrs = %{
          session_id: session.id,
          sequence: seq,
          kind: kind,
          content: %{"type" => kind},
          emitted_at: DateTime.utc_now()
        }

        cs = SessionMessage.changeset(%SessionMessage{}, attrs)
        assert cs.valid?, "expected valid for kind=#{kind}, errors: #{inspect(cs.errors)}"
      end
    end

    test "accepts optional tool_call_id" do
      session = create_session!()

      attrs = %{
        session_id: session.id,
        sequence: 0,
        kind: "tool_call",
        content: %{"tool" => "bash"},
        tool_call_id: "call_xyz",
        emitted_at: DateTime.utc_now()
      }

      cs = SessionMessage.changeset(%SessionMessage{}, attrs)
      assert cs.valid?
    end
  end

  describe "changeset/2 — validation errors" do
    test "requires session_id" do
      cs =
        SessionMessage.changeset(%SessionMessage{}, %{
          sequence: 0,
          kind: "assistant",
          content: %{},
          emitted_at: DateTime.utc_now()
        })

      assert %{session_id: ["can't be blank"]} = errors_on(cs)
    end

    test "requires kind" do
      session = create_session!()

      cs =
        SessionMessage.changeset(%SessionMessage{}, %{
          session_id: session.id,
          sequence: 0,
          content: %{},
          emitted_at: DateTime.utc_now()
        })

      assert %{kind: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects invalid kind" do
      session = create_session!()

      cs =
        SessionMessage.changeset(%SessionMessage{}, %{
          session_id: session.id,
          sequence: 0,
          kind: "invalid_kind",
          content: %{},
          emitted_at: DateTime.utc_now()
        })

      assert %{kind: [_msg]} = errors_on(cs)
    end

    test "requires content" do
      session = create_session!()

      cs =
        SessionMessage.changeset(%SessionMessage{}, %{
          session_id: session.id,
          sequence: 0,
          kind: "assistant",
          emitted_at: DateTime.utc_now()
        })

      assert %{content: ["can't be blank"]} = errors_on(cs)
    end
  end

  describe "database constraints — append-only" do
    test "enforces unique (session_id, sequence)" do
      session = create_session!()
      now = DateTime.utc_now()

      attrs = %{
        session_id: session.id,
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "hi"},
        emitted_at: now
      }

      {:ok, _first} = Canopy.Repo.insert(SessionMessage.changeset(%SessionMessage{}, attrs))

      {:error, cs} = Canopy.Repo.insert(SessionMessage.changeset(%SessionMessage{}, attrs))
      assert %{sequence: ["has already been taken"]} = errors_on(cs)
    end

    test "messages from different sessions can share sequence numbers" do
      s1 = create_session!()
      s2 = create_session!()
      now = DateTime.utc_now()

      {:ok, _s1_msg} =
        Canopy.Repo.insert(
          SessionMessage.changeset(%SessionMessage{}, %{
            session_id: s1.id,
            sequence: 0,
            kind: "assistant",
            content: %{},
            emitted_at: now
          })
        )

      {:ok, _s2_msg} =
        Canopy.Repo.insert(
          SessionMessage.changeset(%SessionMessage{}, %{
            session_id: s2.id,
            sequence: 0,
            kind: "assistant",
            content: %{},
            emitted_at: now
          })
        )
    end

    test "schema has no updated_at (append-only)" do
      fields = SessionMessage.__schema__(:fields)
      refute :updated_at in fields
    end
  end
end
