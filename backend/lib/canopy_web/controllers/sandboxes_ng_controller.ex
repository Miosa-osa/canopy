defmodule CanopyWeb.SandboxesNgController do
  @moduledoc """
  HTTP API for the Sandboxes super-module (next-gen operator surface).

  Routes (all under `/api/v1/sandboxes-ng`):

      GET    /sandboxes-ng                       — current state of every sandbox
      GET    /sandboxes-ng/events                — lifecycle event log
      GET    /sandboxes-ng/events/:sandbox_id    — events for one sandbox
      GET    /sandboxes-ng/snapshots             — list snapshots
      POST   /sandboxes-ng/snapshots             — record a snapshot
      GET    /sandboxes-ng/ports                 — list port forwards
      POST   /sandboxes-ng/ports                 — open a port forward
      DELETE /sandboxes-ng/ports/:id             — close a port forward
      GET    /sandboxes-ng/alerts                — list alerts
      POST   /sandboxes-ng/alerts                — create an alert

  Distinct from the legacy `/api/v1/sandboxes` controller which reads off the
  `sessions` table; this controller writes against the dedicated
  `sandbox_*` tables and is the operator agent's API.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.SandboxesNg
  alias CanopyWeb.Schemas.SandboxesNgSchema

  action_fallback CanopyWeb.FallbackController

  tags ["sandboxes-ng"]

  @max_limit 1000
  @default_limit 100
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  @sandbox_id_regex ~r/\A[A-Za-z0-9][A-Za-z0-9_\-]{0,127}\z/

  # ---------------------------------------------------------------------------
  # Lifecycle: current state
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List current state of every sandbox",
    description: "Returns the most-recent lifecycle event per sandbox_id.",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Sandbox state list", "application/json", SandboxesNgSchema.SandboxStateList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts =
      []
      |> maybe_put(:workspace_slug, params["workspace_slug"])

    json(conn, %{data: SandboxesNg.list_current_states(opts)})
  end

  # ---------------------------------------------------------------------------
  # Lifecycle: events
  # ---------------------------------------------------------------------------

  operation :events,
    summary: "List lifecycle events",
    parameters: [
      sandbox_id: [in: :query, type: :string, required: false],
      state: [in: :query, type: :string, required: false],
      owner_agent_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      from: [in: :query, type: :string, required: false],
      to: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Lifecycle event list", "application/json", SandboxesNgSchema.LifecycleEventList}]

  @spec events(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def events(conn, params) do
    with {:ok, from} <- parse_dt_opt(params["from"]),
         {:ok, to} <- parse_dt_opt(params["to"]),
         :ok <- validate_window(from, to),
         {:ok, owner_agent_id} <- validate_uuid_opt(params["owner_agent_id"]),
         {:ok, sandbox_id} <- validate_sandbox_id_opt(params["sandbox_id"]) do
      opts =
        []
        |> maybe_put(:sandbox_id, sandbox_id)
        |> maybe_put(:state, params["state"])
        |> maybe_put(:owner_agent_id, owner_agent_id)
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:from, from)
        |> maybe_put(:to, to)
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: SandboxesNg.list_events(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :events_for_sandbox,
    summary: "List lifecycle events for a single sandbox",
    parameters: [
      sandbox_id: [in: :path, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Lifecycle event list", "application/json", SandboxesNgSchema.LifecycleEventList}]

  @spec events_for_sandbox(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def events_for_sandbox(conn, %{"sandbox_id" => sandbox_id} = params) do
    with {:ok, sandbox_id} <- validate_sandbox_id(sandbox_id) do
      events =
        SandboxesNg.list_events(
          sandbox_id: sandbox_id,
          limit: parse_limit(params["limit"])
        )

      json(conn, %{sandbox_id: sandbox_id, count: length(events), data: events})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Snapshots
  # ---------------------------------------------------------------------------

  operation :snapshots_index,
    summary: "List snapshots",
    parameters: [
      sandbox_id: [in: :query, type: :string, required: false],
      kind: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      active_only: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Snapshot list", "application/json", SandboxesNgSchema.SnapshotList}]

  @spec snapshots_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def snapshots_index(conn, params) do
    with {:ok, sandbox_id} <- validate_sandbox_id_opt(params["sandbox_id"]) do
      opts =
        []
        |> maybe_put(:sandbox_id, sandbox_id)
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:active_only, parse_bool(params["active_only"]))
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: SandboxesNg.list_snapshots(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :snapshots_create,
    summary: "Record a snapshot",
    request_body: {"Snapshot create", "application/json", SandboxesNgSchema.SnapshotCreate},
    responses: [created: {"Snapshot", "application/json", SandboxesNgSchema.Snapshot}]

  @spec snapshots_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def snapshots_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]),
         {:ok, sandbox_id} <- validate_sandbox_id_opt(params["sandbox_id"]) do
      attrs = if sandbox_id, do: Map.put(params, "sandbox_id", sandbox_id), else: params

      case SandboxesNg.create_snapshot(attrs) do
        {:ok, snap} -> conn |> put_status(:created) |> json(snap)
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Ports
  # ---------------------------------------------------------------------------

  operation :ports_index,
    summary: "List port forwards",
    parameters: [
      sandbox_id: [in: :query, type: :string, required: false],
      visibility: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      open_only: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Port forward list", "application/json", SandboxesNgSchema.PortForwardList}]

  @spec ports_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ports_index(conn, params) do
    with {:ok, sandbox_id} <- validate_sandbox_id_opt(params["sandbox_id"]) do
      opts =
        []
        |> maybe_put(:sandbox_id, sandbox_id)
        |> maybe_put(:visibility, params["visibility"])
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:open_only, parse_bool(params["open_only"]))
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: SandboxesNg.list_port_forwards(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :ports_create,
    summary: "Open a port forward",
    request_body: {"Port forward create", "application/json", SandboxesNgSchema.PortForwardCreate},
    responses: [created: {"Port forward", "application/json", SandboxesNgSchema.PortForward}]

  @spec ports_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ports_create(conn, params) do
    visibility = Map.get(params, "visibility", "private")
    confirm_public = Map.get(params, "confirm_public", false)

    with :ok <- validate_visibility(visibility),
         :ok <- validate_public_confirmation(visibility, confirm_public),
         {:ok, sandbox_id} <- validate_sandbox_id(params["sandbox_id"] || "") do
      attrs =
        params
        |> Map.put("sandbox_id", sandbox_id)
        |> Map.delete("confirm_public")

      case SandboxesNg.create_port_forward(attrs) do
        {:ok, forward} -> conn |> put_status(:created) |> json(forward)
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :ports_delete,
    summary: "Close a port forward",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Port forward", "application/json", SandboxesNgSchema.PortForward}]

  @spec ports_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ports_delete(conn, %{"id" => id}) do
    with {:ok, id} <- validate_uuid(id, "id") do
      case Canopy.Repo.get(SandboxesNg.PortForward, id) do
        nil ->
          conn |> put_status(:not_found) |> json(%{error: "port_forward_not_found", id: id})

        forward ->
          case SandboxesNg.close_port_forward(forward) do
            {:ok, updated} -> json(conn, updated)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Alerts
  # ---------------------------------------------------------------------------

  operation :alerts_index,
    summary: "List alerts",
    parameters: [
      enabled: [in: :query, type: :string, required: false],
      metric: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Alert list", "application/json", SandboxesNgSchema.AlertList}]

  @spec alerts_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_index(conn, params) do
    opts =
      []
      |> maybe_put(:enabled, parse_bool(params["enabled"]))
      |> maybe_put(:metric, params["metric"])
      |> maybe_put(:workspace_slug, params["workspace_slug"])

    json(conn, %{data: SandboxesNg.list_alerts(opts)})
  end

  operation :alerts_create,
    summary: "Create an alert",
    request_body: {"Alert create", "application/json", SandboxesNgSchema.AlertCreate},
    responses: [created: {"Alert", "application/json", SandboxesNgSchema.Alert}]

  @spec alerts_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def alerts_create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]) do
      case SandboxesNg.create_alert(params) do
        {:ok, alert} -> conn |> put_status(:created) |> json(alert)
        {:error, changeset} -> {:error, changeset}
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

  # ── Optional ISO-8601 timestamp parsing ────────────────────────────────────

  defp parse_dt_opt(nil), do: {:ok, nil}
  defp parse_dt_opt(""), do: {:ok, nil}

  defp parse_dt_opt(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      _ -> {:error, "invalid timestamp: #{str}"}
    end
  end

  defp parse_dt_opt(_), do: {:error, "invalid timestamp"}

  # ── Window validation ──────────────────────────────────────────────────────

  defp validate_window(nil, _), do: :ok
  defp validate_window(_, nil), do: :ok

  defp validate_window(from, to) do
    if DateTime.compare(from, to) in [:lt, :eq] do
      :ok
    else
      {:error, "from must be ≤ to"}
    end
  end

  # ── UUID validation ────────────────────────────────────────────────────────

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}
  defp validate_uuid_opt(str) when is_binary(str), do: validate_uuid(str, "uuid")
  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

  defp validate_uuid(str, field_name) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid #{field_name}: must be a UUID"}
    end
  end

  defp validate_uuid(_, field_name), do: {:error, "invalid #{field_name}"}

  # ── Sandbox ID validation (alphanumeric, dashes, underscores) ──────────────

  defp validate_sandbox_id_opt(nil), do: {:ok, nil}
  defp validate_sandbox_id_opt(""), do: {:ok, nil}
  defp validate_sandbox_id_opt(str) when is_binary(str), do: validate_sandbox_id(str)
  defp validate_sandbox_id_opt(_), do: {:error, "invalid sandbox_id"}

  defp validate_sandbox_id(str) when is_binary(str) do
    if Regex.match?(@sandbox_id_regex, str) do
      {:ok, str}
    else
      {:error,
       "invalid sandbox_id: must be alphanumeric/dashes/underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_sandbox_id(_), do: {:error, "invalid sandbox_id"}

  # ── Slug validation ────────────────────────────────────────────────────────

  defp validate_slug_opt(nil), do: :ok
  defp validate_slug_opt(""), do: {:error, "slug cannot be empty"}
  defp validate_slug_opt(str) when is_binary(str), do: validate_slug(str)
  defp validate_slug_opt(_), do: {:error, "slug must be a string"}

  defp validate_slug(str) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error,
       "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  # ── Visibility validation ──────────────────────────────────────────────────

  defp validate_visibility(v) when v in ["private", "token", "public"], do: :ok

  defp validate_visibility(other),
    do: {:error, "invalid visibility: #{inspect(other)} — must be private/token/public"}

  defp validate_public_confirmation("public", false),
    do: {:error, "public visibility requires confirm_public: true"}

  defp validate_public_confirmation(_, _), do: :ok

  # ── Bounded limit ──────────────────────────────────────────────────────────

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(""), do: @default_limit
  defp parse_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp parse_bool(nil), do: nil
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil

  # ── Error response ─────────────────────────────────────────────────────────

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
