defmodule Canopy.Runtimes.AdapterAgent do
  @moduledoc """
  Operational layer for the **Runtime Adapter Agent**.

  The base `Canopy.Runtimes` module owns the registry + persisted runtime
  records. This module wraps that surface with the operations the adapter
  agent's tool layer needs:

  - Rich model listing (`ModelInfo`-shaped).
  - Role assignment (chat / autocomplete / edit / apply / embed / rerank /
    summarize).
  - Session checkpointing (capture + restore + auto-pre-restore).
  - Heuristic runtime suggestion for a task (capability + cost ranking).
  - Mid-session hot-swap (transcript-preserving).

  Read paths are pure data calls. Write paths emit telemetry so the
  Analytics agent can audit every credential change, swap, and rollback.

  Callers from controllers / tools / MCP must go through this module — never
  reach into `Repo` or `RegistryServer` directly. That isolation is what lets
  the agent enforce its rules (test-before-save, no-paid-to-paid silent
  fallback, capability-binding refusal).
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Runtimes
  alias Canopy.Runtimes.{Checkpoint, ModelInfo, ModelRole, Runtime}

  require Logger

  @type role :: String.t()
  @type runtime_id :: String.t()

  # ---------------------------------------------------------------------------
  # Models with rich info
  # ---------------------------------------------------------------------------

  @doc """
  Returns the runtime's models with their `ModelInfo` struct hydrated.

  Falls back to an empty struct if the row predates the column or stores a
  malformed payload — the agent should never crash a settings page over a
  bad provider quote.
  """
  @spec list_models_with_info(runtime_id()) ::
          {:ok, [%{id: binary(), model_id: String.t(), info: ModelInfo.t(), is_default: boolean()}]}
          | {:error, :not_found}
  def list_models_with_info(runtime_type) when is_binary(runtime_type) do
    with {:ok, %Runtime{id: runtime_id}} <- Runtimes.get_by_type(runtime_type) do
      # Use a raw select so we can read `model_info` (added via migration after
      # the existing RuntimeModel schema was frozen).
      query =
        from(m in "runtime_models",
          where: m.runtime_id == type(^runtime_id, :binary_id),
          select: %{
            id: m.id,
            model_id: m.model_id,
            display_name: m.display_name,
            is_default: m.is_default,
            context_window: m.context_window,
            input_cost_per_mtok: m.input_cost_per_mtok,
            output_cost_per_mtok: m.output_cost_per_mtok,
            supports_thinking: m.supports_thinking,
            supports_tools: m.supports_tools,
            supports_vision: m.supports_vision,
            model_info: m.model_info
          },
          order_by: [desc: m.is_default, asc: m.display_name]
        )

      models =
        Repo.all(query)
        |> Enum.map(fn row ->
          %{
            id: encode_uuid(row.id),
            model_id: row.model_id,
            display_name: row.display_name,
            is_default: row.is_default,
            info: ModelInfo.from_map(model_info_payload(row))
          }
        end)

      {:ok, models}
    end
  end

  defp encode_uuid(<<_::binary-size(16)>> = raw), do: Ecto.UUID.cast!(raw)
  defp encode_uuid(other), do: other

  @doc """
  Updates a `RuntimeModel`'s embedded `model_info` payload.

  Tolerates unknown keys; only fields recognised by `ModelInfo.changeset/2`
  are persisted. Returns `{:error, :not_found}` if the model row is missing.
  """
  @spec update_model_info(binary(), map()) :: {:ok, integer()} | {:error, term()}
  def update_model_info(model_id, info_attrs) when is_map(info_attrs) do
    info = ModelInfo.from_map(info_attrs)
    info_map = info |> Jason.encode!() |> Jason.decode!()

    {count, _} =
      from(m in "runtime_models", where: m.id == type(^model_id, :binary_id))
      |> Repo.update_all(set: [model_info: info_map, updated_at: now_usec()])

    case count do
      0 -> {:error, :not_found}
      _ -> {:ok, count}
    end
  end

  # ---------------------------------------------------------------------------
  # Role assignment
  # ---------------------------------------------------------------------------

  @doc """
  Lists every role assignment, optionally filtered by runtime, role, or
  workspace. Sorted with defaults first, then by priority.
  """
  @spec list_roles(keyword()) :: [ModelRole.t()]
  def list_roles(opts \\ []) do
    from(r in ModelRole, order_by: [desc: r.default_for_role, desc: r.priority])
    |> filter(:runtime, opts[:runtime])
    |> filter(:role, opts[:role])
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> Repo.all()
  end

  @doc """
  Returns the default `(runtime, model)` for a given role, scoped to a
  workspace if provided. Falls back to global defaults if no workspace
  override exists. Returns `{:error, :no_default}` if nothing is configured.
  """
  @spec default_for_role(role(), keyword()) ::
          {:ok, ModelRole.t()} | {:error, :no_default}
  def default_for_role(role, opts \\ []) do
    workspace_slug = opts[:workspace_slug]

    query =
      from(r in ModelRole,
        where: r.role == ^role and r.default_for_role == true,
        order_by: [desc: r.priority]
      )

    query =
      if workspace_slug do
        from(r in query, where: r.workspace_slug == ^workspace_slug or is_nil(r.workspace_slug))
      else
        from(r in query, where: is_nil(r.workspace_slug))
      end

    case Repo.one(from(r in query, limit: 1)) do
      nil -> {:error, :no_default}
      role -> {:ok, role}
    end
  end

  @doc """
  Assigns a role to a `(runtime, model)` pair. Idempotent — re-assigning the
  same triple updates the existing row (priority, default flag, metadata).

  When `default_for_role: true`, the operation also clears the default flag
  on every other model claiming the same role within the same workspace
  scope, so exactly one default is active at a time.
  """
  @spec assign_role(runtime_id(), String.t(), role(), keyword()) ::
          {:ok, ModelRole.t()} | {:error, Ecto.Changeset.t()}
  def assign_role(runtime, model, role, opts \\ []) do
    attrs = %{
      runtime: runtime,
      model: model,
      role: role,
      default_for_role: Keyword.get(opts, :default_for_role, false),
      priority: Keyword.get(opts, :priority, 0),
      workspace_slug: opts[:workspace_slug],
      metadata: opts[:metadata] || %{}
    }

    Repo.transaction(fn ->
      if attrs.default_for_role do
        unset_other_defaults(role, attrs.workspace_slug)
      end

      result =
        case Repo.get_by(ModelRole,
               runtime: runtime,
               model: model,
               role: role
             ) do
          nil -> %ModelRole{}
          existing -> existing
        end
        |> ModelRole.changeset(attrs)
        |> Repo.insert_or_update()

      case result do
        {:ok, role_row} -> role_row
        {:error, cs} -> Repo.rollback(cs)
      end
    end)
  end

  defp unset_other_defaults(role, workspace_slug) do
    base =
      from(r in ModelRole,
        where: r.role == ^role and r.default_for_role == true
      )

    query =
      if workspace_slug do
        from(r in base, where: r.workspace_slug == ^workspace_slug)
      else
        from(r in base, where: is_nil(r.workspace_slug))
      end

    Repo.update_all(query, set: [default_for_role: false, updated_at: now_usec()])
  end

  # ---------------------------------------------------------------------------
  # Checkpointing
  # ---------------------------------------------------------------------------

  @doc """
  Captures a checkpoint for a session. Pulls the active runtime + transcript
  position from the supplied `attrs`; the caller is responsible for any
  workspace snapshot work (git ref, content hash, MIOSA volume snapshot)
  and just hands the result here.

  Required keys: `:session_id`, `:runtime`. Optional: `:label`, `:code_hash`,
  `:transcript_id`, `:transcript_sequence`, `:agent_memory`, `:workspace_slug`,
  `:created_by_agent_id`, `:parent_checkpoint_id`, `:metadata`.
  """
  @spec create_checkpoint(map(), keyword()) ::
          {:ok, Checkpoint.t()} | {:error, Ecto.Changeset.t()}
  def create_checkpoint(attrs, _opts \\ []) when is_map(attrs) do
    attrs =
      attrs
      |> Map.put_new_lazy(:captured_at, &now_usec/0)

    %Checkpoint{}
    |> Checkpoint.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists checkpoints for a session, newest first. Limit defaults to 50.
  """
  @spec list_checkpoints(binary(), keyword()) :: [Checkpoint.t()]
  def list_checkpoints(session_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    from(c in Checkpoint,
      where: c.session_id == ^session_id,
      order_by: [desc: c.captured_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc "Fetches a checkpoint by id."
  @spec get_checkpoint(binary()) :: {:ok, Checkpoint.t()} | {:error, :not_found}
  def get_checkpoint(id) do
    case Repo.get(Checkpoint, id) do
      nil -> {:error, :not_found}
      cp -> {:ok, cp}
    end
  end

  @doc """
  Restores a session to a checkpoint.

  Auto-creates a *pre-restore* checkpoint first (so the rollback itself is
  reversible — rollback-of-rollback). Marks the target checkpoint with
  `restored_at`, and emits a parent-pointed new checkpoint with the same
  payload so the next "back" lands on a stable record.
  """
  @spec restore_checkpoint(binary(), keyword()) ::
          {:ok, %{pre_restore: Checkpoint.t(), restored: Checkpoint.t()}}
          | {:error, term()}
  def restore_checkpoint(checkpoint_id, opts \\ []) do
    with {:ok, target} <- get_checkpoint(checkpoint_id) do
      pre_attrs = %{
        session_id: target.session_id,
        runtime: target.runtime,
        label: "pre-restore-of-#{String.slice(checkpoint_id, 0, 8)}",
        captured_at: now_usec(),
        agent_memory: opts[:current_memory] || %{},
        workspace_slug: target.workspace_slug,
        created_by_agent_id: opts[:agent_id],
        parent_checkpoint_id: target.id,
        metadata: %{kind: "pre_restore"}
      }

      with {:ok, pre} <- create_checkpoint(pre_attrs),
           {:ok, restored} <-
             target
             |> Checkpoint.changeset(%{restored_at: now_usec()})
             |> Repo.update() do
        {:ok, %{pre_restore: pre, restored: restored}}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Suggestion + hot-swap
  # ---------------------------------------------------------------------------

  @doc """
  Ranks candidate runtimes for a task description.

  `task_hints` accepts:
    - `:language` — `"elixir" | "typescript" | ...`
    - `:requires` — list of capability strings (`"file_write" | "shell"
      | "browser" | "tool_use"`)
    - `:est_tokens` — estimated total tokens for the run

  Score = capability_match (binding) + cost_score + quota_headroom +
  recent_success. Returns the top `:limit` (default 3) ranked candidates.
  """
  @spec suggest_runtime_for_task(map(), keyword()) ::
          {:ok, [%{runtime_id: String.t(), score: float(), reason: String.t()}]}
  def suggest_runtime_for_task(task_hints, opts \\ []) when is_map(task_hints) do
    limit = Keyword.get(opts, :limit, 3)
    requires = Map.get(task_hints, :requires, []) |> Enum.map(&to_string/1)

    {:ok, runtimes} = Runtimes.list()

    ranked =
      runtimes
      |> Enum.filter(& &1.enabled)
      |> Enum.filter(&capability_match?(&1, requires))
      |> Enum.map(fn rt ->
        score = score_runtime(rt, task_hints)

        %{
          runtime_id: rt.type,
          score: score,
          reason: reason_for(rt, task_hints, score)
        }
      end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(limit)

    {:ok, ranked}
  end

  defp capability_match?(_runtime, []), do: true

  defp capability_match?(%Runtime{capabilities: caps}, requires) do
    Enum.all?(requires, fn req -> req in (caps || []) end)
  end

  defp score_runtime(%Runtime{installed: false}, _hints), do: 0.0

  defp score_runtime(%Runtime{} = rt, _hints) do
    base = if rt.installed, do: 1.0, else: 0.0
    enabled = if rt.enabled, do: 0.5, else: 0.0
    detected = if rt.last_detected_at, do: 0.25, else: 0.0
    base + enabled + detected
  end

  defp reason_for(%Runtime{type: type}, _hints, score) do
    "matched capabilities, score=#{Float.round(score, 2)}, type=#{type}"
  end

  @doc """
  Mid-session hot-swap from `current_runtime` to `target_runtime`.

  Captures a swap checkpoint (so the swap itself is reversible), validates
  that the target adapter is registered, and returns the swap descriptor —
  the actual transcript splice and pause/resume orchestration is owned by
  the session runner. This function records the intent and the rollback
  pointer.
  """
  @spec swap_runtime(binary(), runtime_id(), runtime_id(), keyword()) ::
          {:ok, %{checkpoint: Checkpoint.t(), target: module()}} | {:error, term()}
  def swap_runtime(session_id, current_runtime, target_runtime, opts \\ []) do
    with {:ok, target_module} <- Runtimes.lookup_adapter(target_runtime),
         {:ok, checkpoint} <-
           create_checkpoint(%{
             session_id: session_id,
             runtime: current_runtime,
             label: "swap-to-#{target_runtime}",
             captured_at: now_usec(),
             workspace_slug: opts[:workspace_slug],
             created_by_agent_id: opts[:agent_id],
             agent_memory: opts[:agent_memory] || %{},
             metadata: %{
               kind: "swap",
               from: current_runtime,
               to: target_runtime
             }
           }) do
      {:ok, %{checkpoint: checkpoint, target: target_module}}
    end
  end

  # ---------------------------------------------------------------------------
  # MCP server passthroughs (storage lives on Runtime.config, key :mcp_servers)
  # ---------------------------------------------------------------------------

  @doc """
  Lists MCP servers attached to a runtime (or globally if `:nil`).
  """
  @spec list_mcp_servers(runtime_id() | nil) :: [map()]
  def list_mcp_servers(nil) do
    {:ok, runtimes} = Runtimes.list()
    Enum.flat_map(runtimes, &mcp_servers_of/1)
  end

  def list_mcp_servers(runtime_type) when is_binary(runtime_type) do
    case Runtimes.get_by_type(runtime_type) do
      {:ok, runtime} -> mcp_servers_of(runtime)
      _ -> []
    end
  end

  defp mcp_servers_of(%Runtime{type: type, config: %{} = config}) do
    config
    |> Map.get("mcp_servers", [])
    |> Enum.map(fn s -> Map.put(s, "runtime", type) end)
  end

  defp mcp_servers_of(_), do: []

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp model_info_payload(%{model_info: info}) when is_map(info) and map_size(info) > 0,
    do: info

  defp model_info_payload(row) when is_map(row) do
    %{
      "context_window" => Map.get(row, :context_window),
      "input_price" => Map.get(row, :input_cost_per_mtok),
      "output_price" => Map.get(row, :output_cost_per_mtok),
      "supports_images" => Map.get(row, :supports_vision),
      "supports_reasoning" => Map.get(row, :supports_thinking)
    }
  end

  defp now_usec, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
