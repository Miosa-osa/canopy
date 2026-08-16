defmodule Canopy.Tasks.Dispatcher do
  @moduledoc """
  Dispatches a task to a live agent terminal session.

  Resolves the target session (existing or newly spawned), formats the task
  payload, writes it to the pty stdin, marks the task `:in_progress`, and
  broadcasts a `task:dispatched` event for the Kanban frontend.

  ## Resolution order

  1. `task.session_id` is set and the pty process is alive → append to existing session.
  2. `task.assignee_type == "agent"` → find the agent's running session, or spawn a new
     one bound to the agent's `default_runtime`. Updates `task.session_id` on success.
  3. No resolvable target → `{:error, :no_target}`.

  ## PubSub contract

  On success, broadcasts on topic `tasks:workspace:<workspace_slug>`:

      {:task_dispatched, %{task_id: short_id, session_id: session_id, status: "in_progress"}}

  The frontend should subscribe to this topic via the workspace channel or
  refetch the task list on receiving the event.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents
  alias Canopy.Repo
  alias Canopy.Runtimes.Auth
  alias Canopy.Sessions
  alias Canopy.Sessions.{PtyBridge, PtyRegistry, Session}
  alias Canopy.Tasks
  alias Canopy.Tasks.Task

  require Logger

  @type dispatch_opt :: {:agent_slug, String.t()} | {:runtime_type, String.t()}

  @doc """
  Dispatches the task identified by `task_or_id` to a live agent terminal.

  `opts` may override the task's default agent/runtime:
  - `:agent_slug` — use this agent instead of the task's `assignee_id`
  - `:runtime_type` — use this runtime instead of the agent's default

  Returns `{:ok, %{session_id: id, task: %Task{}}}` on success.
  """
  @spec dispatch(Task.t() | String.t(), [dispatch_opt()]) ::
          {:ok, %{session_id: String.t(), task: Task.t()}}
          | {:error, :not_found}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
  def dispatch(task_or_id, opts \\ [])

  def dispatch(%Task{} = task, opts) do
    do_dispatch(task, opts)
  end

  def dispatch(short_id, opts) when is_binary(short_id) do
    case Tasks.get(short_id) do
      {:ok, task} -> do_dispatch(task, opts)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  @spec do_dispatch(Task.t(), [dispatch_opt()]) ::
          {:ok, %{session_id: String.t(), task: Task.t()}}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
  defp do_dispatch(task, opts) do
    override_agent = Keyword.get(opts, :agent_slug)
    override_runtime = Keyword.get(opts, :runtime_type)

    with {:ok, session_id} <- resolve_session(task, override_agent, override_runtime),
         payload = build_payload(task),
         :ok <- write_to_pty(session_id, payload),
         {:ok, updated_task} <- mark_dispatched(task, session_id) do
      broadcast(updated_task)
      {:ok, %{session_id: session_id, task: updated_task}}
    end
  end

  # ---------------------------------------------------------------------------
  # Session resolution
  # ---------------------------------------------------------------------------

  @spec resolve_session(Task.t(), String.t() | nil, String.t() | nil) ::
          {:ok, String.t()}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
  defp resolve_session(task, override_agent, override_runtime) do
    cond do
      # 1. Task already bound to a session and the pty is alive
      is_binary(task.session_id) and pty_alive?(task.session_id) ->
        {:ok, task.session_id}

      # 2. Resolve via agent slug (override or assignee_id when assignee_type == "agent")
      effective_agent_slug(task, override_agent) != nil ->
        slug = effective_agent_slug(task, override_agent)
        spawn_or_find_session(slug, override_runtime)

      # 3. No target
      true ->
        {:error, :no_target}
    end
  end

  @spec effective_agent_slug(Task.t(), String.t() | nil) :: String.t() | nil
  defp effective_agent_slug(_task, override) when is_binary(override) and override != "",
    do: override

  defp effective_agent_slug(%Task{assignee_type: "agent", assignee_id: id}, _override)
       when is_binary(id) and id != "",
       do: id

  defp effective_agent_slug(_task, _override), do: nil

  @spec pty_alive?(String.t()) :: boolean()
  defp pty_alive?(session_id) do
    case Registry.lookup(PtyRegistry, session_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  # Find a running session for the agent, or spawn a new one.
  @spec spawn_or_find_session(String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, :no_target} | {:error, :runtime_unauthenticated}
  defp spawn_or_find_session(agent_slug, override_runtime) do
    case find_running_session(agent_slug) do
      {:ok, session_id} ->
        {:ok, session_id}

      {:error, :none} ->
        spawn_session_for_agent(agent_slug, override_runtime)
    end
  end

  # Returns the id of an existing running session for this agent that has a live pty.
  @spec find_running_session(String.t()) :: {:ok, String.t()} | {:error, :none}
  defp find_running_session(agent_slug) do
    sessions =
      Repo.all(
        from(s in Session,
          where: s.agent_slug == ^agent_slug and s.status == "running",
          order_by: [desc: s.inserted_at],
          limit: 5
        )
      )

    live = Enum.find(sessions, fn s -> pty_alive?(s.id) end)

    case live do
      nil -> {:error, :none}
      session -> {:ok, session.id}
    end
  end

  # Spawns a new session for the agent. Creates the DB row via Sessions.create/1.
  # The pty is NOT started here — the SessionTerminalChannel starts it when the
  # frontend joins `terminal:session:<id>`. Dispatch writes to stdin via PtyBridge
  # only when the pty is already live. For a newly spawned session the pty won't be
  # live until the frontend connects, so we return the session_id and let the
  # status update + broadcast signal the frontend to open the terminal.
  @spec spawn_session_for_agent(String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, :no_target} | {:error, :runtime_unauthenticated}
  defp spawn_session_for_agent(agent_slug, override_runtime) do
    with {:ok, agent} <- Agents.get_by_slug(agent_slug),
         runtime_type = override_runtime || agent.default_runtime,
         {:ok, _env} <- validate_runtime_auth(runtime_type),
         {:ok, session} <-
           Sessions.create(%{
             runtime_type: runtime_type || "claude-local",
             agent_slug: agent_slug,
             cwd: System.user_home() || "/tmp",
             prompt: "",
             metadata: %{"spawned_by" => "dispatcher"}
           }) do
      {:ok, session.id}
    else
      {:error, :not_found} -> {:error, :no_target}
      {:error, :runtime_unauthenticated} -> {:error, :runtime_unauthenticated}
      {:error, _other} -> {:error, :no_target}
    end
  end

  # Returns {:ok, env} if credentials are available or the runtime degrades gracefully.
  # Auth.session_env_for/1 always returns {:ok, map()} — CLI-managed runtimes return
  # {:ok, %{}} when no credential is stored (they use their own stored auth).
  # This wrapper exists so future callers can pattern-match consistently on
  # {:ok, _} | {:error, :runtime_unauthenticated} without knowing Auth's internals.
  @spec validate_runtime_auth(String.t() | nil) ::
          {:ok, map()} | {:error, :runtime_unauthenticated}
  defp validate_runtime_auth(nil), do: {:ok, %{}}

  defp validate_runtime_auth(runtime_type) do
    {:ok, _env} = Auth.session_env_for(runtime_type)
    {:ok, %{}}
  end

  # ---------------------------------------------------------------------------
  # Payload
  # ---------------------------------------------------------------------------

  @spec build_payload(Task.t()) :: String.t()
  defp build_payload(task) do
    description = task.description || ""

    """
    [task dispatch]
    # #{task.title}

    #{description}

    Task ID: #{task.short_id}
    """
  end

  # ---------------------------------------------------------------------------
  # Pty write
  # ---------------------------------------------------------------------------

  @spec write_to_pty(String.t(), String.t()) :: :ok
  defp write_to_pty(session_id, payload) do
    if pty_alive?(session_id) do
      PtyBridge.send_input(session_id, payload <> "\n")
    else
      # Pty not yet live (freshly spawned session). The payload will be delivered
      # once the frontend opens the terminal. Log and continue — not an error.
      Logger.info(
        "[Dispatcher] pty not live for session=#{session_id}, payload deferred until terminal opens"
      )
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Status update
  # ---------------------------------------------------------------------------

  @spec mark_dispatched(Task.t(), String.t()) ::
          {:ok, Task.t()} | {:error, Ecto.Changeset.t()}
  defp mark_dispatched(task, session_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      %{dispatched_at: now, session_id: session_id}
      |> maybe_set_in_progress(task.status)

    task
    |> Task.changeset(attrs)
    |> Canopy.Repo.update()
  end

  @spec maybe_set_in_progress(map(), String.t()) :: map()
  defp maybe_set_in_progress(attrs, "todo"), do: Map.put(attrs, :status, "in_progress")
  defp maybe_set_in_progress(attrs, _status), do: attrs

  # ---------------------------------------------------------------------------
  # Broadcast
  # ---------------------------------------------------------------------------

  @spec broadcast(Task.t()) :: :ok
  defp broadcast(task) do
    topic = "tasks:workspace:#{task.workspace_slug || "default"}"

    Phoenix.PubSub.broadcast(
      Canopy.PubSub,
      topic,
      {:task_dispatched,
       %{task_id: task.short_id, session_id: task.session_id, status: task.status}}
    )

    :ok
  end
end
