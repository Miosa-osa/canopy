defmodule CanopyWeb.Schemas.WorktreeSchema do
  @moduledoc """
  OpenAPISpex schema definitions for worktree endpoints.
  """

  alias OpenApiSpex.Schema

  defmodule WorktreeStatus do
    @moduledoc "Worktree existence and change summary for a session."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorktreeStatus",
      type: :object,
      properties: %{
        path: %Schema{type: :string, nullable: true, description: "Absolute path to the worktree"},
        branch: %Schema{type: :string, nullable: true, description: "Session branch name"},
        base_branch: %Schema{
          type: :string,
          nullable: true,
          description: "Branch worktree was forked from"
        },
        exists: %Schema{
          type: :boolean,
          description: "Whether the worktree directory exists on disk"
        },
        has_changes: %Schema{type: :boolean, description: "True when changes_count > 0"},
        changes_count: %Schema{
          type: :integer,
          description: "Number of changed files (git status --porcelain)"
        },
        ahead: %Schema{type: :integer, description: "Commits ahead of base branch"},
        behind: %Schema{type: :integer, description: "Commits behind base branch"}
      },
      required: [:exists, :has_changes, :changes_count, :ahead, :behind]
    })
  end

  defmodule WorktreeDiff do
    @moduledoc "Git diff output for a session worktree."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WorktreeDiff",
      type: :object,
      properties: %{
        stat: %Schema{type: :string, description: "git diff --stat output"},
        diff: %Schema{type: :string, description: "Full diff (capped at 500KB)"},
        truncated: %Schema{type: :boolean, description: "Whether diff was truncated due to size"},
        message: %Schema{
          type: :string,
          nullable: true,
          description: "Informational message when no worktree"
        }
      },
      required: [:diff, :truncated]
    })
  end

  defmodule CommitRequest do
    @moduledoc "Request body for worktree commit with optional file list."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CommitRequest",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Commit message"},
        files: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true,
          description: "Subset of files to stage (default: all via git add -A)"
        }
      },
      required: [:message]
    })
  end

  defmodule CommitResult do
    @moduledoc "Result of a worktree commit."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CommitResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean},
        sha: %Schema{type: :string, description: "Full commit SHA"},
        output: %Schema{type: :string, description: "Human-readable summary"}
      },
      required: [:ok]
    })
  end

  defmodule PushRequest do
    @moduledoc "Request body for worktree push."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PushRequest",
      type: :object,
      properties: %{
        remote: %Schema{type: :string, description: "Remote name (default: origin)", nullable: true}
      }
    })
  end

  defmodule PushResult do
    @moduledoc "Result of a worktree push."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PushResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean},
        ref: %Schema{type: :string, description: "remote/branch that was pushed"}
      },
      required: [:ok]
    })
  end

  defmodule MergeResult do
    @moduledoc "Result of merging session branch back to base."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MergeResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean},
        base_branch: %Schema{type: :string, nullable: true},
        conflict_files: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true,
          description: "Present when error is 'conflict'"
        },
        error: %Schema{type: :string, nullable: true}
      },
      required: [:ok]
    })
  end

  defmodule StageRequest do
    @moduledoc "Request body for staging files in the worktree."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "StageRequest",
      type: :object,
      properties: %{
        files: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "File paths to stage (relative to worktree root)"
        }
      },
      required: [:files]
    })
  end

  defmodule StageResult do
    @moduledoc "Result of a stage operation."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "StageResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean},
        staged: %Schema{type: :array, items: %Schema{type: :string}}
      },
      required: [:ok, :staged]
    })
  end

  defmodule DiscardHunkRequest do
    @moduledoc "Request body for discarding a single hunk in the worktree."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DiscardHunkRequest",
      type: :object,
      properties: %{
        file_path: %Schema{type: :string, description: "Path of the file (relative to worktree)"},
        hunk_header: %Schema{
          type: :string,
          description: "Unified diff hunk header (e.g. '@@ -10,5 +10,7 @@ ...')"
        },
        hunk_content: %Schema{
          type: :string,
          description: "Hunk body lines (each prefixed with '+', '-' or ' ')"
        }
      },
      required: [:file_path, :hunk_header, :hunk_content]
    })
  end

  defmodule DiscardHunkResult do
    @moduledoc "Result of a discard-hunk operation."
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DiscardHunkResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean}
      },
      required: [:ok]
    })
  end

  defmodule CleanupResult do
    @moduledoc "Result of a worktree cleanup."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CleanupResult",
      type: :object,
      properties: %{
        ok: %Schema{type: :boolean}
      },
      required: [:ok]
    })
  end
end
