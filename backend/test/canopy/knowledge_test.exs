defmodule Canopy.KnowledgeTest do
  @moduledoc """
  Context tests for Canopy.Knowledge.

  Covers: create_base, add_file_to_base (with chunker integration), list_chunks,
  search (assert ≤ limit results), assign/unassign, rebuild_index, delete_base.

  The embedding stub returns zero vectors — search ordering is by insertion order.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Knowledge
  alias Canopy.Knowledge.{KbAgentAssignment, KbChunk, KnowledgeBase}
  alias Canopy.Repo

  # ---------------------------------------------------------------------------
  # create_base/1
  # ---------------------------------------------------------------------------

  describe "create_base/1" do
    test "creates a knowledge base with defaults" do
      assert {:ok, %KnowledgeBase{} = kb} =
               Knowledge.create_base(%{slug: "test-kb", name: "Test KB"})

      assert kb.slug == "test-kb"
      assert kb.name == "Test KB"
      assert kb.embedding_model == "text-embedding-3-small"
      assert kb.dimensions == 1536
      assert kb.chunk_size == 800
      assert kb.chunk_overlap == 100
      assert is_nil(kb.archived_at)
    end

    test "creates a knowledge base with custom config" do
      attrs = %{
        slug: "custom-kb",
        name: "Custom KB",
        description: "My custom KB",
        workspace_slug: "my-workspace",
        chunk_size: 400,
        chunk_overlap: 50
      }

      assert {:ok, kb} = Knowledge.create_base(attrs)
      assert kb.workspace_slug == "my-workspace"
      assert kb.chunk_size == 400
      assert kb.chunk_overlap == 50
    end

    test "returns error for duplicate slug" do
      insert(:knowledge_base, slug: "dup-kb")
      assert {:error, changeset} = Knowledge.create_base(%{slug: "dup-kb", name: "Dup"})
      assert %{slug: [_]} = errors_on(changeset)
    end

    test "returns error for missing required fields" do
      assert {:error, changeset} = Knowledge.create_base(%{})
      assert %{slug: [_], name: [_]} = errors_on(changeset)
    end

    test "returns error for invalid slug format" do
      assert {:error, changeset} =
               Knowledge.create_base(%{slug: "Invalid Slug!", name: "Bad"})

      assert %{slug: [_]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # list_bases/1
  # ---------------------------------------------------------------------------

  describe "list_bases/1" do
    test "returns empty list when no KBs exist" do
      assert {:ok, []} = Knowledge.list_bases()
    end

    test "returns all active KBs ordered by name" do
      insert(:knowledge_base, slug: "z-kb", name: "Zebra KB")
      insert(:knowledge_base, slug: "a-kb", name: "Alpha KB")
      assert {:ok, [first, second]} = Knowledge.list_bases()
      assert first.name == "Alpha KB"
      assert second.name == "Zebra KB"
    end

    test "excludes archived KBs by default" do
      insert(:knowledge_base, slug: "active-kb")
      insert(:knowledge_base, slug: "archived-kb", archived_at: DateTime.utc_now())
      assert {:ok, kbs} = Knowledge.list_bases()
      slugs = Enum.map(kbs, & &1.slug)
      assert "active-kb" in slugs
      refute "archived-kb" in slugs
    end

    test "includes archived KBs when archived: true" do
      insert(:knowledge_base, slug: "arc-incl-active")
      insert(:knowledge_base, slug: "arc-incl-archived", archived_at: DateTime.utc_now())
      assert {:ok, kbs} = Knowledge.list_bases(archived: true)
      slugs = Enum.map(kbs, & &1.slug)
      assert "arc-incl-active" in slugs
      assert "arc-incl-archived" in slugs
    end

    test "filters by workspace_slug" do
      insert(:knowledge_base, slug: "ws-kb-1", workspace_slug: "workspace-a")
      insert(:knowledge_base, slug: "ws-kb-2", workspace_slug: "workspace-b")
      assert {:ok, kbs} = Knowledge.list_bases(workspace: "workspace-a")
      slugs = Enum.map(kbs, & &1.slug)
      assert "ws-kb-1" in slugs
      refute "ws-kb-2" in slugs
    end
  end

  # ---------------------------------------------------------------------------
  # get_base/1
  # ---------------------------------------------------------------------------

  describe "get_base/1" do
    test "returns KB by slug" do
      insert(:knowledge_base, slug: "findable-kb")
      assert {:ok, %KnowledgeBase{slug: "findable-kb"}} = Knowledge.get_base("findable-kb")
    end

    test "returns error for unknown slug" do
      assert {:error, :not_found} = Knowledge.get_base("nonexistent")
    end
  end

  # ---------------------------------------------------------------------------
  # delete_base/1 (soft archive)
  # ---------------------------------------------------------------------------

  describe "delete_base/1" do
    test "sets archived_at on a KB" do
      kb = insert(:knowledge_base, slug: "to-archive-kb")
      assert {:ok, archived} = Knowledge.delete_base(kb.id)
      assert archived.archived_at != nil
    end

    test "returns error for unknown id" do
      assert {:error, :not_found} = Knowledge.delete_base(Ecto.UUID.generate())
    end
  end

  # ---------------------------------------------------------------------------
  # add_file_to_base/3 with chunker integration
  # ---------------------------------------------------------------------------

  describe "add_file_to_base/3 — direct path upload" do
    test "chunks and inserts content from a direct path" do
      kb = insert(:knowledge_base, slug: "add-file-kb", chunk_size: 50, chunk_overlap: 5)

      content =
        Enum.map_join(1..20, "\n\n", fn i ->
          "Paragraph #{i}: " <> String.duplicate("word ", 20)
        end)

      assert {:ok, chunk_count} = Knowledge.add_file_to_base(kb.id, {:path, "test.txt", content})
      assert chunk_count >= 1

      assert {:ok, chunks} = Knowledge.list_chunks(kb.id)
      assert length(chunks) == chunk_count
      assert Enum.all?(chunks, fn c -> c.source_path == "test.txt" end)
    end

    test "sets correct source_path and nil source_file_id for direct uploads" do
      kb = insert(:knowledge_base, slug: "path-source-kb")
      assert {:ok, _} = Knowledge.add_file_to_base(kb.id, {:path, "upload.txt", "Hello world."})

      [chunk] = Repo.all(Ecto.Query.from(c in KbChunk, where: c.kb_id == ^kb.id))
      assert chunk.source_path == "upload.txt"
      assert is_nil(chunk.source_file_id)
    end

    test "upserts on re-add (same source_path + chunk_index)" do
      kb = insert(:knowledge_base, slug: "upsert-kb")
      content = "Some content for dedup testing."

      assert {:ok, c1} = Knowledge.add_file_to_base(kb.id, {:path, "upsert.txt", content})
      assert {:ok, c2} = Knowledge.add_file_to_base(kb.id, {:path, "upsert.txt", content})

      chunks = Repo.all(Ecto.Query.from(c in KbChunk, where: c.kb_id == ^kb.id))
      assert length(chunks) == c1
      assert c1 == c2
    end
  end

  # ---------------------------------------------------------------------------
  # list_chunks/3
  # ---------------------------------------------------------------------------

  describe "list_chunks/3" do
    test "returns chunks ordered by source_path + chunk_index" do
      kb = insert(:knowledge_base, slug: "list-chunks-kb")
      # Insert chunks in reverse order
      insert(:kb_chunk, knowledge_base: kb, source_path: "b.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb, source_path: "a.txt", chunk_index: 1)
      insert(:kb_chunk, knowledge_base: kb, source_path: "a.txt", chunk_index: 0)

      assert {:ok, chunks} = Knowledge.list_chunks(kb.id)
      assert length(chunks) == 3
      [first, second, third] = chunks
      assert first.source_path == "a.txt" and first.chunk_index == 0
      assert second.source_path == "a.txt" and second.chunk_index == 1
      assert third.source_path == "b.txt"
    end

    test "respects limit and offset" do
      kb = insert(:knowledge_base, slug: "paginate-kb")

      Enum.each(0..4, fn i ->
        insert(:kb_chunk, knowledge_base: kb, source_path: "f.txt", chunk_index: i)
      end)

      assert {:ok, page1} = Knowledge.list_chunks(kb.id, 2, 0)
      assert {:ok, page2} = Knowledge.list_chunks(kb.id, 2, 2)

      assert length(page1) == 2
      assert length(page2) == 2
      assert Enum.map(page1, & &1.chunk_index) != Enum.map(page2, & &1.chunk_index)
    end
  end

  # ---------------------------------------------------------------------------
  # search/3
  # ---------------------------------------------------------------------------

  describe "search/3" do
    test "returns at most limit chunks" do
      kb = insert(:knowledge_base, slug: "search-kb")

      Enum.each(0..9, fn i ->
        insert(:kb_chunk, knowledge_base: kb, source_path: "s.txt", chunk_index: i)
      end)

      assert {:ok, results} = Knowledge.search(kb.id, "test query", 5)
      assert length(results) <= 5
    end

    test "returns empty list when KB has no chunks" do
      kb = insert(:knowledge_base, slug: "empty-search-kb")
      assert {:ok, []} = Knowledge.search(kb.id, "anything", 5)
    end

    test "returns fewer than limit when KB has fewer chunks" do
      kb = insert(:knowledge_base, slug: "small-search-kb")

      Enum.each(0..2, fn i ->
        insert(:kb_chunk, knowledge_base: kb, source_path: "s.txt", chunk_index: i)
      end)

      assert {:ok, results} = Knowledge.search(kb.id, "query", 10)
      assert length(results) == 3
    end

    test "only returns chunks from the target KB" do
      kb1 = insert(:knowledge_base, slug: "kb1-scope")
      kb2 = insert(:knowledge_base, slug: "kb2-scope")

      insert(:kb_chunk, knowledge_base: kb1, source_path: "k1.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb2, source_path: "k2.txt", chunk_index: 0)

      assert {:ok, results} = Knowledge.search(kb1.id, "query", 5)
      assert Enum.all?(results, fn c -> c.kb_id == kb1.id end)
    end
  end

  # ---------------------------------------------------------------------------
  # assign / unassign
  # ---------------------------------------------------------------------------

  describe "assign/2 and unassign/2" do
    test "assigns an agent to a KB" do
      kb = insert(:knowledge_base, slug: "assign-kb")
      assert {:ok, assignment} = Knowledge.assign(kb.id, "test-agent")
      assert assignment.kb_id == kb.id
      assert assignment.agent_slug == "test-agent"
    end

    test "assign is idempotent (on_conflict: nothing)" do
      kb = insert(:knowledge_base, slug: "idem-assign-kb")
      assert {:ok, _} = Knowledge.assign(kb.id, "agent-x")
      assert {:ok, _} = Knowledge.assign(kb.id, "agent-x")

      count =
        Repo.aggregate(
          Ecto.Query.from(a in KbAgentAssignment, where: a.kb_id == ^kb.id),
          :count,
          :id
        )

      assert count == 1
    end

    test "unassigns an agent" do
      kb = insert(:knowledge_base, slug: "unassign-kb")
      {:ok, _} = Knowledge.assign(kb.id, "agent-to-remove")
      :ok = Knowledge.unassign(kb.id, "agent-to-remove")

      count =
        Repo.aggregate(
          Ecto.Query.from(a in KbAgentAssignment, where: a.kb_id == ^kb.id),
          :count,
          :id
        )

      assert count == 0
    end

    test "unassign is idempotent" do
      kb = insert(:knowledge_base, slug: "idem-unassign-kb")
      assert :ok = Knowledge.unassign(kb.id, "nonexistent-agent")
    end
  end

  # ---------------------------------------------------------------------------
  # retrieve_for_agent/3
  # ---------------------------------------------------------------------------

  describe "retrieve_for_agent/3" do
    test "returns empty list when agent has no KB assignments" do
      assert {:ok, []} = Knowledge.retrieve_for_agent("unassigned-agent", "query", 5)
    end

    test "returns chunks from all assigned KBs" do
      kb1 = insert(:knowledge_base, slug: "rag-kb1")
      kb2 = insert(:knowledge_base, slug: "rag-kb2")
      insert(:kb_chunk, knowledge_base: kb1, source_path: "r1.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb2, source_path: "r2.txt", chunk_index: 0)

      Knowledge.assign(kb1.id, "rag-agent")
      Knowledge.assign(kb2.id, "rag-agent")

      assert {:ok, results} = Knowledge.retrieve_for_agent("rag-agent", "query", 5)
      kb_ids = Enum.map(results, & &1.kb_id) |> Enum.uniq()
      assert kb1.id in kb_ids
      assert kb2.id in kb_ids
    end
  end

  # ---------------------------------------------------------------------------
  # rebuild_index/1
  # ---------------------------------------------------------------------------

  describe "rebuild_index/1" do
    test "deletes existing chunks and returns zero for a KB with no file-backed chunks" do
      kb = insert(:knowledge_base, slug: "rebuild-kb")
      # Add direct-path chunks (no source_file_id) — these won't be re-indexed
      insert(:kb_chunk, knowledge_base: kb, source_path: "direct.txt", chunk_index: 0)
      insert(:kb_chunk, knowledge_base: kb, source_path: "direct.txt", chunk_index: 1)

      assert {:ok, 0} = Knowledge.rebuild_index(kb.id)

      # All chunks deleted (no file-backed sources to re-index)
      count =
        Repo.aggregate(
          Ecto.Query.from(c in KbChunk, where: c.kb_id == ^kb.id),
          :count,
          :id
        )

      assert count == 0
    end

    test "returns error for unknown KB id" do
      assert {:error, :not_found} = Knowledge.rebuild_index(Ecto.UUID.generate())
    end
  end
end
