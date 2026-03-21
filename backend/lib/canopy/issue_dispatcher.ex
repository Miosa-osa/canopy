defmodule Canopy.IssueDispatcher do
  @moduledoc """
  Subscribes to workspace PubSub topics and auto-dispatches agents
  when issues are assigned to them.

  Lifecycle:
    1. On init, subscribe to all existing workspace topics
    2. Listen for "issue.assigned" events
    3. Validate agent readiness (status, concurrent runs)
    4. Build context string from issue + goal
    5. Spawn heartbeat via Task.Supervisor
  """
  use GenServer
  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Issue, Workspace}
  import Ecto.Query

  # ── Client API ────────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Subscribe to a new workspace topic (call this when a workspace is created)."
  def subscribe_workspace(workspace_id) do
    GenServer.cast(__MODULE__, {:subscribe, workspace_id})
  end

  @doc "Manually dispatch an issue to its assigned agent."
  def dispatch(issue_id) do
    GenServer.call(__MODULE__, {:dispatch, issue_id})
  catch
    # If the GenServer is not running (e.g. during tests or startup), convert
    # the exit signal into a normal error tuple so callers can handle it cleanly
    # instead of crashing with an unhandled exit.
    :exit, reason -> {:error, {:dispatcher_unavailable, reason}}
  end

  # ── Server Callbacks ──────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    workspace_ids = Repo.all(from w in Workspace, select: w.id)

    for ws_id <- workspace_ids do
      Canopy.EventBus.subscribe(Canopy.EventBus.workspace_topic(ws_id))
    end

    Logger.info("[IssueDispatcher] Subscribed to #{length(workspace_ids)} workspace topics")
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:subscribe, workspace_id}, state) do
    Canopy.EventBus.subscribe(Canopy.EventBus.workspace_topic(workspace_id))
    Logger.info("[IssueDispatcher] Subscribed to workspace #{workspace_id}")
    {:noreply, state}
  end

  # Matches the map broadcast by Work.assign_issue/2 (atom keys).
  @impl true
  def handle_info(%{event: "issue.assigned", issue_id: issue_id, agent_id: agent_id}, state) do
    Logger.info("[IssueDispatcher] issue.assigned — issue=#{issue_id} agent=#{agent_id}")
    do_dispatch(issue_id, agent_id)
    {:noreply, state}
  end

  # Ignore all other PubSub messages.
  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_call({:dispatch, issue_id}, _from, state) do
    result =
      case Repo.get(Issue, issue_id) do
        %Issue{assignee_id: nil} ->
          {:error, :not_assigned}

        %Issue{assignee_id: agent_id} ->
          do_dispatch(issue_id, agent_id)

        nil ->
          {:error, :not_found}
      end

    {:reply, result, state}
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp do_dispatch(issue_id, agent_id) do
    with %Issue{} = issue <- Repo.get(Issue, issue_id) |> Repo.preload([:workspace, goal: :project]),
         %Agent{} = agent <- Repo.get(Agent, agent_id) |> Repo.preload(:workspace),
         :ok <- validate_agent(agent),
         :ok <- validate_issue(issue) do
      context = Canopy.IssueContext.build_context(issue, agent)

      Task.Supervisor.start_child(Canopy.HeartbeatRunner, fn ->
        Canopy.Heartbeat.run(agent_id, context: context, issue_id: issue_id)
      end)

      Logger.info("[IssueDispatcher] Dispatched agent #{agent.name} for issue: #{issue.title}")
      {:ok, :dispatched}
    else
      nil ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.warning("[IssueDispatcher] Skipped dispatch: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp validate_agent(%Agent{status: status}) when status in ["idle", "active"], do: :ok
  defp validate_agent(%Agent{status: status}), do: {:error, {:agent_not_ready, status}}

  defp validate_issue(%Issue{checked_out_by: nil}), do: :ok
  defp validate_issue(%Issue{}), do: {:error, :already_checked_out}

end
