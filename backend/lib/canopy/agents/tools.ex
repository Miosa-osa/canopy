defmodule Canopy.Agents.Tools do
  @moduledoc """
  Agent-to-Canopy orchestration tool dispatcher.

  Agents running in pty sessions call `POST /api/v1/agents/tools/:tool_name`
  which routes here. Each tool is an explicit function. No metaprogramming.

  ## Capability map

  | Tool                  | Required capability  |
  |-----------------------|----------------------|
  | canopy.create_task    | write_tasks          |
  | canopy.create_issue   | write_issues         |
  | canopy.create_goal    | write_tasks          |
  | canopy.update_task    | write_tasks          |
  | canopy.move_card      | write_tasks          |
  | canopy.comment        | write_tasks          |
  | canopy.spawn_session  | spawn_sessions       |
  | canopy.request_review | write_tasks          |
  | canopy.read_task      | read_workspace       |
  | canopy.list_tasks     | read_workspace       |
  | canopy.read_file      | read_workspace       |
  | canopy.search_issues  | read_workspace       |

  ## Governance

  After capability check, each mutating tool runs through
  `Canopy.Governance.Reviewer.maybe_request_review(:tool_call, ...)`. If a
  governance rule matches, execution is suspended and `{:pending_review, id}`
  is returned. The agent polls `GET /api/v1/reviews/:id` and retries on approve.

  ## Audit

  Every execute/3 call — success, error, or pending_review — writes an
  `agent_tool_calls` row via `record_call/5`.
  """

  require Logger

  alias Canopy.Agents
  alias Canopy.Agents.{SpawnPipeline, ToolCall}
  alias Canopy.Governance.Reviewer
  alias Canopy.Issues
  alias Canopy.Repo
  alias Canopy.Runs.Events, as: RunEvents
  alias Canopy.Sessions
  alias Canopy.Tasks

  @type tool_result ::
          {:ok, map()}
          | {:error, String.t()}
          | {:pending_review, String.t()}

  # ---------------------------------------------------------------------------
  # Capability map — tool name → required capability string
  # ---------------------------------------------------------------------------

  @capability_map %{
    "canopy.create_task" => "write_tasks",
    "canopy.create_issue" => "write_issues",
    "canopy.create_goal" => "write_tasks",
    "canopy.update_task" => "write_tasks",
    "canopy.move_card" => "write_tasks",
    "canopy.comment" => "write_tasks",
    "canopy.spawn_session" => "spawn_sessions",
    "canopy.request_review" => "write_tasks",
    "canopy.read_task" => "read_workspace",
    "canopy.list_tasks" => "read_workspace",
    "canopy.read_file" => "read_workspace",
    "canopy.search_issues" => "read_workspace"
  }

  @read_only_defaults ~w(read_workspace)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Dispatches a named tool call on behalf of the given session.

  1. Resolves the session → agent slug.
  2. Loads agent config.capabilities.
  3. Checks required capability. Defaults: read-only tools only.
  4. Runs governance review hook for mutating tools.
  5. Executes the tool.
  6. Records audit row.

  Returns:
  - `{:ok, result_map}`
  - `{:error, reason_string}`
  - `{:pending_review, review_id}`
  """
  @spec execute(String.t(), String.t(), map(), keyword()) :: tool_result()
  def execute(tool_name, session_id, params, opts \\ []) do
    run_id = Keyword.get(opts, :run_id)

    with {:ok, agent_slug} <- resolve_agent(session_id),
         {:ok, agent} <- Agents.get_by_slug(agent_slug),
         :ok <- check_capability(tool_name, agent) do
      run_with_governance(tool_name, session_id, agent_slug, params, run_id: run_id)
    else
      {:error, :not_found} ->
        record_call(tool_name, session_id, "unknown", params, {:error, "session_not_found"},
          run_id: run_id
        )

        {:error, "session not found or no agent assigned"}

      {:error, :unauthorized} ->
        record_call(tool_name, session_id, "unknown", params, {:error, "unauthorized"},
          run_id: run_id
        )

        {:error, "agent lacks capability #{tool_name}"}

      {:error, reason} when is_binary(reason) ->
        record_call(tool_name, session_id, "unknown", params, {:error, reason}, run_id: run_id)
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Tool implementations
  # ---------------------------------------------------------------------------

  defp dispatch("canopy.create_task", _session_id, _agent_slug, params) do
    attrs =
      params
      |> Map.take(
        ~w(title description status priority workspace_slug project_slug assignee_type assignee_id labels)
      )
      |> Map.put_new("workspace_slug", "default")

    case Tasks.create(attrs) do
      {:ok, task} -> {:ok, %{task: task}}
      {:error, cs} -> {:error, format_changeset(cs)}
    end
  end

  defp dispatch("canopy.create_issue", _session_id, _agent_slug, params) do
    attrs =
      params
      |> Map.take(
        ~w(title description status priority workspace_slug project_slug assignee_type assignee_id labels estimate_minutes branch)
      )
      |> Map.put_new("workspace_slug", "default")

    case Issues.create(attrs) do
      {:ok, issue} -> {:ok, %{issue: issue}}
      {:error, cs} -> {:error, format_changeset(cs)}
    end
  end

  defp dispatch("canopy.create_goal", _session_id, _agent_slug, params) do
    attrs =
      params
      |> Map.take(
        ~w(title description status workspace_slug project_slug assignee_type assignee_id target_pct)
      )
      |> Map.put_new("workspace_slug", "default")

    case Canopy.Goals.create(attrs) do
      {:ok, goal} -> {:ok, %{goal: goal}}
      {:error, cs} -> {:error, format_changeset(cs)}
    end
  end

  defp dispatch("canopy.update_task", _session_id, _agent_slug, params) do
    short_id = Map.get(params, "task_id") || Map.get(params, "short_id")

    if is_nil(short_id) do
      {:error, "missing task_id"}
    else
      attrs =
        Map.take(params, ~w(title description status priority assignee_type assignee_id labels))

      case Tasks.update(short_id, attrs) do
        {:ok, task} -> {:ok, %{task: task}}
        {:error, :not_found} -> {:error, "task #{short_id} not found"}
        {:error, cs} -> {:error, format_changeset(cs)}
      end
    end
  end

  defp dispatch("canopy.move_card", _session_id, _agent_slug, params) do
    short_id = Map.get(params, "task_id") || Map.get(params, "short_id")
    status = Map.get(params, "status")

    cond do
      is_nil(short_id) ->
        {:error, "missing task_id"}

      is_nil(status) ->
        {:error, "missing status"}

      true ->
        # Try task first, then issue
        case Tasks.update(short_id, %{"status" => status}) do
          {:ok, task} ->
            {:ok, %{entity: "task", id: short_id, status: task.status}}

          {:error, :not_found} ->
            case Issues.update(short_id, %{"status" => status}) do
              {:ok, issue} -> {:ok, %{entity: "issue", id: short_id, status: issue.status}}
              {:error, :not_found} -> {:error, "#{short_id} not found"}
              {:error, cs} -> {:error, format_changeset(cs)}
            end

          {:error, cs} ->
            {:error, format_changeset(cs)}
        end
    end
  end

  defp dispatch("canopy.comment", session_id, agent_slug, params) do
    body = Map.get(params, "body") || Map.get(params, "message")
    channel_id = Map.get(params, "channel_id")
    target_id = Map.get(params, "task_id") || Map.get(params, "issue_id")

    cond do
      is_nil(body) ->
        {:error, "missing body"}

      is_nil(channel_id) ->
        {:error, "missing channel_id"}

      true ->
        # Resolve target reference as a suffix when provided
        body_with_ref =
          if target_id, do: "#{body}\n\n> ref: #{target_id}", else: body

        msg_attrs = %{
          "channel_id" => channel_id,
          "body_markdown" => body_with_ref,
          "actor_type" => "agent",
          "actor_id" => agent_slug,
          "session_id" => session_id
        }

        case Canopy.Channels.create_message(msg_attrs) do
          {:ok, msg} -> {:ok, %{message_id: msg.id, channel_id: channel_id}}
          {:error, cs} -> {:error, format_changeset(cs)}
        end
    end
  end

  defp dispatch("canopy.spawn_session", parent_session_id, agent_slug, params) do
    runtime = Map.get(params, "runtime") || "claude-local"
    prompt = Map.get(params, "prompt") || ""
    child_agent = Map.get(params, "agent_slug") || agent_slug
    workspace = Map.get(params, "workspace_slug") || "default"
    wake_reason = Map.get(params, "wake_reason") || "user_prompt"

    # Check if the target agent requires hire approval.
    requires_approval =
      case Agents.get_by_slug(child_agent) do
        {:ok, agent} ->
          get_in(agent.config || %{}, ["requires_hire_approval"]) == true

        _ ->
          false
      end

    if requires_approval do
      case Canopy.Reviews.request_hire_agent(
             parent_session_id,
             child_agent,
             prompt,
             %{"runtime" => runtime, "workspace_slug" => workspace, "wake_reason" => wake_reason},
             workspace_slug: workspace
           ) do
        {:ok, review} ->
          {:pending_review, review.id}

        {:error, cs} ->
          {:error, format_changeset(cs)}
      end
    else
      session_attrs = %{
        runtime_type: runtime,
        agent_slug: child_agent,
        workspace_slug: workspace,
        prompt: prompt,
        cwd: Map.get(params, "cwd", "/tmp")
      }

      # Route through SpawnPipeline so the sub-agent gets the full runtime
      # integration (run record, CANOPY_* vars, skills, worktree).
      with {:ok, session} <- Sessions.create(session_attrs),
           {:ok, result} <-
             SpawnPipeline.spawn(session,
               wake_reason: wake_reason,
               parent_session_id: parent_session_id
             ) do
        {:ok,
         %{
           session_id: session.id,
           run_id: result.run.short_id,
           agent_slug: child_agent,
           status: result.session.status
         }}
      else
        {:error, %Ecto.Changeset{} = cs} ->
          {:error, format_changeset(cs)}

        {:error, reason} ->
          {:error, inspect(reason)}

        {:error, _stage, reason} ->
          {:error, inspect(reason)}
      end
    end
  end

  defp dispatch("canopy.request_review", session_id, agent_slug, params) do
    workspace_slug = Map.get(params, "workspace_slug", "default")

    result =
      case Map.get(params, "kind", "tool_call") do
        "artifact" ->
          params
          |> Map.take(~w(workspace_slug artifact_type artifact_id artifact_preview))
          |> Map.put_new("workspace_slug", workspace_slug)
          |> Map.put("agent_id", agent_slug)
          |> Canopy.Reviews.request_artifact()

        _ ->
          tool_name = Map.get(params, "tool_name", "unknown")
          tool_args = Map.get(params, "tool_args", %{})

          Canopy.Reviews.request_tool_call(session_id, tool_name, tool_args,
            workspace_slug: workspace_slug,
            agent_id: agent_slug
          )
      end

    case result do
      {:ok, review} ->
        {:ok,
         %{
           review_id: review.id,
           status: review.status,
           kind: review.kind,
           workspace_slug: review.workspace_slug,
           agent_id: review.agent_id
         }}

      {:error, cs} ->
        {:error, format_changeset(cs)}
    end
  end

  defp dispatch("canopy.read_task", _session_id, _agent_slug, params) do
    short_id = Map.get(params, "task_id") || Map.get(params, "short_id")

    case Tasks.get(short_id) do
      {:ok, task} -> {:ok, %{task: task}}
      {:error, :not_found} -> {:error, "task #{short_id} not found"}
    end
  end

  defp dispatch("canopy.list_tasks", _session_id, _agent_slug, params) do
    filters =
      %{}
      |> maybe_put_filter(params, "status", :status)
      |> maybe_put_filter(params, "assignee_id", :assignee_id)
      |> maybe_put_filter(params, "workspace_slug", :workspace_slug)
      |> maybe_put_filter(params, "project_slug", :project_slug)
      |> maybe_put_limit(params)

    tasks = Tasks.list(filters)
    {:ok, %{tasks: tasks, count: length(tasks)}}
  end

  defp dispatch("canopy.read_file", _session_id, _agent_slug, params) do
    path = Map.get(params, "path")

    if is_nil(path) do
      {:error, "missing path"}
    else
      case File.read(path) do
        {:ok, content} -> {:ok, %{path: path, content: content, size: byte_size(content)}}
        {:error, reason} -> {:error, "cannot read #{path}: #{reason}"}
      end
    end
  end

  defp dispatch("canopy.search_issues", _session_id, _agent_slug, params) do
    filters =
      %{}
      |> maybe_put_filter(params, "q", :query)
      |> maybe_put_filter(params, "status", :status)
      |> maybe_put_filter(params, "workspace_slug", :workspace_slug)
      |> maybe_put_limit(params)

    issues = Issues.list(filters)
    {:ok, %{issues: issues, count: length(issues)}}
  end

  defp dispatch(tool_name, _session_id, _agent_slug, _params) do
    {:error, "unknown tool: #{tool_name}"}
  end

  # ---------------------------------------------------------------------------
  # Governance + execution pipeline
  # ---------------------------------------------------------------------------

  @read_tools ~w(canopy.read_task canopy.list_tasks canopy.read_file canopy.search_issues)

  defp run_with_governance(tool_name, session_id, agent_slug, params, opts)
       when tool_name in @read_tools do
    # Read tools skip governance — no side effects
    result = dispatch_with_events(tool_name, session_id, agent_slug, params, opts)
    record_call(tool_name, session_id, agent_slug, params, result, opts)
    result
  end

  defp run_with_governance(tool_name, session_id, agent_slug, params, opts) do
    workspace_slug = Map.get(params, "workspace_slug", "default")

    governance_attrs = %{
      session_id: session_id,
      agent_id: agent_slug,
      tool_name: tool_name,
      tool_args: params,
      workspace_slug: workspace_slug
    }

    case Reviewer.maybe_request_review(:tool_call, governance_attrs) do
      {:review_pending, review_id} ->
        result = {:pending_review, review_id}

        record_call(
          tool_name,
          session_id,
          agent_slug,
          params,
          result,
          Keyword.put(opts, :review_id, review_id)
        )

        result

      :no_review_required ->
        result = dispatch_with_events(tool_name, session_id, agent_slug, params, opts)
        record_call(tool_name, session_id, agent_slug, params, result, opts)
        result
    end
  end

  # Wraps dispatch with run_tool_call / run_tool_result broadcasts.
  # Only emits when a run_id is present in opts — plain HTTP calls without a
  # run context produce no events.
  defp dispatch_with_events(tool_name, session_id, agent_slug, params, opts) do
    run_id = Keyword.get(opts, :run_id)
    at = DateTime.to_iso8601(DateTime.utc_now())

    if run_id do
      run_info = fetch_run_info(run_id)

      RunEvents.run_tool_call(%{
        run_id: run_id,
        short_id: run_info.short_id,
        workspace_slug: run_info.workspace_slug,
        tool_name: tool_name,
        params: params,
        at: at
      })
    end

    result = dispatch(tool_name, session_id, agent_slug, params)

    if run_id do
      run_info = fetch_run_info(run_id)
      result_payload = extract_result_payload(result)

      RunEvents.run_tool_result(%{
        run_id: run_id,
        short_id: run_info.short_id,
        workspace_slug: run_info.workspace_slug,
        tool_name: tool_name,
        result: result_payload,
        at: DateTime.to_iso8601(DateTime.utc_now())
      })
    end

    result
  end

  # Lightweight run lookup for event payloads — best-effort; never blocks.
  defp fetch_run_info(run_id) do
    case Canopy.Runs.get(run_id) do
      {:ok, run} ->
        %{short_id: run.short_id, workspace_slug: run.workspace_slug || "default"}

      _ ->
        %{short_id: run_id, workspace_slug: "default"}
    end
  end

  defp extract_result_payload({:ok, data}), do: data
  defp extract_result_payload({:error, msg}), do: %{error: msg}
  defp extract_result_payload({:pending_review, id}), do: %{pending_review: id}

  # ---------------------------------------------------------------------------
  # Capability check
  # ---------------------------------------------------------------------------

  defp check_capability(tool_name, agent) do
    required = Map.get(@capability_map, tool_name)

    if is_nil(required) do
      {:error, "unknown tool: #{tool_name}"}
    else
      capabilities = get_in(agent.config || %{}, ["capabilities"]) || @read_only_defaults

      if required in capabilities do
        :ok
      else
        {:error, :unauthorized}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Agent resolution
  # ---------------------------------------------------------------------------

  defp resolve_agent(session_id) do
    case Sessions.get(session_id) do
      {:ok, session} when is_binary(session.agent_slug) ->
        {:ok, session.agent_slug}

      {:ok, _session} ->
        {:error, "session has no agent_slug"}

      {:error, _} ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Audit recording
  # ---------------------------------------------------------------------------

  defp record_call(tool_name, session_id, agent_slug, params, result, extra) do
    review_id = Keyword.get(extra, :review_id)
    run_id = Keyword.get(extra, :run_id)

    {status, result_map, error_text} =
      case result do
        {:ok, data} -> {"ok", data, nil}
        {:error, msg} -> {"error", nil, to_string(msg)}
        {:pending_review, _} -> {"pending_review", nil, nil}
      end

    attrs = %{
      session_id: session_id,
      run_id: run_id,
      agent_id: to_string(agent_slug),
      tool_name: tool_name,
      params: params,
      result: result_map,
      status: status,
      error: error_text,
      review_id: review_id,
      inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case %ToolCall{} |> ToolCall.changeset(attrs) |> Repo.insert() do
      {:ok, _} ->
        :ok

      {:error, cs} ->
        Logger.warning("[AgentTools] Failed to record tool call audit: #{inspect(cs.errors)}")
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp format_changeset(%Ecto.Changeset{} = cs) do
    cs.errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
    |> Enum.join(", ")
  end

  defp maybe_put_filter(acc, params, key, filter_key) do
    case Map.get(params, key) do
      nil -> acc
      val -> Map.put(acc, filter_key, val)
    end
  end

  defp maybe_put_limit(acc, params) do
    case Map.get(params, "limit") do
      nil -> acc
      val when is_integer(val) -> Map.put(acc, :limit, val)
      val when is_binary(val) -> Map.put(acc, :limit, String.to_integer(val))
    end
  end
end
