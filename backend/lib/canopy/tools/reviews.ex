defmodule Canopy.Tools.Reviews do
  @moduledoc """
  Agent/MCP tool surface for the human review queue.
  """

  use Canopy.Tool

  alias Canopy.Reviews

  tool("review.list",
    description: "List saved human-review queue records with optional filters.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "status" => %{
          "type" => "string",
          "enum" => ["pending", "approved", "rejected", "changes_requested", "expired"]
        },
        "kind" => %{"type" => "string", "enum" => ["artifact", "tool_call", "hire_agent"]},
        "agent_id" => %{"type" => "string"},
        "session_id" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :list, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.get",
    description: "Inspect a single saved review record by id.",
    parameters: %{
      "type" => "object",
      "properties" => %{"id" => %{"type" => "string"}},
      "required" => ["id"]
    },
    handler: {__MODULE__, :get, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.summary",
    description:
      "Summarize review queue health with counts by status, kind, workspace, and agent.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "status" => %{
          "type" => "string",
          "enum" => ["pending", "approved", "rejected", "changes_requested", "expired"]
        },
        "kind" => %{"type" => "string", "enum" => ["artifact", "tool_call", "hire_agent"]},
        "agent_id" => %{"type" => "string"},
        "session_id" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :summary, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.request_artifact",
    description:
      "Create a pending artifact review for a doc, task, issue, PR, file, or knowledge chunk.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "artifact_type" => %{
          "type" => "string",
          "enum" => ["doc", "task", "issue", "pr", "file", "kb_chunk"]
        },
        "artifact_id" => %{"type" => "string"},
        "artifact_preview" => %{"type" => "string"},
        "agent_id" => %{"type" => "string"}
      },
      "required" => ["artifact_type"]
    },
    handler: {__MODULE__, :request_artifact, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.request_tool_call",
    description: "Create a pending review for a tool invocation that needs human approval.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "session_id" => %{"type" => "string"},
        "agent_id" => %{"type" => "string"},
        "tool_name" => %{"type" => "string"},
        "tool_args" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["tool_name"]
    },
    handler: {__MODULE__, :request_tool_call, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.approve",
    description: "Approve a pending review.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "reviewer_id" => %{"type" => "string"}
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :approve, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.reject",
    description: "Reject a pending review with optional feedback.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "reviewer_id" => %{"type" => "string"},
        "feedback" => %{"type" => "string"}
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :reject, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.request_changes",
    description: "Move a pending review to changes_requested with optional feedback.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "reviewer_id" => %{"type" => "string"},
        "feedback" => %{"type" => "string"}
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :request_changes, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  tool("review.resubmit",
    description: "Resubmit a changes_requested review back to pending.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "artifact_preview" => %{"type" => "string"}
      },
      "required" => ["id"]
    },
    handler: {__MODULE__, :resubmit, []},
    requires: [:review],
    mcp_exposed: true,
    prompt_exposed: true
  )

  def list(args) do
    filters = filters_from_args(args)

    reviews = Reviews.list(filters)
    {:ok, %{reviews: reviews, count: length(reviews)}}
  end

  def summary(args), do: {:ok, Reviews.summary(filters_from_args(args))}

  def get(%{"id" => id}), do: Reviews.get(id)

  def request_artifact(args) do
    args
    |> Map.take(~w(workspace_slug artifact_type artifact_id artifact_preview agent_id))
    |> Reviews.request_artifact()
  end

  def request_tool_call(%{"tool_name" => tool_name} = args) do
    Reviews.request_tool_call(
      args["session_id"],
      tool_name,
      args["tool_args"] || %{},
      workspace_slug: args["workspace_slug"],
      agent_id: args["agent_id"]
    )
  end

  def approve(%{"id" => id} = args), do: Reviews.approve(id, args["reviewer_id"])

  def reject(%{"id" => id} = args), do: Reviews.reject(id, args["reviewer_id"], args["feedback"])

  def request_changes(%{"id" => id} = args),
    do: Reviews.request_changes(id, args["reviewer_id"], args["feedback"])

  def resubmit(%{"id" => id} = args) do
    attrs =
      case args["artifact_preview"] do
        nil -> %{}
        preview -> %{artifact_preview: preview}
      end

    Reviews.resubmit(id, attrs)
  end

  defp put_if_present(acc, _key, nil), do: acc
  defp put_if_present(acc, _key, ""), do: acc
  defp put_if_present(acc, key, value), do: Map.put(acc, key, value)

  defp filters_from_args(args) do
    %{}
    |> put_if_present(:workspace_slug, args["workspace_slug"])
    |> put_if_present(:status, args["status"])
    |> put_if_present(:kind, args["kind"])
    |> put_if_present(:agent_id, args["agent_id"])
    |> put_if_present(:session_id, args["session_id"])
  end
end
