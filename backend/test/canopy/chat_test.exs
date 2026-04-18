defmodule Canopy.ChatTest do
  @moduledoc """
  Integration tests for the Canopy.Chat context.

  These tests exercise the full chat thread lifecycle: create, continue,
  list, rename, pin, archive, delete, and transcript concatenation across
  multi-session threads.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Chat
  alias Canopy.Chat.Thread
  alias Canopy.Repo
  alias Canopy.Sessions

  @valid_attrs %{
    runtime_type: "claude-local",
    title: "Test Thread",
    agent_slug: "senior-dev"
  }

  # ---------------------------------------------------------------------------
  # create_thread/1
  # ---------------------------------------------------------------------------

  describe "create_thread/1" do
    test "creates a thread and initial session" do
      assert {:ok, thread} = Chat.create_thread(@valid_attrs)

      assert thread.id != nil
      assert thread.title == "Test Thread"
      assert thread.agent_slug == "senior-dev"
      assert thread.runtime_type == "claude-local"
      assert thread.last_session_id != nil
      assert thread.last_message_at != nil
    end

    test "the linked session is inserted via Sessions.create/1" do
      assert {:ok, thread} = Chat.create_thread(@valid_attrs)

      assert {:ok, session} = Sessions.get(thread.last_session_id)
      assert session.runtime_type == "claude-local"
      assert session.agent_slug == "senior-dev"
    end

    test "propagates agent_slug and workspace_slug to session" do
      attrs =
        Map.merge(@valid_attrs, %{workspace_slug: "my-workspace", agent_slug: "code-reviewer"})

      assert {:ok, thread} = Chat.create_thread(attrs)
      assert {:ok, session} = Sessions.get(thread.last_session_id)
      assert session.workspace_slug == "my-workspace"
      assert session.agent_slug == "code-reviewer"
    end

    test "returns changeset error on missing runtime_type" do
      assert {:error, changeset} = Chat.create_thread(%{})
      assert %{runtime_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "creates thread without optional title" do
      assert {:ok, thread} = Chat.create_thread(%{runtime_type: "claude-local"})
      assert thread.title == nil
    end
  end

  # ---------------------------------------------------------------------------
  # continue_thread/2
  # ---------------------------------------------------------------------------

  describe "continue_thread/2" do
    test "creates a new session and updates last_session_id" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)

      assert {:ok, %{thread: updated_thread, session: new_session}} =
               Chat.continue_thread(thread.id, "Follow-up question")

      assert new_session.id != thread.last_session_id
      assert updated_thread.last_session_id == new_session.id
    end

    test "sets parent_session_id on the new session pointing to prior session" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      first_session_id = thread.last_session_id

      {:ok, %{session: new_session}} = Chat.continue_thread(thread.id, "Next turn")

      assert new_session.parent_session_id == first_session_id
    end

    test "updates last_message_at on the thread" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      original_ts = thread.last_message_at

      :timer.sleep(1000)

      {:ok, %{thread: updated}} = Chat.continue_thread(thread.id, "Another message")

      assert DateTime.compare(updated.last_message_at, original_ts) == :gt
    end

    test "returns :not_found for non-existent thread" do
      assert {:error, :not_found} = Chat.continue_thread(Ecto.UUID.generate(), "hi")
    end

    test "supports multiple continuations building a parent_session_id chain" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      session0_id = thread.last_session_id

      {:ok, %{session: s1}} = Chat.continue_thread(thread.id, "turn 2")
      {:ok, %{session: s2}} = Chat.continue_thread(thread.id, "turn 3")

      assert s1.parent_session_id == session0_id
      assert s2.parent_session_id == s1.id
    end
  end

  # ---------------------------------------------------------------------------
  # list_threads/1
  # ---------------------------------------------------------------------------

  describe "list_threads/1" do
    test "returns all active threads without filters" do
      {:ok, t1} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, t2} = Chat.create_thread(%{runtime_type: "claude-local"})

      threads = Chat.list_threads()
      ids = Enum.map(threads, & &1.id)

      assert t1.id in ids
      assert t2.id in ids
    end

    test "filters by user_id" do
      user_id = Ecto.UUID.generate()
      {:ok, mine} = Chat.create_thread(%{runtime_type: "claude-local", user_id: user_id})
      {:ok, _other} = Chat.create_thread(%{runtime_type: "claude-local"})

      threads = Chat.list_threads(%{user_id: user_id})
      assert length(threads) == 1
      assert hd(threads).id == mine.id
    end

    test "filters by agent_slug" do
      {:ok, t1} = Chat.create_thread(%{runtime_type: "claude-local", agent_slug: "coder"})
      {:ok, _t2} = Chat.create_thread(%{runtime_type: "claude-local", agent_slug: "reviewer"})

      threads = Chat.list_threads(%{agent_slug: "coder"})
      assert length(threads) == 1
      assert hd(threads).id == t1.id
    end

    test "excludes archived threads by default" do
      {:ok, active} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, archived_thread} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, _} = Chat.archive_thread(archived_thread.id)

      threads = Chat.list_threads()
      ids = Enum.map(threads, & &1.id)

      assert active.id in ids
      refute archived_thread.id in ids
    end

    test "returns archived threads when archived: true" do
      {:ok, active} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, archived_thread} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, _} = Chat.archive_thread(archived_thread.id)

      threads = Chat.list_threads(%{archived: true})
      ids = Enum.map(threads, & &1.id)

      assert archived_thread.id in ids
      refute active.id in ids
    end

    test "filters pinned threads" do
      {:ok, t1} = Chat.create_thread(%{runtime_type: "claude-local"})
      {:ok, t2} = Chat.create_thread(%{runtime_type: "claude-local"})
      Chat.pin_thread(t1.id)

      threads = Chat.list_threads(%{pinned: true})
      ids = Enum.map(threads, & &1.id)

      assert t1.id in ids
      refute t2.id in ids
    end
  end

  # ---------------------------------------------------------------------------
  # get_thread/1
  # ---------------------------------------------------------------------------

  describe "get_thread/1" do
    test "loads thread by id" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      {:ok, fetched} = Chat.get_thread(thread.id)

      assert fetched.id == thread.id
      assert fetched.last_session_id == thread.last_session_id
    end

    test "returns :not_found for missing thread" do
      assert {:error, :not_found} = Chat.get_thread(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # rename_thread/2
  # ---------------------------------------------------------------------------

  describe "rename_thread/2" do
    test "updates the title" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      {:ok, renamed} = Chat.rename_thread(thread.id, "New Title")
      assert renamed.title == "New Title"
    end

    test "returns :not_found for unknown thread" do
      assert {:error, :not_found} = Chat.rename_thread(Ecto.UUID.generate(), "x")
    end
  end

  # ---------------------------------------------------------------------------
  # pin / unpin
  # ---------------------------------------------------------------------------

  describe "pin_thread/1 and unpin_thread/1" do
    test "pins and unpins a thread" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      assert thread.pinned == false

      {:ok, pinned} = Chat.pin_thread(thread.id)
      assert pinned.pinned == true

      {:ok, unpinned} = Chat.unpin_thread(thread.id)
      assert unpinned.pinned == false
    end
  end

  # ---------------------------------------------------------------------------
  # archive / unarchive
  # ---------------------------------------------------------------------------

  describe "archive_thread/1 and unarchive_thread/1" do
    test "sets and clears archived_at" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      assert thread.archived_at == nil

      {:ok, archived} = Chat.archive_thread(thread.id)
      assert archived.archived_at != nil

      {:ok, restored} = Chat.unarchive_thread(thread.id)
      assert restored.archived_at == nil
    end
  end

  # ---------------------------------------------------------------------------
  # delete_thread/1
  # ---------------------------------------------------------------------------

  describe "delete_thread/1" do
    test "removes the thread and preserves sessions" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      session_id = thread.last_session_id

      assert :ok = Chat.delete_thread(thread.id)
      assert Repo.get(Thread, thread.id) == nil
      # Sessions are preserved
      assert {:ok, _session} = Sessions.get(session_id)
    end

    test "returns :not_found for missing thread" do
      assert {:error, :not_found} = Chat.delete_thread(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # thread_transcript/1 — multi-session concatenation
  # ---------------------------------------------------------------------------

  describe "thread_transcript/1" do
    test "returns empty list for a thread with no messages" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      {:ok, messages} = Chat.thread_transcript(thread.id)
      assert messages == []
    end

    test "concatenates messages from multiple sessions in session order" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)
      session1_id = thread.last_session_id

      {:ok, %{session: session2}} = Chat.continue_thread(thread.id, "turn 2")

      # Insert messages into each session
      {:ok, m1} =
        Sessions.add_message(session1_id, %{
          sequence: 0,
          kind: "user",
          content: %{"text" => "hello session 1"},
          emitted_at: DateTime.utc_now()
        })

      {:ok, m2} =
        Sessions.add_message(session2.id, %{
          sequence: 0,
          kind: "user",
          content: %{"text" => "hello session 2"},
          emitted_at: DateTime.utc_now()
        })

      {:ok, messages} = Chat.thread_transcript(thread.id)

      assert length(messages) == 2
      [first, second] = messages
      assert first.id == m1.id
      assert second.id == m2.id
    end

    test "returns :not_found for missing thread" do
      assert {:error, :not_found} = Chat.thread_transcript(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # export_thread/2
  # ---------------------------------------------------------------------------

  describe "export_thread/2" do
    test "returns markdown string with thread header" do
      {:ok, thread} = Chat.create_thread(Map.put(@valid_attrs, :title, "My Export Thread"))
      {:ok, markdown} = Chat.export_thread(thread.id)

      assert String.contains?(markdown, "# My Export Thread")
      assert String.contains?(markdown, "**Agent:** senior-dev")
    end

    test "returns :not_found for missing thread" do
      assert {:error, :not_found} = Chat.export_thread(Ecto.UUID.generate())
    end

    test "renders user and assistant messages" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)

      Sessions.add_message(thread.last_session_id, %{
        sequence: 0,
        kind: "user",
        content: %{"text" => "What is Elixir?"},
        emitted_at: DateTime.utc_now()
      })

      Sessions.add_message(thread.last_session_id, %{
        sequence: 1,
        kind: "assistant",
        content: %{"text" => "Elixir is a dynamic, functional language."},
        emitted_at: DateTime.utc_now()
      })

      {:ok, markdown} = Chat.export_thread(thread.id)

      assert String.contains?(markdown, "### You")
      assert String.contains?(markdown, "What is Elixir?")
      assert String.contains?(markdown, "### Assistant")
      assert String.contains?(markdown, "Elixir is a dynamic, functional language.")
    end

    test "skips thinking blocks by default and includes them with include_thinking" do
      {:ok, thread} = Chat.create_thread(@valid_attrs)

      Sessions.add_message(thread.last_session_id, %{
        sequence: 0,
        kind: "thinking",
        content: %{"text" => "Let me think..."},
        emitted_at: DateTime.utc_now()
      })

      {:ok, without_thinking} = Chat.export_thread(thread.id)
      refute String.contains?(without_thinking, "Let me think...")

      {:ok, with_thinking} = Chat.export_thread(thread.id, include_thinking: true)
      assert String.contains?(with_thinking, "Let me think...")
    end
  end
end
