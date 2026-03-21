defmodule Canopy.Heartbeat do
  @moduledoc """
  Executes a heartbeat run for an agent.

  Lifecycle:
    1. Resolve adapter from agent config
    2. Create session record
    3. Optionally checkout an issue (set status to "in_progress")
    4. Optionally create git worktree execution workspace
    5. Execute heartbeat via adapter — streams events
    6. Persist each event to DB and broadcast to PubSub
    7. Update session with final token counts and cost
    8. Record cost with BudgetEnforcer
    9. Cleanup workspace and reset agent status
   10. Mark issue as done and create WorkProduct record (if issue_id provided)
  """
  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.{Agent, Session, SessionEvent, Workspace, WorkProduct}
  import Ecto.Changeset, only: [change: 2]

  @doc """
  Run a heartbeat for the given agent.

  ## Options
    - `:schedule_id` — UUID of the triggering schedule (optional)
    - `:session_id`  — UUID of an already-created session row (optional).
                       When provided, Heartbeat reuses that row rather than
                       inserting a new one.  SpawnController uses this to
                       avoid the duplicate-session bug.
    - `:context`     — instruction string passed to the adapter (default: generic heartbeat prompt)
    - `:issue_id`    — UUID of an issue to checkout before execution and complete after (optional)
  """
  def run(agent_id, opts \\ []) do
    schedule_id = opts[:schedule_id]
    existing_session_id = opts[:session_id]
    context = opts[:context] || "Perform your scheduled heartbeat."
    issue_id = opts[:issue_id]

    with %Agent{} = agent <- Repo.get(Agent, agent_id),
         {:ok, adapter_mod} <- Canopy.Adapter.resolve(agent.adapter) do
      session =
        if existing_session_id do
          Repo.get!(Session, existing_session_id)
        else
          create_session!(agent, schedule_id)
        end

      agent |> change(status: "working") |> Repo.update!()

      broadcast_workspace(agent, %{
        event: "run.started",
        agent_id: agent.id,
        session_id: session.id,
        agent_name: agent.name
      })

      if issue_id do
        case Repo.get(Canopy.Schemas.Issue, issue_id) do
          nil ->
            Logger.warning("[Heartbeat] Issue #{issue_id} not found, skipping checkout")

          issue ->
            issue |> change(status: "in_progress", checked_out_by: agent.id) |> Repo.update!()
            Logger.info("[Heartbeat] Checked out issue #{issue_id} for agent #{agent.name}")
        end
      end

      workspace = resolve_workspace(agent)

      # Prepend system prompt to context if agent has one
      full_context =
        if agent.system_prompt && agent.system_prompt != "" do
          "#{agent.system_prompt}\n\n---\n\n#{context}"
        else
          context
        end

      params = %{
        "context" => full_context,
        "model" => agent.model,
        "working_dir" => workspace.path,
        "workspace_path" => workspace.path,
        "url" => agent.config["url"]
      }

      Logger.info("[Heartbeat] Executing agent #{agent.name} (#{agent.id}) via #{agent.adapter} in #{workspace.path}")

      totals =
        try do
          execute_and_stream(adapter_mod, params, session, agent)
        rescue
          e ->
            Logger.error("[Heartbeat] FATAL: #{Exception.message(e)}\n#{Exception.format_stacktrace(__STACKTRACE__)}")
            fail_session!(session, Exception.message(e))
            agent |> change(status: "error") |> Repo.update!()

            if issue_id do
              case Repo.get(Canopy.Schemas.Issue, issue_id) do
                nil ->
                  :ok

                issue ->
                  issue |> change(status: "backlog", checked_out_by: nil) |> Repo.update!()
                  Logger.info("[Heartbeat] Rolled back issue #{issue_id} to backlog after failure")
              end
            end

            broadcast_workspace(agent, %{event: "run.failed", agent_id: agent.id, session_id: session.id, error: Exception.message(e)})
            raise e
        end

      complete_session!(session, totals)
      agent |> change(status: "idle") |> Repo.update!()

      if issue_id do
        case Repo.get(Canopy.Schemas.Issue, issue_id) do
          nil ->
            Logger.warning("[Heartbeat] Issue #{issue_id} not found, skipping completion")

          issue ->
            issue |> change(status: "done", checked_out_by: nil) |> Repo.update!()
            Logger.info("[Heartbeat] Marked issue #{issue_id} as done")

            %WorkProduct{}
            |> WorkProduct.changeset(%{
              title: "Heartbeat output for issue #{issue_id}",
              product_type: "heartbeat",
              issue_id: issue_id,
              session_id: session.id,
              agent_id: agent.id,
              workspace_id: agent.workspace_id
            })
            |> Repo.insert()
            |> case do
              {:ok, wp} ->
                Logger.info("[Heartbeat] Created WorkProduct #{wp.id} for issue #{issue_id}")

              {:error, changeset} ->
                Logger.warning("[Heartbeat] Failed to create WorkProduct for issue #{issue_id}: #{inspect(changeset.errors)}")
            end
        end
      end

      cleanup_workspace(workspace)

      if totals.cost > 0 do
        Canopy.BudgetEnforcer.record_cost(%{
          agent_id: agent.id,
          session_id: session.id,
          model: agent.model,
          tokens_input: totals.input,
          tokens_output: totals.output,
          cost_cents: totals.cost
        })
      end

      broadcast_workspace(agent, %{
        event: "run.completed",
        agent_id: agent.id,
        session_id: session.id,
        agent_name: agent.name,
        cost_cents: totals.cost
      })

      {:ok, session.id}
    else
      nil -> {:error, :agent_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp create_session!(agent, schedule_id) do
    %Session{}
    |> Session.changeset(%{
      agent_id: agent.id,
      schedule_id: schedule_id,
      model: agent.model,
      status: "active",
      started_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end

  defp complete_session!(session, totals) do
    session
    |> change(%{
      status: "completed",
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      tokens_input: totals.input,
      tokens_output: totals.output,
      cost_cents: totals.cost
    })
    |> Repo.update!()
  end

  defp fail_session!(session, reason) do
    session
    |> change(%{
      status: "failed",
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()

    Logger.error("[Heartbeat] Session #{session.id} failed: #{reason}")
  end

  # Returns a map with :path and :strategy keys.
  # Looks up the actual workspace path from the DB instead of using CWD.
  defp resolve_workspace(agent) do
    workspace_path =
      case Repo.get(Workspace, agent.workspace_id) do
        %Workspace{path: path} when is_binary(path) and path != "" -> path
        _ -> raise "No workspace path found for agent #{agent.id} (workspace_id: #{inspect(agent.workspace_id)}). Cannot execute without a valid workspace."
      end

    Logger.info("[Heartbeat] Resolved workspace path: #{workspace_path} for agent #{agent.id}")

    if agent.config["workspace_strategy"] == "shared" do
      %{path: workspace_path, strategy: :shared}
    else
      case Canopy.ExecutionWorkspace.create(workspace_path, strategy: :worktree) do
        {:ok, ws} -> ws
        {:error, reason} ->
          Logger.warning("[Heartbeat] Worktree creation failed (#{inspect(reason)}), using shared workspace")
          %{path: workspace_path, strategy: :shared}
      end
    end
  end

  defp cleanup_workspace(%{strategy: :shared}), do: :ok

  defp cleanup_workspace(workspace) do
    Canopy.ExecutionWorkspace.cleanup(workspace)
  end

  defp execute_and_stream(adapter_mod, params, session, agent) do
    try do
      adapter_mod.execute_heartbeat(params)
      |> Enum.reduce(%{input: 0, output: 0, cost: 0}, fn event, acc ->
        persist_event!(event, session)

        Canopy.EventBus.broadcast(
          Canopy.EventBus.session_topic(session.id),
          %{
            event: event.event_type,
            data: event.data,
            session_id: session.id,
            agent_id: agent.id
          }
        )

        tokens = event[:tokens] || 0
        cost = estimate_cost(tokens, agent.model)

        %{acc | input: acc.input + tokens, cost: acc.cost + cost}
      end)
    rescue
      e ->
        Logger.error(
          "[Heartbeat] Execution error for agent #{agent.id}: #{Exception.message(e)}\n" <>
            Exception.format_stacktrace(__STACKTRACE__)
        )

        %{input: 0, output: 0, cost: 0}
    end
  end

  defp persist_event!(event, session) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %SessionEvent{}
    |> SessionEvent.changeset(%{
      session_id: session.id,
      event_type: event.event_type,
      data: event.data,
      tokens: event[:tokens] || 0,
      inserted_at: now
    })
    |> Repo.insert!()
  end

  defp broadcast_workspace(agent, payload) do
    Canopy.EventBus.broadcast(Canopy.EventBus.workspace_topic(agent.workspace_id), payload)
  end

  # Rough cost estimation in cents per 1K tokens.
  # Input/output are billed differently in practice; this uses a blended rate
  # for simplicity. Adjust when per-direction token counts are available.
  defp estimate_cost(tokens, model) do
    rate =
      case model do
        m when m in ["claude-opus-4-6", "claude-opus-4-20250514"] -> 1.5
        m when m in ["claude-sonnet-4-6", "claude-sonnet-4-20250514"] -> 0.3
        m when m in ["claude-haiku-4-5", "claude-haiku-4-5-20251001"] -> 0.08
        _ -> 0.3
      end

    round(tokens / 1000 * rate)
  end
end
