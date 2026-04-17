defmodule Canopy.SessionsTest do
  @moduledoc """
  Integration tests for the Canopy.Sessions context module.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Sessions

  defp valid_attrs(overrides \\ %{}) do
    Map.merge(%{runtime_type: "claude-local", cwd: "/tmp/project"}, overrides)
  end

  describe "create/1" do
    test "creates a session with required attrs" do
      assert {:ok, session} = Sessions.create(valid_attrs())
      assert session.id != nil
      assert session.status == "pending"
      assert session.runtime_type == "claude-local"
    end

    test "returns changeset error on missing required fields" do
      assert {:error, cs} = Sessions.create(%{})
      assert %{runtime_type: ["can't be blank"]} = errors_on(cs)
    end

    test "assigns optional fields" do
      attrs = valid_attrs(%{agent_slug: "senior-dev", model_id: "claude-sonnet-4-6"})
      {:ok, session} = Sessions.create(attrs)
      assert session.agent_slug == "senior-dev"
      assert session.model_id == "claude-sonnet-4-6"
    end
  end

  describe "get!/1" do
    test "returns session by id" do
      {:ok, created} = Sessions.create(valid_attrs())
      fetched = Sessions.get!(created.id)
      assert fetched.id == created.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn ->
        Sessions.get!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_by_status/1" do
    test "returns sessions matching the status" do
      {:ok, _s1} = Sessions.create(valid_attrs())
      {:ok, s2} = Sessions.create(valid_attrs())
      {:ok, running} = Sessions.update_status(s2.id, "running")

      {:ok, pending} = Sessions.list_by_status("pending")
      {:ok, running_list} = Sessions.list_by_status("running")

      assert Enum.any?(pending, &(&1.status == "pending"))
      assert Enum.any?(running_list, &(&1.id == running.id))
    end
  end

  describe "update_status/2" do
    test "transitions status" do
      {:ok, session} = Sessions.create(valid_attrs())
      {:ok, updated} = Sessions.update_status(session.id, "running")
      assert updated.status == "running"
    end

    test "returns error for invalid status" do
      {:ok, session} = Sessions.create(valid_attrs())
      assert {:error, cs} = Sessions.update_status(session.id, "invalid")
      assert %{status: [_msg]} = errors_on(cs)
    end

    test "returns error for unknown id" do
      assert {:error, :not_found} = Sessions.update_status(Ecto.UUID.generate(), "running")
    end
  end

  describe "add_message/2" do
    test "appends a message to the session" do
      {:ok, session} = Sessions.create(valid_attrs())

      msg_attrs = %{
        sequence: 0,
        kind: "assistant",
        content: %{"text" => "Hello!"},
        emitted_at: DateTime.utc_now()
      }

      assert {:ok, msg} = Sessions.add_message(session.id, msg_attrs)
      assert msg.session_id == session.id
      assert msg.sequence == 0
    end

    test "rejects duplicate sequence" do
      {:ok, session} = Sessions.create(valid_attrs())

      attrs = %{sequence: 0, kind: "user", content: %{}, emitted_at: DateTime.utc_now()}
      {:ok, _first_msg} = Sessions.add_message(session.id, attrs)
      {:error, cs} = Sessions.add_message(session.id, attrs)
      assert %{sequence: ["has already been taken"]} = errors_on(cs)
    end
  end

  describe "list_messages/1" do
    test "returns messages ordered by sequence" do
      {:ok, session} = Sessions.create(valid_attrs())
      now = DateTime.utc_now()

      for seq <- [2, 0, 1] do
        Sessions.add_message(session.id, %{
          sequence: seq,
          kind: "assistant",
          content: %{},
          emitted_at: now
        })
      end

      {:ok, msgs} = Sessions.list_messages(session.id)
      sequences = Enum.map(msgs, & &1.sequence)
      assert sequences == [0, 1, 2]
    end
  end

  describe "finalize/2" do
    test "sets status to completed and records completed_at" do
      {:ok, session} = Sessions.create(valid_attrs())
      {:ok, updated} = Sessions.update_status(session.id, "running")

      cost = Decimal.new("0.001234")
      {:ok, final} = Sessions.finalize(updated.id, %{cost_usd: cost, input_tokens: 100})

      assert final.status == "completed"
      assert final.completed_at != nil
      assert Decimal.equal?(final.cost_usd, cost)
      assert final.input_tokens == 100
    end

    test "returns error for unknown session" do
      assert {:error, :not_found} = Sessions.finalize(Ecto.UUID.generate(), %{})
    end
  end
end
