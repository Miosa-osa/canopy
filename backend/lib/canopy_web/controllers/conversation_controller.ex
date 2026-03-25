defmodule CanopyWeb.ConversationController do
  use CanopyWeb, :controller

  alias Canopy.Repo
  alias Canopy.Schemas.{Conversation, ConversationMessage, Agent}
  import Ecto.Query

  # ── Index ───────────────────────────────────────────────────────────────────

  def index(conn, params) do
    agent_id = params["agent_id"]
    status = params["status"]
    limit = min(String.to_integer(params["limit"] || "50"), 100)
    offset = String.to_integer(params["offset"] || "0")

    query =
      from c in Conversation,
        join: a in Agent,
        on: c.agent_id == a.id,
        order_by: [desc: coalesce(c.last_message_at, c.inserted_at)],
        limit: ^limit,
        offset: ^offset,
        select: %{
          id: c.id,
          title: c.title,
          agent_id: c.agent_id,
          agent_name: a.name,
          agent_avatar: a.avatar_emoji,
          workspace_id: c.workspace_id,
          user_id: c.user_id,
          status: c.status,
          last_message_at: c.last_message_at,
          message_count: c.message_count,
          metadata: c.metadata,
          inserted_at: c.inserted_at,
          updated_at: c.updated_at
        }

    query = if agent_id, do: where(query, [c], c.agent_id == ^agent_id), else: query
    query = if status, do: where(query, [c], c.status == ^status), else: query

    count_query = from(c in Conversation)

    count_query =
      if agent_id, do: where(count_query, [c], c.agent_id == ^agent_id), else: count_query

    count_query = if status, do: where(count_query, [c], c.status == ^status), else: count_query

    conversations = Repo.all(query)
    total = Repo.aggregate(count_query, :count)

    json(conn, %{conversations: conversations, total: total})
  end

  # ── Show ────────────────────────────────────────────────────────────────────

  def show(conn, %{"id" => id}) do
    case Repo.get(Conversation, id) |> Repo.preload([:agent, :workspace]) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      conv ->
        recent_messages =
          Repo.all(
            from m in ConversationMessage,
              where: m.conversation_id == ^id,
              order_by: [asc: m.inserted_at],
              limit: 50
          )

        json(conn, %{
          conversation: serialize_conversation(conv),
          messages: Enum.map(recent_messages, &serialize_message/1)
        })
    end
  end

  # ── Create ──────────────────────────────────────────────────────────────────

  def create(conn, params) do
    agent_id = params["agent_id"]
    title = params["title"]
    workspace_id = params["workspace_id"]
    user_id = params["user_id"]

    attrs = %{
      agent_id: agent_id,
      title: title,
      workspace_id: workspace_id,
      user_id: user_id,
      status: "active"
    }

    case %Conversation{} |> Conversation.changeset(attrs) |> Repo.insert() do
      {:ok, conv} ->
        conv = Repo.preload(conv, :agent)

        conn
        |> put_status(201)
        |> json(%{conversation: serialize_conversation(conv)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  # ── Delete ──────────────────────────────────────────────────────────────────

  def delete(conn, %{"id" => id}) do
    case Repo.get(Conversation, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      conv ->
        Repo.delete!(conv)
        send_resp(conn, 204, "")
    end
  end

  # ── Messages (paginated) ────────────────────────────────────────────────────

  def messages(conn, %{"conversation_id" => conversation_id} = params) do
    case Repo.get(Conversation, conversation_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      _conv ->
        limit = min(String.to_integer(params["limit"] || "50"), 200)
        before_id = params["before"]

        query =
          from m in ConversationMessage,
            where: m.conversation_id == ^conversation_id,
            order_by: [desc: m.inserted_at],
            limit: ^limit

        query =
          if before_id do
            case Repo.get(ConversationMessage, before_id) do
              nil ->
                query

              cursor_msg ->
                where(query, [m], m.inserted_at < ^cursor_msg.inserted_at)
            end
          else
            query
          end

        msgs = query |> Repo.all() |> Enum.reverse()

        json(conn, %{
          messages: Enum.map(msgs, &serialize_message/1),
          count: length(msgs)
        })
    end
  end

  # ── Send Message ────────────────────────────────────────────────────────────

  def send_message(conn, %{"conversation_id" => conversation_id} = params) do
    content = params["content"] || ""

    case Repo.get(Conversation, conversation_id) |> Repo.preload(:agent) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      conv ->
        now = DateTime.utc_now()
        agent_content = mock_agent_response(content, conv.agent)

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.insert(
            :user_message,
            ConversationMessage.changeset(%ConversationMessage{}, %{
              conversation_id: conversation_id,
              role: "user",
              content: content,
              content_type: "text"
            })
          )
          |> Ecto.Multi.insert(
            :agent_message,
            ConversationMessage.changeset(%ConversationMessage{}, %{
              conversation_id: conversation_id,
              role: "agent",
              content: agent_content,
              content_type: "text"
            })
          )
          |> Ecto.Multi.update(
            :conversation,
            Conversation.changeset(conv, %{
              message_count: conv.message_count + 2,
              last_message_at: now
            })
          )

        case Repo.transaction(multi) do
          {:ok, %{user_message: user_msg, agent_message: agent_msg}} ->
            json(conn, %{
              user_message: serialize_message(user_msg),
              agent_message: serialize_message(agent_msg)
            })

          {:error, failed_op, changeset, _changes} ->
            conn
            |> put_status(422)
            |> json(%{error: "message_failed", step: failed_op, details: format_errors(changeset)})
        end
    end
  end

  # ── Archive ─────────────────────────────────────────────────────────────────

  def archive(conn, %{"conversation_id" => id}) do
    case Repo.get(Conversation, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      conv ->
        case conv |> Conversation.changeset(%{status: "archived"}) |> Repo.update() do
          {:ok, updated} ->
            updated = Repo.preload(updated, :agent)
            json(conn, %{conversation: serialize_conversation(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "update_failed", details: format_errors(changeset)})
        end
    end
  end

  # ── Private helpers ─────────────────────────────────────────────────────────

  defp serialize_conversation(conv) do
    %{
      id: conv.id,
      title: conv.title,
      agent_id: conv.agent_id,
      agent_name: Map.get(conv, :agent) && conv.agent.name,
      agent_avatar: Map.get(conv, :agent) && conv.agent.avatar_emoji,
      workspace_id: conv.workspace_id,
      user_id: conv.user_id,
      status: conv.status,
      last_message_at: conv.last_message_at,
      message_count: conv.message_count,
      metadata: conv.metadata,
      inserted_at: conv.inserted_at,
      updated_at: conv.updated_at
    }
  end

  defp serialize_message(msg) do
    %{
      id: msg.id,
      conversation_id: msg.conversation_id,
      role: msg.role,
      content: msg.content,
      content_type: msg.content_type,
      metadata: msg.metadata,
      token_count: msg.token_count,
      cost_cents: msg.cost_cents,
      inserted_at: msg.inserted_at
    }
  end

  defp mock_agent_response(prompt, agent) do
    agent_name = if agent, do: agent.name, else: "Agent"

    "#{agent_name} here. I received your message: \"#{String.slice(prompt, 0, 60)}#{if String.length(prompt) > 60, do: "...", else: ""}\".\n\n" <>
      "This is a placeholder response. Real OSA execution will be wired in a future release. " <>
      "Your request has been acknowledged and queued for processing."
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
