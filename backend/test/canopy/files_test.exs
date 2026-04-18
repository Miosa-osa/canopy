defmodule Canopy.FilesTest do
  @moduledoc """
  Integration tests for Canopy.Files public API.

  Covers: index_file, index_workspace idempotency, list with filters,
  tag CRUD, record_read throttle, activity log, archive, record_rename.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Files
  alias Canopy.Files.{Activity, FileRecord}
  alias Canopy.Repo
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp make_workspace do
    dir = Path.join(System.tmp_dir!(), "files-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)

    {:ok, ws} =
      Repo.insert(
        Workspace.changeset(%Workspace{}, %{
          slug: "ws-#{System.unique_integer([:positive])}",
          name: "Test Workspace",
          root_path: dir
        })
      )

    {ws, dir}
  end

  defp write_file!(dir, rel, content \\ "# hello") do
    abs = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
    abs
  end

  defp default_actor, do: %{type: "user", id: "u-#{System.unique_integer([:positive])}"}

  # ---------------------------------------------------------------------------
  # index_file/3
  # ---------------------------------------------------------------------------

  describe "index_file/3" do
    test "indexes a new file and returns {:ok, %FileRecord{}}" do
      {ws, dir} = make_workspace()
      write_file!(dir, "docs/intro.md")

      assert {:ok, %FileRecord{} = file} = Files.index_file(ws.id, "docs/intro.md")

      assert file.workspace_id == ws.id
      assert file.path == "docs/intro.md"
      assert file.name == "intro.md"
      assert file.extension == "md"
      assert file.mime_type == "text/markdown"
      assert is_binary(file.sha256)
      refute is_nil(file.id)
    end

    test "creates a 'created' activity entry on first index" do
      {ws, dir} = make_workspace()
      write_file!(dir, "README.md")

      {:ok, file} = Files.index_file(ws.id, "README.md")

      activities = Repo.all(from a in Activity, where: a.file_id == ^file.id)
      assert length(activities) == 1
      assert hd(activities).action == "created"
    end

    test "re-indexing unchanged file still returns {:ok, file}" do
      {ws, dir} = make_workspace()
      write_file!(dir, "SYSTEM.md")

      {:ok, first} = Files.index_file(ws.id, "SYSTEM.md")
      {:ok, second} = Files.index_file(ws.id, "SYSTEM.md")

      # Same DB id — upserted to same row
      assert first.id == second.id
    end

    test "re-indexing changed file creates 'updated' activity" do
      {ws, dir} = make_workspace()
      write_file!(dir, "SYSTEM.md", "v1")
      {:ok, file} = Files.index_file(ws.id, "SYSTEM.md")

      write_file!(dir, "SYSTEM.md", "v2 with more content")
      {:ok, _updated} = Files.index_file(ws.id, "SYSTEM.md")

      activities =
        Repo.all(from a in Activity, where: a.file_id == ^file.id, order_by: a.inserted_at)

      actions = Enum.map(activities, & &1.action)
      assert "updated" in actions
    end

    test "returns {:error, :not_found} for non-existent workspace" do
      assert {:error, :not_found} = Files.index_file(Ecto.UUID.generate(), "foo.md")
    end

    test "returns {:error, :not_found} for path not on disk" do
      {ws, _dir} = make_workspace()
      assert {:error, :not_found} = Files.index_file(ws.id, "missing.md")
    end
  end

  # ---------------------------------------------------------------------------
  # index_workspace/1
  # ---------------------------------------------------------------------------

  describe "index_workspace/1" do
    test "indexes all non-hidden files and returns count" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md")
      write_file!(dir, "sub/b.txt")
      write_file!(dir, ".hidden")

      {:ok, count} = Files.index_workspace(ws.id)

      # 2 visible files — .hidden excluded
      assert count == 2
    end

    test "is idempotent — unchanged files return count 0 on re-scan" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md")

      {:ok, 1} = Files.index_workspace(ws.id)
      {:ok, 0} = Files.index_workspace(ws.id)
    end

    test "counts re-indexed file when content changes" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md", "v1")

      {:ok, 1} = Files.index_workspace(ws.id)

      write_file!(dir, "a.md", "v2 different content")
      {:ok, 1} = Files.index_workspace(ws.id)
    end
  end

  # ---------------------------------------------------------------------------
  # get_by_path/2
  # ---------------------------------------------------------------------------

  describe "get_by_path/2" do
    test "returns file by workspace + path" do
      {ws, dir} = make_workspace()
      write_file!(dir, "foo.json")
      {:ok, _} = Files.index_file(ws.id, "foo.json")

      assert {:ok, %FileRecord{name: "foo.json"}} = Files.get_by_path(ws.id, "foo.json")
    end

    test "returns {:error, :not_found} for unknown path" do
      {ws, _} = make_workspace()
      assert {:error, :not_found} = Files.get_by_path(ws.id, "nope.md")
    end
  end

  # ---------------------------------------------------------------------------
  # list/1
  # ---------------------------------------------------------------------------

  describe "list/1" do
    test "lists all active files for workspace" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md")
      write_file!(dir, "b.txt")
      {:ok, _} = Files.index_workspace(ws.id)

      {:ok, files} = Files.list(%{workspace_id: ws.id})
      assert length(files) == 2
    end

    test "filters by extension" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md")
      write_file!(dir, "b.txt")
      {:ok, _} = Files.index_workspace(ws.id)

      {:ok, files} = Files.list(%{workspace_id: ws.id, extension: "md"})
      assert length(files) == 1
      assert hd(files).extension == "md"
    end

    test "filters by tag" do
      {ws, dir} = make_workspace()
      write_file!(dir, "tagged.md")
      {:ok, file} = Files.index_file(ws.id, "tagged.md")
      Files.update_tags(file.id, ["important"], default_actor())

      write_file!(dir, "other.md")
      {:ok, _} = Files.index_file(ws.id, "other.md")

      {:ok, results} = Files.list(%{workspace_id: ws.id, tag: "important"})
      assert length(results) == 1
      assert hd(results).id == file.id
    end

    test "name query with :q filter" do
      {ws, dir} = make_workspace()
      write_file!(dir, "readme.md")
      write_file!(dir, "other.md")
      {:ok, _} = Files.index_workspace(ws.id)

      {:ok, results} = Files.list(%{workspace_id: ws.id, q: "readme"})
      assert length(results) == 1
      assert hd(results).name == "readme.md"
    end
  end

  # ---------------------------------------------------------------------------
  # update_tags/3
  # ---------------------------------------------------------------------------

  describe "update_tags/3" do
    test "sets new tags and returns updated file" do
      {ws, dir} = make_workspace()
      write_file!(dir, "notes.md")
      {:ok, file} = Files.index_file(ws.id, "notes.md")

      {:ok, updated} = Files.update_tags(file.id, ["important", "draft"], default_actor())

      assert updated.tags == ["important", "draft"]
    end

    test "logs a 'tagged' activity entry" do
      {ws, dir} = make_workspace()
      write_file!(dir, "notes.md")
      {:ok, file} = Files.index_file(ws.id, "notes.md")
      actor = default_actor()

      Files.update_tags(file.id, ["foo"], actor)

      activities =
        Repo.all(from a in Activity, where: a.file_id == ^file.id and a.action == "tagged")

      assert length(activities) == 1
      assert hd(activities).metadata["added"] == ["foo"]
    end

    test "returns {:error, :not_found} for unknown file" do
      assert {:error, :not_found} = Files.update_tags(Ecto.UUID.generate(), ["x"])
    end
  end

  # ---------------------------------------------------------------------------
  # archive/2
  # ---------------------------------------------------------------------------

  describe "archive/2" do
    test "sets archived_at and returns archived file" do
      {ws, dir} = make_workspace()
      write_file!(dir, "old.md")
      {:ok, file} = Files.index_file(ws.id, "old.md")

      {:ok, archived} = Files.archive(file.id, default_actor())
      refute is_nil(archived.archived_at)
    end

    test "archived file excluded from default list" do
      {ws, dir} = make_workspace()
      write_file!(dir, "old.md")
      {:ok, file} = Files.index_file(ws.id, "old.md")
      Files.archive(file.id, default_actor())

      {:ok, files} = Files.list(%{workspace_id: ws.id})
      assert Enum.all?(files, &is_nil(&1.archived_at))
    end
  end

  # ---------------------------------------------------------------------------
  # record_read throttle
  # ---------------------------------------------------------------------------

  describe "record_read/2" do
    test "logs first read and returns {:ok, :logged}" do
      {ws, dir} = make_workspace()
      write_file!(dir, "r.md")
      {:ok, file} = Files.index_file(ws.id, "r.md")
      actor = default_actor()

      assert {:ok, :logged} = Files.record_read(file.id, actor)

      reads = Repo.all(from a in Activity, where: a.file_id == ^file.id and a.action == "read")
      assert length(reads) == 1
    end

    test "throttles second read within 1 hour — returns {:ok, :throttled}" do
      {ws, dir} = make_workspace()
      write_file!(dir, "r.md")
      {:ok, file} = Files.index_file(ws.id, "r.md")
      actor = default_actor()

      {:ok, :logged} = Files.record_read(file.id, actor)
      assert {:ok, :throttled} = Files.record_read(file.id, actor)

      reads = Repo.all(from a in Activity, where: a.file_id == ^file.id and a.action == "read")
      assert length(reads) == 1
    end

    test "different actors log independently" do
      {ws, dir} = make_workspace()
      write_file!(dir, "r.md")
      {:ok, file} = Files.index_file(ws.id, "r.md")

      {:ok, :logged} = Files.record_read(file.id, %{type: "user", id: "u-1"})
      {:ok, :logged} = Files.record_read(file.id, %{type: "user", id: "u-2"})

      reads = Repo.all(from a in Activity, where: a.file_id == ^file.id and a.action == "read")
      assert length(reads) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # log_activity/4
  # ---------------------------------------------------------------------------

  describe "log_activity/4" do
    test "inserts activity entry with correct fields" do
      {ws, dir} = make_workspace()
      write_file!(dir, "x.md")
      {:ok, file} = Files.index_file(ws.id, "x.md")
      actor = %{type: "agent", id: "ghost"}

      {:ok, activity} = Files.log_activity(file.id, actor, "updated", %{"source" => "test"})

      assert activity.file_id == file.id
      assert activity.actor_type == "agent"
      assert activity.actor_id == "ghost"
      assert activity.action == "updated"
      # JSONB normalises map keys to strings on insert — check string keys.
      assert Map.get(activity.metadata, "source") == "test" or
               Map.get(activity.metadata, :source) == "test"
    end
  end

  # ---------------------------------------------------------------------------
  # record_rename/4
  # ---------------------------------------------------------------------------

  describe "record_rename/4" do
    test "updates path and name, logs renamed activity" do
      {ws, dir} = make_workspace()
      write_file!(dir, "old-name.md")
      {:ok, file} = Files.index_file(ws.id, "old-name.md")

      # Create new file on disk (simulate filesystem move)
      write_file!(dir, "new-name.md", File.read!(Path.join(dir, "old-name.md")))
      actor = default_actor()

      {:ok, updated} = Files.record_rename("old-name.md", "new-name.md", ws.id, actor)

      assert updated.path == "new-name.md"
      assert updated.name == "new-name.md"
      assert updated.id == file.id

      activities =
        Repo.all(from a in Activity, where: a.file_id == ^file.id and a.action == "renamed")

      assert length(activities) == 1
      assert hd(activities).metadata["old_path"] == "old-name.md"
      assert hd(activities).metadata["new_path"] == "new-name.md"
    end

    test "returns {:error, :not_found} when old_path not indexed" do
      {ws, _dir} = make_workspace()

      assert {:error, :not_found} =
               Files.record_rename("ghost.md", "new.md", ws.id, default_actor())
    end
  end

  # ---------------------------------------------------------------------------
  # list_activity/2
  # ---------------------------------------------------------------------------

  describe "list_activity/2" do
    test "returns activity entries newest first" do
      {ws, dir} = make_workspace()
      write_file!(dir, "a.md")
      {:ok, file} = Files.index_file(ws.id, "a.md")
      actor = default_actor()

      Files.log_activity(file.id, actor, "updated", %{})
      Files.record_read(file.id, actor)

      {:ok, entries} = Files.list_activity(file.id, 50)
      assert length(entries) >= 2
      # Most recent first
      [first | _] = entries
      assert first.action == "read"
    end
  end
end
