defmodule CanopyWeb.RuntimeAdapterController do
  @moduledoc """
  HTTP API for the Runtime Adapter Agent.

  This controller is *additive* to `RuntimesController`: that one owns the raw
  detection / preflight / config-schema surface; this one exposes the
  agent-driven operations layered on top of it (rich models, role binding,
  checkpointing, suggestion).

  Routes (under `/api/v1/runtime-adapter`):

      GET    /models?runtime_id=...                — list models with ModelInfo
      GET    /roles?runtime=...&role=...           — list role assignments
      POST   /roles                                — assign or update a role
      GET    /checkpoints?session_id=...           — list checkpoints
      POST   /checkpoints                          — create a checkpoint
      POST   /checkpoints/:id/restore              — restore a checkpoint
      POST   /suggestions                          — suggest runtime for a task
      POST   /swap                                 — mid-session hot-swap
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Runtimes.AdapterAgent
  alias CanopyWeb.Schemas.RuntimeAdapterSchema

  action_fallback CanopyWeb.FallbackController

  tags ["runtime-adapter"]

  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  @runtime_id_regex ~r/\A[a-z0-9][a-z0-9_-]{0,63}\z/
  @valid_roles ~w(chat autocomplete edit apply embed rerank summarize)
  @max_limit 200
  @default_limit 50

  # ---------------------------------------------------------------------------
  # Models
  # ---------------------------------------------------------------------------

  operation :models,
    summary: "List models exposed by a runtime with ModelInfo metadata",
    parameters: [
      runtime_id: [in: :query, type: :string, required: true]
    ],
    responses: [
      ok: {"Model list", "application/json", RuntimeAdapterSchema.ModelList}
    ]

  @spec models(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def models(conn, %{"runtime_id" => runtime_id}) do
    with :ok <- validate_runtime_id(runtime_id),
         {:ok, models} <- AdapterAgent.list_models_with_info(runtime_id) do
      json(conn, %{runtime_id: runtime_id, models: models})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "runtime_not_found"})

      {:error, reason} ->
        bad_request(conn, reason)
    end
  end

  def models(conn, _), do: bad_request(conn, "runtime_id is required")

  # ---------------------------------------------------------------------------
  # Roles
  # ---------------------------------------------------------------------------

  operation :roles_index,
    summary: "List model role assignments",
    parameters: [
      runtime: [in: :query, type: :string, required: false],
      role: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false]
    ],
    responses: [
      ok: {"Role list", "application/json", RuntimeAdapterSchema.ModelRoleList}
    ]

  @spec roles_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def roles_index(conn, params) do
    with :ok <- validate_role_opt(params["role"]) do
      opts =
        []
        |> maybe_put(:runtime, params["runtime"])
        |> maybe_put(:role, params["role"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])

      json(conn, %{data: AdapterAgent.list_roles(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :roles_create,
    summary: "Assign or update a model role",
    request_body: {"Role assignment", "application/json", RuntimeAdapterSchema.RoleAssignment},
    responses: [
      created: {"Role", "application/json", RuntimeAdapterSchema.ModelRole}
    ]

  @spec roles_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def roles_create(conn, params) do
    with {:ok, runtime} <- require_string(params["runtime"], "runtime"),
         :ok <- validate_runtime_id(runtime),
         {:ok, model} <- require_string(params["model"], "model"),
         {:ok, role} <- validate_role(params["role"]) do
      opts =
        []
        |> maybe_put(:default_for_role, params["default_for_role"])
        |> maybe_put(:priority, params["priority"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:metadata, params["metadata"])

      case AdapterAgent.assign_role(runtime, model, role, opts) do
        {:ok, role_row} ->
          conn |> put_status(:created) |> json(role_row)

        {:error, %Ecto.Changeset{} = cs} ->
          {:error, cs}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Checkpoints
  # ---------------------------------------------------------------------------

  operation :checkpoints_index,
    summary: "List checkpoints for a session",
    parameters: [
      session_id: [in: :query, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Checkpoint list", "application/json", RuntimeAdapterSchema.CheckpointList}
    ]

  @spec checkpoints_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def checkpoints_index(conn, %{"session_id" => session_id} = params) do
    with {:ok, session_id} <- validate_uuid(session_id, "session_id") do
      opts = [limit: parse_limit(params["limit"])]
      checkpoints = AdapterAgent.list_checkpoints(session_id, opts)
      json(conn, %{session_id: session_id, count: length(checkpoints), data: checkpoints})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  def checkpoints_index(conn, _), do: bad_request(conn, "session_id is required")

  operation :checkpoints_create,
    summary: "Create a session checkpoint",
    request_body:
      {"Checkpoint create", "application/json", RuntimeAdapterSchema.CheckpointCreate},
    responses: [
      created: {"Checkpoint", "application/json", RuntimeAdapterSchema.Checkpoint}
    ]

  @spec checkpoints_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def checkpoints_create(conn, params) do
    with {:ok, session_id} <- require_string(params["session_id"], "session_id"),
         {:ok, session_id} <- validate_uuid(session_id, "session_id"),
         {:ok, runtime} <- require_string(params["runtime"], "runtime"),
         :ok <- validate_runtime_id(runtime) do
      attrs = %{
        session_id: session_id,
        runtime: runtime,
        label: params["label"],
        code_hash: params["code_hash"],
        transcript_id: params["transcript_id"],
        transcript_sequence: params["transcript_sequence"],
        agent_memory: params["agent_memory"] || %{},
        workspace_slug: params["workspace_slug"]
      }

      case AdapterAgent.create_checkpoint(attrs) do
        {:ok, cp} -> conn |> put_status(:created) |> json(cp)
        {:error, %Ecto.Changeset{} = cs} -> {:error, cs}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :checkpoints_restore,
    summary: "Restore a session to a checkpoint",
    parameters: [
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Restore result", "application/json", RuntimeAdapterSchema.Checkpoint}
    ]

  @spec checkpoints_restore(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def checkpoints_restore(conn, %{"id" => id} = params) do
    with {:ok, id} <- validate_uuid(id, "checkpoint_id") do
      opts =
        []
        |> maybe_put(:current_memory, params["current_memory"])
        |> maybe_put(:agent_id, params["agent_id"])

      case AdapterAgent.restore_checkpoint(id, opts) do
        {:ok, %{pre_restore: pre, restored: restored}} ->
          json(conn, %{
            ok: true,
            new_checkpoint_id: pre.id,
            restored_checkpoint_id: restored.id
          })

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "checkpoint_not_found"})

        {:error, reason} ->
          bad_request(conn, inspect(reason))
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Suggestions + swap
  # ---------------------------------------------------------------------------

  operation :suggestions,
    summary: "Suggest a runtime for a task",
    request_body:
      {"Suggestion query", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           task_hints: %OpenApiSpex.Schema{type: :object, additionalProperties: true},
           limit: %OpenApiSpex.Schema{type: :integer}
         },
         required: [:task_hints]
       }},
    responses: [
      ok: {"Suggestions", "application/json", RuntimeAdapterSchema.SuggestionList}
    ]

  @spec suggestions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def suggestions(conn, params) do
    hints = parse_hints(params["task_hints"] || %{})
    limit = parse_limit(params["limit"], 3)

    {:ok, ranked} = AdapterAgent.suggest_runtime_for_task(hints, limit: limit)
    json(conn, %{count: length(ranked), suggestions: ranked})
  end

  operation :swap,
    summary: "Mid-session hot-swap to a target runtime",
    request_body: {"Swap request", "application/json", RuntimeAdapterSchema.SwapRequest},
    responses: [
      ok: {"Swap result", "application/json", RuntimeAdapterSchema.Checkpoint}
    ]

  @spec swap(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def swap(conn, params) do
    with {:ok, session_id} <- require_string(params["session_id"], "session_id"),
         {:ok, session_id} <- validate_uuid(session_id, "session_id"),
         {:ok, current} <- require_string(params["current_runtime"], "current_runtime"),
         :ok <- validate_runtime_id(current),
         {:ok, target} <- require_string(params["target_runtime"], "target_runtime"),
         :ok <- validate_runtime_id(target) do
      opts =
        []
        |> maybe_put(:agent_id, params["agent_id"])
        |> maybe_put(:agent_memory, params["agent_memory"])

      case AdapterAgent.swap_runtime(session_id, current, target, opts) do
        {:ok, %{checkpoint: cp}} ->
          json(conn, %{
            ok: true,
            checkpoint_id: cp.id,
            target: target,
            captured_at: cp.captured_at
          })

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "unknown_target", target: target})

        {:error, reason} ->
          bad_request(conn, inspect(reason))
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp require_string(nil, name), do: {:error, "#{name} is required"}
  defp require_string("", name), do: {:error, "#{name} cannot be empty"}
  defp require_string(value, _name) when is_binary(value), do: {:ok, value}
  defp require_string(_, name), do: {:error, "#{name} must be a string"}

  defp validate_runtime_id(id) when is_binary(id) do
    if Regex.match?(@runtime_id_regex, id) do
      :ok
    else
      {:error,
       "invalid runtime_id: must be lowercase alphanumeric, dashes, underscores; max 64 chars"}
    end
  end

  defp validate_runtime_id(_), do: {:error, "runtime_id must be a string"}

  defp validate_role(role) when role in @valid_roles, do: {:ok, role}
  defp validate_role(_), do: {:error, "role must be one of #{Enum.join(@valid_roles, ", ")}"}

  defp validate_role_opt(nil), do: :ok
  defp validate_role_opt(""), do: :ok

  defp validate_role_opt(role) when role in @valid_roles, do: :ok
  defp validate_role_opt(_), do: {:error, "invalid role"}

  defp validate_uuid(str, field_name) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid #{field_name}: must be a UUID"}
    end
  end

  defp validate_uuid(_, field_name), do: {:error, "invalid #{field_name}"}

  defp parse_limit(value, default \\ @default_limit)
  defp parse_limit(nil, default), do: default
  defp parse_limit("", default), do: default

  defp parse_limit(n, _default) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> default
    end
  end

  defp parse_limit(_, default), do: default

  defp parse_hints(map) when is_map(map) do
    %{
      language: map["language"],
      requires: map["requires"] || [],
      est_tokens: map["est_tokens"]
    }
  end

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
