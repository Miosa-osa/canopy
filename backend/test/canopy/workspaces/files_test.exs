defmodule Canopy.Workspaces.FilesTest do
  @moduledoc """
  Tests for `Canopy.Workspaces.Files`.

  Focuses on path-traversal guards and filesystem operations. Every test
  operates in an isolated temporary directory so tests are hermetic and
  parallel-safe.
  """

  use ExUnit.Case, async: true

  alias Canopy.Workspaces.Files
  alias Canopy.Workspaces.Workspace

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp tmp_workspace(overrides \\ %{}) do
    dir = System.tmp_dir!() |> Path.join("canopy-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    on_exit(fn -> File.rm_rf(dir) end)

    ws = %Workspace{
      id: Ecto.UUID.generate(),
      slug: "test-ws",
      name: "Test Workspace",
      root_path: dir
    }

    {Map.merge(ws, overrides), dir}
  end

  defp write_file!(ws_dir, rel_path, content \\ "hello") do
    abs = Path.join(ws_dir, rel_path)
    File.mkdir_p!(Path.dirname(abs))
    File.write!(abs, content)
  end

  # ---------------------------------------------------------------------------
  # list_dir/2
  # ---------------------------------------------------------------------------

  describe "list_dir/2" do
    test "returns entries for workspace root" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "notes.md")
      write_file!(dir, "sub/nested.md")

      assert {:ok, entries} = Files.list_dir(ws)
      names = Enum.map(entries, & &1.name)
      assert "notes.md" in names
      assert "sub" in names
    end

    test "returns entries for subdirectory" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "sub/a.md")
      write_file!(dir, "sub/b.md")

      assert {:ok, entries} = Files.list_dir(ws, "sub")
      names = Enum.map(entries, & &1.name)
      assert "a.md" in names
      assert "b.md" in names
    end

    test "returns :not_found when directory does not exist" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :not_found} = Files.list_dir(ws, "nonexistent")
    end

    test "returns :traversal for .. segments" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.list_dir(ws, "../../etc")
      assert {:error, :traversal} = Files.list_dir(ws, "../escape")
    end

    test "returns :traversal for absolute path" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.list_dir(ws, "/etc")
      assert {:error, :traversal} = Files.list_dir(ws, "/etc/passwd")
    end

    test "includes is_dir flag correctly" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "file.md")
      File.mkdir_p!(Path.join(dir, "subdir"))

      {:ok, entries} = Files.list_dir(ws)
      file_entry = Enum.find(entries, &(&1.name == "file.md"))
      dir_entry = Enum.find(entries, &(&1.name == "subdir"))

      assert file_entry.is_dir == false
      assert dir_entry.is_dir == true
    end

    test "empty directory returns empty list" do
      {ws, _dir} = tmp_workspace()
      assert {:ok, []} = Files.list_dir(ws)
    end
  end

  # ---------------------------------------------------------------------------
  # read_file/2
  # ---------------------------------------------------------------------------

  describe "read_file/2" do
    test "reads an existing UTF-8 file" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "hello.md", "# Hello World\n")

      assert {:ok, "# Hello World\n"} = Files.read_file(ws, "hello.md")
    end

    test "reads a file in a subdirectory" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "sub/notes.md", "content")

      assert {:ok, "content"} = Files.read_file(ws, "sub/notes.md")
    end

    test "returns :not_found when file does not exist" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :not_found} = Files.read_file(ws, "missing.md")
    end

    test "returns :traversal for .. segments" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.read_file(ws, "../../etc/passwd")
      assert {:error, :traversal} = Files.read_file(ws, "../escape.md")
    end

    test "returns :traversal for absolute paths" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.read_file(ws, "/etc/passwd")
    end

    test "returns :too_large for files over 10MB" do
      {ws, dir} = tmp_workspace()
      large_path = Path.join(dir, "large.bin")
      # Create a sparse file larger than the 10MB limit
      {:ok, f} = :file.open(String.to_charlist(large_path), [:write, :binary])
      :file.pwrite(f, 10 * 1024 * 1024 + 1, <<0>>)
      :file.close(f)

      assert {:error, :too_large} = Files.read_file(ws, "large.bin")
    end

    test "returns :not_utf8 for binary content" do
      {ws, dir} = tmp_workspace()
      bin_path = Path.join(dir, "binary.bin")
      # Write invalid UTF-8 bytes
      File.write!(bin_path, <<0xFF, 0xFE, 0x00, 0x01>>)

      assert {:error, :not_utf8} = Files.read_file(ws, "binary.bin")
    end
  end

  # ---------------------------------------------------------------------------
  # write_file/3
  # ---------------------------------------------------------------------------

  describe "write_file/3" do
    test "writes content to a new file" do
      {ws, dir} = tmp_workspace()

      assert :ok = Files.write_file(ws, "output.md", "# Output\n")
      assert File.read!(Path.join(dir, "output.md")) == "# Output\n"
    end

    test "creates parent directories as needed" do
      {ws, dir} = tmp_workspace()

      assert :ok = Files.write_file(ws, "deep/nested/file.md", "content")
      assert File.exists?(Path.join(dir, "deep/nested/file.md"))
    end

    test "overwrites an existing file" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "existing.md", "old content")

      assert :ok = Files.write_file(ws, "existing.md", "new content")
      assert File.read!(Path.join(dir, "existing.md")) == "new content"
    end

    test "returns :traversal for .. segments" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.write_file(ws, "../escape.md", "content")
      assert {:error, :traversal} = Files.write_file(ws, "../../escape.md", "content")
    end

    test "returns :traversal for absolute paths" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.write_file(ws, "/tmp/escape.md", "content")
    end

    test "write is atomic — file appears with full content" do
      {ws, dir} = tmp_workspace()
      content = String.duplicate("line\n", 1000)

      assert :ok = Files.write_file(ws, "atomic.md", content)
      assert File.read!(Path.join(dir, "atomic.md")) == content
      # No .tmp file left behind
      refute File.exists?(Path.join(dir, "atomic.md.tmp"))
    end
  end

  # ---------------------------------------------------------------------------
  # delete_file/2
  # ---------------------------------------------------------------------------

  describe "delete_file/2" do
    test "deletes an existing file" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "to-delete.md")

      assert :ok = Files.delete_file(ws, "to-delete.md")
      refute File.exists?(Path.join(dir, "to-delete.md"))
    end

    test "returns :ok for non-existent file (idempotent)" do
      {ws, _dir} = tmp_workspace()
      assert :ok = Files.delete_file(ws, "nonexistent.md")
    end

    test "returns :traversal for .. segments" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.delete_file(ws, "../escape.md")
    end

    test "returns :traversal for absolute paths" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.delete_file(ws, "/tmp/escape.md")
    end
  end

  # ---------------------------------------------------------------------------
  # move_file/3
  # ---------------------------------------------------------------------------

  describe "move_file/3" do
    test "moves a file within the workspace" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "original.md", "content")

      assert :ok = Files.move_file(ws, "original.md", "moved.md")
      refute File.exists?(Path.join(dir, "original.md"))
      assert File.read!(Path.join(dir, "moved.md")) == "content"
    end

    test "moves into a new subdirectory" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "file.md", "data")

      assert :ok = Files.move_file(ws, "file.md", "sub/file.md")
      refute File.exists?(Path.join(dir, "file.md"))
      assert File.exists?(Path.join(dir, "sub/file.md"))
    end

    test "returns :not_found when source does not exist" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :not_found} = Files.move_file(ws, "missing.md", "dest.md")
    end

    test "returns :traversal for .. in source path" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.move_file(ws, "../escape.md", "dest.md")
    end

    test "returns :traversal for .. in dest path" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "src.md")
      assert {:error, :traversal} = Files.move_file(ws, "src.md", "../escape.md")
    end

    test "returns :traversal for absolute source path" do
      {ws, _dir} = tmp_workspace()
      assert {:error, :traversal} = Files.move_file(ws, "/etc/passwd", "dest.md")
    end

    test "returns :traversal for absolute dest path" do
      {ws, dir} = tmp_workspace()
      write_file!(dir, "src.md")
      assert {:error, :traversal} = Files.move_file(ws, "src.md", "/tmp/escape.md")
    end
  end
end
