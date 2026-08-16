defmodule Canopy.Issues.Dispatcher do
  @moduledoc """
  Dispatches an issue to a live agent terminal session.

  Identical resolution logic to `Canopy.Tasks.Dispatcher` — not abstracted
  into a shared module intentionally. Both contexts own their dispatch path.

  ## Resolution order

  1. `issue.session_id` is set and the pty process is alive → append to existing session.
  2. `issue.assignee_type == "agent"` → find the agent's running session, or spawn a new
     one bound to the agent's `default_runtime`. Updates `issue.session_id` on success.
  3. No resolvable target → `{:error, :no_target}`.

  ## PubSub contract

  On success, broadcasts on topic `issues:workspace:<workspace_slug>`:

      {:issue_dispatched, %{issue_id: short_id, session_id: session_id, status: "in_progress"}}
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents
  alias Canopy.Issues.Issue
  alias Canopy.Repo
  alias Canopy.Runtimes.Auth
  alias Canopy.Sessions
  alias Canopy.Sessions.{PtyBridge, PtyRegistry, Session}

  require Logger

  @type dispatch_opt :: {:agent_slug, String.t()} | {:runtime_type, String.t()}

  @doc """
  Dispatches the issue identified by `issue_or_id` to a live agent terminal.
  Returns `{:ok, %{session_id: id, issue: %Issue{}}}` on success.
  """
  @spec dispatch(Issue.t() | String.t(), [dispatch_opt()]) ::
          {:ok, %{session_id: String.t(), issue: Issue.t()}}
          | {:error, :not_found}
          | {:error, :no_target}
          | {:error, :runtime_unauthenticated}
  def dispatch(issue_or_id, opts \\ [])

  def dispatch(%Issue{} = issue, opts) do
    do_dispatch(issue, opts)
  end

  def dispatch(id, opts) when is_binary(id) do
    case Canopy.Issues.get(id) do
      {:ok, issue} -> do_dispatch(issue, opts)
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal
  # ---------------------------------------------------------------------------

  defp do_dispatch(issue, opts) do
    override_agent = Keyword.get(opts, :agent_slug)
    override_runtime = Keyword.get(opts, :runtime_type)

    with {:ok, session_id} <- resolve_session(issue, override_agent, override_runtime),
         payload = build_payload(issue),
         :ok <- write_to_pty(session_id, payload),
         {:ok, updated_issue} <- mark_dispatched(issue, session_id) do
      broadcast(updated_issue)
      {:ok, %{session_id: session_id, issue: updated_issue}}
    end
  end

  defp resolve_session(issue, override_agent, override_runtime) do
    cond do
      is_binary(issue.session_id) and pty_alive?(issue.session_id) ->
        {:ok, issue.session_id}

      effective_agent_slug(issue, override_agent) != nil ->
        slug = effective_agent_slug(issue, override_agent)
        spawn_or_find_session(slug, override_runtime)

      true ->
        {:error, :no_target}
    end
  end

  defp effective_agent_slug(_issue, override) when is_binary(override) and override != "",
    do: override

  defp effective_agent_slug(%Issue{assignee_type: "agent", assignee_id: id}, _override)
       when is_binary(id) and id != "",
       do: id

  defp effective_agent_slug(_issue, _override), do: nil

  defp pty_alive?(session_id) do
    case Registry.lookup(PtyRegistry, session_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp spawn_or_find_session(agent_slug, override_runtime) do
    case find_running_session(agent_slug) do
      {:ok, session_id} -> {:ok, session_id}
      {:error, :none} -> spawn_session_for_agent(agent_slug, override_runtime)
    end
  end

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
             metadata: %{"spawned_by" => "issues_dispatcher"}
           }) do
      {:ok, session.id}
    else
      {:error, :not_found} -> {:error, :no_target}
      {:error, :runtime_unauthenticated} -> {:error, :runtime_unauthenticated}
      {:error, _other} -> {:error, :no_target}
    end
  end

  defp validate_runtime_auth(nil), do: {:ok, %{}}

  defp validate_runtime_auth(runtime_type) do
    {:ok, _env} = Auth.session_env_for(runtime_type)
    {:ok, %{}}
  end

  defp build_payload(issue) do
    description = issue.description || ""

    """
    [issue dispatch]
    # #{issue.title}

    #{description}

    Issue ID: #{issue.short_id}
    """
  end

  defp write_to_pty(session_id, payload) do
    if pty_alive?(session_id) do
      PtyBridge.send_input(session_id, payload <> "\n")
    else
      Logger.info(
        "[Issues.Dispatcher] pty not live for session=#{session_id}, payload deferred until terminal opens"
      )
    end

    :ok
  end

  defp mark_dispatched(issue, session_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs =
      %{dispatched_at: now, session_id: session_id}
      |> maybe_set_in_progress(issue.status)

    issue
    |> Issue.changeset(attrs)
    |> Canopy.Repo.update()
  end

  defp maybe_set_in_progress(attrs, "open"), do: Map.put(attrs, :status, "in_progress")
  defp maybe_set_in_progress(attrs, "backlog"), do: Map.put(attrs, :status, "in_progress")
  defp maybe_set_in_progress(attrs, _status), do: attrs

  defp broadcast(issue) do
    topic = "issues:workspace:#{issue.workspace_slug || "default"}"

    Phoenix.PubSub.broadcast(
      Canopy.PubSub,
      topic,
      {:issue_dispatched,
       %{issue_id: issue.short_id, session_id: issue.session_id, status: issue.status}}
    )

    :ok
  end
end
