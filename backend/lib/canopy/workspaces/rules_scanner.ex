defmodule Canopy.Workspaces.RulesScanner do
  @moduledoc """
  Scan a workspace root for project rule files (CLAUDE.md, .cursorrules, etc.)

  Reads files using `File.exists?/1` and `File.read/1` only — no shell commands.
  Returns all found rule files with their content, skipping files larger than 512 KB
  to avoid loading massive binaries into memory.
  """

  @rule_files [
    "CLAUDE.md",
    ".claude/CLAUDE.md",
    ".cursorrules",
    ".cursor/rules",
    ".aider",
    ".github/copilot-instructions.md",
    ".continuerc.json",
    "AGENTS.md",
    "CONVENTIONS.md"
  ]

  @max_bytes 512 * 1024

  @doc """
  Scan `root_path` for known rule files.

  Returns `{:ok, [%{file: String.t(), content: String.t()}]}` — list contains
  only files that exist and could be read. Missing files are silently skipped.

  Returns `{:error, :invalid_path}` when `root_path` is `nil` or not a directory.
  """
  @spec scan(String.t() | nil) :: {:ok, [%{file: String.t(), content: String.t()}]} | {:error, :invalid_path}
  def scan(nil), do: {:error, :invalid_path}

  def scan(root_path) do
    unless File.dir?(root_path) do
      {:error, :invalid_path}
    else
      results =
        @rule_files
        |> Enum.flat_map(fn relative ->
          full_path = Path.join(root_path, relative)

          case read_rule_file(full_path) do
            {:ok, content} -> [%{file: relative, content: content}]
            :skip -> []
          end
        end)

      {:ok, results}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp read_rule_file(full_path) do
    if File.exists?(full_path) do
      case File.stat(full_path) do
        {:ok, %{size: size}} when size > @max_bytes ->
          :skip

        {:ok, _} ->
          case File.read(full_path) do
            {:ok, content} -> {:ok, content}
            {:error, _} -> :skip
          end

        {:error, _} ->
          :skip
      end
    else
      :skip
    end
  end
end
