defmodule Canopy.Tools.Kanban do
  @moduledoc """
  MCP tools for agent self-reporting on kanban tasks.

  Exposes `kanban.*` tools that wrap `Canopy.Tasks.Kanban` operations so any
  agent can manage its own task lifecycle without touching the Repo directly.

  ## Tool list

  - `kanban.complete_task`   — mark the agent's claimed task as done
  - `kanban.update_task`     — append a status note (and optional progress %) to description
  - `kanban.add_note`        — append a timestamped note to the task description
  - `kanban.list_my_tasks`   — list all tasks currently claimed by this agent
  """

  use Canopy.Tool

  alias Canopy.Tasks
  alias Canopy.Tasks.Kanban

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("kanban.complete_task",
    description: """
    Mark the agent's currently claimed task as done. Optionally attach a summary
    of what was accomplished. The calling agent must already have claimed the task;
    attempting to complete a task claimed by another agent returns an error.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "task_id" => %{
          "type" => "string",
          "description" => "Short task ID, e.g. T-12345678"
        },
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the calling agent"
        },
        "summary" => %{
          "type" => "string",
          "description" => "Optional summary of what was accomplished"
        }
      },
      "required" => ["task_id", "agent_slug"]
    },
    handler: {__MODULE__, :complete_task, []},
    requires: []
  )

  tool("kanban.update_task",
    description: """
    Append a status note and optional progress percentage to the task's description.
    The calling agent must be the one that claimed the task.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "task_id" => %{
          "type" => "string",
          "description" => "Short task ID, e.g. T-12345678"
        },
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the calling agent"
        },
        "status_note" => %{
          "type" => "string",
          "description" => "Progress note to append to the task description"
        },
        "progress_pct" => %{
          "type" => "integer",
          "description" => "Progress percentage 0-100 (optional)",
          "minimum" => 0,
          "maximum" => 100
        }
      },
      "required" => ["task_id", "agent_slug", "status_note"]
    },
    handler: {__MODULE__, :update_task, []},
    requires: []
  )

  tool("kanban.add_note",
    description:
      "Append a timestamped note to a task's description. The calling agent must have claimed the task.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "task_id" => %{
          "type" => "string",
          "description" => "Short task ID, e.g. T-12345678"
        },
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the calling agent"
        },
        "note" => %{
          "type" => "string",
          "description" => "Note text to append"
        }
      },
      "required" => ["task_id", "agent_slug", "note"]
    },
    handler: {__MODULE__, :add_note, []},
    requires: []
  )

  tool("kanban.list_my_tasks",
    description: "List all tasks currently claimed by the calling agent.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the calling agent"
        }
      },
      "required" => ["agent_slug"]
    },
    handler: {__MODULE__, :list_my_tasks, []},
    requires: []
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def complete_task(%{"task_id" => task_id, "agent_slug" => agent_slug} = args) do
    summary = args["summary"]

    with {:ok, task} <- Tasks.get(task_id),
         :ok <- assert_claimed_by(task, agent_slug) do
      # If a summary was provided, append it to the description before marking done
      task =
        if summary && summary != "" do
          appended = append_description(task.description, "[Summary] #{summary}")

          case Tasks.update(task_id, %{description: appended}) do
            {:ok, updated} -> updated
            _ -> task
          end
        else
          task
        end

      case Kanban.complete_task(task.short_id, task.session_id) do
        {:ok, completed} -> {:ok, serialize(completed)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc false
  def update_task(
        %{"task_id" => task_id, "agent_slug" => agent_slug, "status_note" => note} = args
      ) do
    progress_pct = args["progress_pct"]

    with {:ok, task} <- Tasks.get(task_id),
         :ok <- assert_claimed_by(task, agent_slug) do
      note_line =
        if progress_pct do
          "[Progress #{progress_pct}%] #{note}"
        else
          "[Update] #{note}"
        end

      appended = append_description(task.description, note_line)

      case Tasks.update(task_id, %{description: appended}) do
        {:ok, updated} -> {:ok, serialize(updated)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc false
  def add_note(%{"task_id" => task_id, "agent_slug" => agent_slug, "note" => note}) do
    with {:ok, task} <- Tasks.get(task_id),
         :ok <- assert_claimed_by(task, agent_slug) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      note_line = "[Note #{timestamp}] #{note}"
      appended = append_description(task.description, note_line)

      case Tasks.update(task_id, %{description: appended}) do
        {:ok, updated} -> {:ok, serialize(updated)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc false
  def list_my_tasks(%{"agent_slug" => agent_slug}) do
    tasks = Kanban.claimed_by(agent_slug)
    {:ok, %{count: length(tasks), tasks: Enum.map(tasks, &serialize/1)}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp assert_claimed_by(%{claimed_by_agent_id: nil}, _agent_slug),
    do: {:error, :not_claimed}

  defp assert_claimed_by(%{claimed_by_agent_id: claimant}, agent_slug)
       when claimant == agent_slug,
       do: :ok

  defp assert_claimed_by(_task, _agent_slug),
    do: {:error, :not_your_task}

  defp append_description(nil, line), do: line
  defp append_description(existing, line), do: "#{existing}\n\n#{line}"

  defp serialize(task) do
    %{
      id: task.id,
      short_id: task.short_id,
      title: task.title,
      description: task.description,
      status: task.status,
      priority: task.priority,
      workspace_slug: task.workspace_slug,
      claimed_by_agent_id: task.claimed_by_agent_id,
      claimed_at: task.claimed_at,
      completed_at: task.completed_at,
      inserted_at: task.inserted_at,
      updated_at: task.updated_at
    }
  end
end
