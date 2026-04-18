defmodule Canopy.Chat do
  @moduledoc """
  Public context for chat threads.

  A thread is a thin coordination layer on top of `Canopy.Sessions`. It groups
  Sessions by conversational context and tracks display state (title, pinned,
  archived). All message storage lives in `SessionMessage` — threads never
  duplicate content.

  ## Thread lifecycle

  1. `create_thread/1` — creates the Thread row and calls `Sessions.create/1`
     for the initial Session. `last_session_id` is set to the new session.

  2. `continue_thread/2` — creates a new Session whose `parent_session_id`
     points to the thread's `last_session_id`. Updates `last_session_id` on
     the thread. No junction table.

  3. `thread_transcript/1` — walks the session chain via `parent_session_id`
     starting from `last_session_id`, concatenates messages.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Chat.{Exporter, Thread}
  alias Canopy.Repo
  alias Canopy.Sessions

  require Logger

  # ---------------------------------------------------------------------------
  # Thread lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Creates a thread and an initial Session.

  Returns `{:ok, thread}` with `thread.last_session_id` populated, or any
  error that `Sessions.create/1` returns.
  """
  @spec create_thread(map()) ::
          {:ok, Thread.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def create_thread(attrs) do
    session_attrs = build_session_attrs(attrs)

    with {:ok, session} <- Sessions.create(session_attrs),
         {:ok, thread} <- insert_thread(attrs, session) do
      {:ok, thread}
    end
  end

  @doc """
  Creates a new Session continuation within the thread.

  The new Session gets `parent_session_id` set to the thread's current
  `last_session_id`. Updates `last_session_id` on the thread.

  Returns `{:ok, %{thread: thread, session: session}}` on success.
  """
  @spec continue_thread(binary(), String.t()) ::
          {:ok, %{thread: Thread.t(), session: Sessions.Session.t()}}
          | {:error, :not_found}
          | {:error, Ecto.Changeset.t()}
          | {:error, term()}
  def continue_thread(thread_id, prompt) when is_binary(thread_id) do
    with {:ok, thread} <- get_thread(thread_id) do
      session_attrs =
        build_session_attrs(%{
          runtime_type: thread.runtime_type,
          model_id: thread.model_id,
          agent_slug: thread.agent_slug,
          workspace_slug: thread.workspace_slug,
          prompt: prompt,
          parent_session_id: thread.last_session_id
        })

      with {:ok, session} <- Sessions.create(session_attrs),
           {:ok, updated_thread} <- update_thread_last_session(thread, session.id) do
        {:ok, %{thread: updated_thread, session: session}}
      end
    end
  end

  @doc """
  Lists threads with optional filters.

  Filters (all optional):
  - `:user_id`    — filter by user UUID
  - `:agent_slug` — filter by agent
  - `:archived`   — when `true`, include only archived threads; false (default) excludes archived
  - `:pinned`     — when `true`, return only pinned threads
  """
  @spec list_threads(map()) :: [Thread.t()]
  def list_threads(filters \\ %{}) do
    Thread
    |> apply_thread_filter(:user_id, Map.get(filters, :user_id))
    |> apply_thread_filter(:agent_slug, Map.get(filters, :agent_slug))
    |> apply_archived_filter(Map.get(filters, :archived, false))
    |> apply_thread_filter(:pinned, Map.get(filters, :pinned))
    |> from(order_by: [desc_nulls_last: :last_message_at, desc: :inserted_at])
    |> Repo.all()
  end

  @doc """
  Returns a thread by id.

  Returns `{:ok, thread}` or `{:error, :not_found}`.
  """
  @spec get_thread(binary()) :: {:ok, Thread.t()} | {:error, :not_found}
  def get_thread(id) do
    case Repo.get(Thread, id) do
      nil -> {:error, :not_found}
      thread -> {:ok, thread}
    end
  end

  @doc "Renames a thread. Returns `{:ok, thread}` or `{:error, :not_found | changeset}`."
  @spec rename_thread(binary(), String.t()) ::
          {:ok, Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def rename_thread(id, title) do
    with {:ok, thread} <- fetch_thread(id) do
      thread
      |> Thread.update_changeset(%{title: title})
      |> Repo.update()
    end
  end

  @doc "Pins a thread."
  @spec pin_thread(binary()) :: {:ok, Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def pin_thread(id) do
    with {:ok, thread} <- fetch_thread(id) do
      thread
      |> Thread.update_changeset(%{pinned: true})
      |> Repo.update()
    end
  end

  @doc "Unpins a thread."
  @spec unpin_thread(binary()) :: {:ok, Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def unpin_thread(id) do
    with {:ok, thread} <- fetch_thread(id) do
      thread
      |> Thread.update_changeset(%{pinned: false})
      |> Repo.update()
    end
  end

  @doc "Archives a thread by setting `archived_at` to now."
  @spec archive_thread(binary()) ::
          {:ok, Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def archive_thread(id) do
    with {:ok, thread} <- fetch_thread(id) do
      thread
      |> Thread.update_changeset(%{archived_at: DateTime.utc_now()})
      |> Repo.update()
    end
  end

  @doc "Unarchives a thread by clearing `archived_at`."
  @spec unarchive_thread(binary()) ::
          {:ok, Thread.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def unarchive_thread(id) do
    with {:ok, thread} <- fetch_thread(id) do
      thread
      |> Thread.update_changeset(%{archived_at: nil})
      |> Repo.update()
    end
  end

  @doc """
  Hard-deletes a thread. Underlying Sessions are preserved.

  Returns `:ok` or `{:error, :not_found}`.
  """
  @spec delete_thread(binary()) :: :ok | {:error, :not_found}
  def delete_thread(id) do
    with {:ok, thread} <- fetch_thread(id) do
      Repo.delete!(thread)
      :ok
    end
  end

  @doc """
  Returns the concatenated transcript across all Sessions in the thread's chain,
  ordered by session chain (parent_session_id walk) then message sequence.
  """
  @spec thread_transcript(binary(), keyword()) ::
          {:ok, [Canopy.Sessions.SessionMessage.t()]} | {:error, :not_found}
  def thread_transcript(thread_id, _opts \\ []) do
    with {:ok, thread} <- fetch_thread(thread_id) do
      messages = load_ordered_messages(thread)
      {:ok, messages}
    end
  end

  @doc """
  Returns a markdown export of the thread's full transcript.
  """
  @spec export_thread(binary(), keyword()) ::
          {:ok, String.t()} | {:error, :not_found}
  def export_thread(thread_id, opts \\ []) do
    with {:ok, thread} <- get_thread(thread_id),
         {:ok, messages} <- thread_transcript(thread_id, opts) do
      markdown = Exporter.export(thread, messages, opts)
      {:ok, markdown}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec build_session_attrs(map()) :: map()
  defp build_session_attrs(attrs) do
    %{
      runtime_type: attrs[:runtime_type] || attrs["runtime_type"],
      model_id: attrs[:model_id] || attrs["model_id"],
      agent_slug: attrs[:agent_slug] || attrs["agent_slug"],
      workspace_slug: attrs[:workspace_slug] || attrs["workspace_slug"],
      prompt: attrs[:prompt] || attrs["prompt"],
      parent_session_id: attrs[:parent_session_id] || attrs["parent_session_id"],
      cwd: System.tmp_dir!(),
      metadata: %{}
    }
  end

  @spec insert_thread(map(), Sessions.Session.t()) ::
          {:ok, Thread.t()} | {:error, Ecto.Changeset.t()}
  defp insert_thread(attrs, session) do
    thread_attrs = %{
      title: attrs[:title] || attrs["title"],
      user_id: attrs[:user_id] || attrs["user_id"],
      agent_slug: attrs[:agent_slug] || attrs["agent_slug"],
      runtime_type: attrs[:runtime_type] || attrs["runtime_type"],
      model_id: attrs[:model_id] || attrs["model_id"],
      workspace_slug: attrs[:workspace_slug] || attrs["workspace_slug"],
      last_session_id: session.id,
      last_message_at: DateTime.truncate(DateTime.utc_now(), :second)
    }

    %Thread{}
    |> Thread.changeset(thread_attrs)
    |> Repo.insert()
  end

  @spec update_thread_last_session(Thread.t(), binary()) ::
          {:ok, Thread.t()} | {:error, Ecto.Changeset.t()}
  defp update_thread_last_session(thread, session_id) do
    thread
    |> Thread.update_changeset(%{
      last_session_id: session_id,
      last_message_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
    |> Repo.update()
  end

  @spec fetch_thread(binary()) :: {:ok, Thread.t()} | {:error, :not_found}
  defp fetch_thread(id) do
    case Repo.get(Thread, id) do
      nil -> {:error, :not_found}
      thread -> {:ok, thread}
    end
  end

  # Walk the session chain via parent_session_id, collect all session_ids in order,
  # then load messages sorted by (chain_order, sequence).
  @spec load_ordered_messages(Thread.t()) :: [Canopy.Sessions.SessionMessage.t()]
  defp load_ordered_messages(%Thread{last_session_id: nil}), do: []

  defp load_ordered_messages(%Thread{last_session_id: last_session_id}) do
    alias Canopy.Sessions.{Session, SessionMessage}

    # Load all sessions reachable from last_session_id via parent_session_id.
    # Build chain by walking backwards from tail.
    session_ids = walk_session_chain(last_session_id)

    if session_ids == [] do
      []
    else
      Repo.all(
        from(m in SessionMessage,
          where: m.session_id in ^session_ids,
          order_by: [asc: m.session_id, asc: m.sequence]
        )
      )
      |> Enum.sort_by(fn msg ->
        order = Enum.find_index(session_ids, &(&1 == msg.session_id)) || 0
        {order, msg.sequence}
      end)
    end
  end

  # Walk parent_session_id chain backwards, return list in chronological order
  # (root first, tail last). Caps at 200 sessions to prevent infinite loops.
  @spec walk_session_chain(binary()) :: [binary()]
  defp walk_session_chain(session_id) do
    walk_session_chain(session_id, [], 0)
  end

  defp walk_session_chain(_session_id, acc, depth) when depth >= 200, do: acc

  defp walk_session_chain(session_id, acc, depth) do
    alias Canopy.Sessions.Session

    case Repo.one(
           from(s in Session, where: s.id == ^session_id, select: {s.id, s.parent_session_id})
         ) do
      nil ->
        acc

      {id, nil} ->
        [id | acc]

      {id, parent_id} ->
        walk_session_chain(parent_id, [id | acc], depth + 1)
    end
  end

  @spec apply_thread_filter(Ecto.Query.t(), atom(), term()) :: Ecto.Query.t()
  defp apply_thread_filter(query, _field, nil), do: query
  defp apply_thread_filter(query, :user_id, val), do: from(t in query, where: t.user_id == ^val)

  defp apply_thread_filter(query, :agent_slug, val),
    do: from(t in query, where: t.agent_slug == ^val)

  defp apply_thread_filter(query, :pinned, true), do: from(t in query, where: t.pinned == true)
  defp apply_thread_filter(query, :pinned, _), do: query

  @spec apply_archived_filter(Ecto.Query.t(), boolean() | nil) :: Ecto.Query.t()
  defp apply_archived_filter(query, true), do: from(t in query, where: not is_nil(t.archived_at))
  defp apply_archived_filter(query, _), do: from(t in query, where: is_nil(t.archived_at))
end
