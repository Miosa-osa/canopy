defmodule Canopy.Tools.Relay do
  @moduledoc """
  MCP tools for agent-to-agent relay messaging.

  Exposes `relay.*` tools so agents can communicate, check their inbox,
  update their status, and broadcast to channels without human intervention.

  ## Tool list

  - `relay.send_message`    — send a direct message to another agent
  - `relay.check_inbox`     — read unread messages for the calling agent
  - `relay.update_status`   — set the calling agent's status
  - `relay.broadcast`       — broadcast a message to a named channel
  """

  use Canopy.Tool

  alias Canopy.Agents.Relay

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("relay.send_message",
    description: """
    Send a direct message to another agent. The message is persisted and
    delivered via PubSub. Optionally include a thread_id to group related
    messages, and a priority (low | normal | high | urgent).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "from_agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the sending agent"
        },
        "to_agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the recipient agent"
        },
        "content" => %{
          "type" => "string",
          "description" => "Message body"
        },
        "thread_id" => %{
          "type" => "string",
          "description" => "Optional thread ID to group messages"
        },
        "priority" => %{
          "type" => "string",
          "enum" => ["low", "normal", "high", "urgent"],
          "description" => "Message priority (default: normal)"
        }
      },
      "required" => ["from_agent_slug", "to_agent_slug", "content"]
    },
    handler: {__MODULE__, :send_message, []},
    requires: []
  )

  tool("relay.check_inbox",
    description: """
    Check unread messages for the calling agent. Returns messages ordered by
    priority (urgent first) then timestamp (oldest first). Optionally limit
    the number of messages returned.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the agent checking their inbox"
        },
        "limit" => %{
          "type" => "integer",
          "description" => "Max messages to return (default: 50)",
          "minimum" => 1,
          "maximum" => 200
        }
      },
      "required" => ["agent_slug"]
    },
    handler: {__MODULE__, :check_inbox, []},
    requires: []
  )

  tool("relay.update_status",
    description: """
    Update the calling agent's status in the relay system.
    Valid statuses: online, busy, offline.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the agent"
        },
        "status" => %{
          "type" => "string",
          "enum" => ["online", "busy", "offline"],
          "description" => "New status for the agent"
        }
      },
      "required" => ["agent_slug", "status"]
    },
    handler: {__MODULE__, :update_status, []},
    requires: []
  )

  tool("relay.broadcast",
    description: """
    Broadcast a message to all members of a named channel. The message is
    sent to each member individually and delivered via PubSub.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "from_agent_slug" => %{
          "type" => "string",
          "description" => "Slug of the broadcasting agent"
        },
        "channel_name" => %{
          "type" => "string",
          "description" => "Name of the target channel"
        },
        "content" => %{
          "type" => "string",
          "description" => "Broadcast message body"
        }
      },
      "required" => ["from_agent_slug", "channel_name", "content"]
    },
    handler: {__MODULE__, :broadcast, []},
    requires: []
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def send_message(
        %{"from_agent_slug" => from, "to_agent_slug" => to, "content" => content} = args
      ) do
    attrs = %{
      from_agent_slug: from,
      to_agent_slug: to,
      scope: "direct",
      content: content,
      priority: Map.get(args, "priority", "normal"),
      thread_id: Map.get(args, "thread_id")
    }

    case Relay.send_message(attrs) do
      {:ok, msg} -> {:ok, serialize_message(msg)}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  @doc false
  def check_inbox(%{"agent_slug" => agent_slug} = args) do
    opts =
      case args["limit"] do
        nil -> []
        limit -> [limit: limit]
      end

    messages = Relay.list_inbox(agent_slug, opts)
    {:ok, %{count: length(messages), messages: Enum.map(messages, &serialize_message/1)}}
  end

  @doc false
  def update_status(%{"agent_slug" => agent_slug, "status" => status}) do
    case Relay.update_status(agent_slug, status) do
      {:ok, participant} ->
        {:ok, %{agent_slug: participant.agent_slug, status: participant.status}}

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  @doc false
  def broadcast(%{"from_agent_slug" => from, "channel_name" => channel, "content" => content}) do
    case Relay.broadcast(channel, from, content) do
      {:ok, messages} -> {:ok, %{channel: channel, sent: length(messages)}}
      {:error, :not_found} -> {:error, :channel_not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp serialize_message(msg) do
    %{
      id: msg.id,
      thread_id: msg.thread_id,
      from_agent_slug: msg.from_agent_slug,
      to_agent_slug: msg.to_agent_slug,
      scope: msg.scope,
      priority: msg.priority,
      content: msg.content,
      metadata: msg.metadata,
      read_at: msg.read_at,
      inserted_at: msg.inserted_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
