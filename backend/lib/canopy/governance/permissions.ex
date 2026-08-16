defmodule Canopy.Governance.Permissions do
  @moduledoc """
  Context functions for the 5-scope tool permission grant system.

  ## Scope priority (highest to lowest)

      never > forever > today > session > once

  When `check_permission/3` evaluates grants for a given (agent_slug, tool_name)
  pair it applies this ordering: a single "never" grant always wins, a "forever"
  grant blocks any time-limited grants from downgrading it, and so on. The caller
  receives one of:

    - `:allowed`  — at least one active grant permits the tool
    - `:denied`   — a "never" grant is present
    - `:ask`      — no applicable grant found; surface to human for decision

  ## Grant lifecycle

    - "once"    — `used` flips to true after first successful check; subsequent
                  checks treat it as consumed and skip it
    - "session" — valid while `session_id` matches the opts session
    - "today"   — `expires_at` set to end of day UTC at creation time; auto-
                  expired by `cleanup_expired!/0`
    - "forever" — no expiry
    - "never"   — permanent deny

  Call `cleanup_expired!/0` from a periodic job (e.g. an Oban cron worker) to
  prune consumed "once" grants and past-deadline "today" grants.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Governance.ToolPermissionGrant
  alias Canopy.Repo

  require Logger

  # Priority order for resolution — index 0 = highest priority.
  @scope_priority ~w(never forever today session once)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Creates a tool permission grant.

  `expires_at` is auto-computed from `scope`:
    - "today"   → end of current UTC day (23:59:59.999999)
    - all other → nil (managed by session termination or manual revocation)

  Returns `{:ok, grant}` or `{:error, changeset}`.
  """
  @spec grant_permission(map()) :: {:ok, ToolPermissionGrant.t()} | {:error, Ecto.Changeset.t()}
  def grant_permission(attrs) do
    expires_at = compute_expires_at(attrs[:scope] || attrs["scope"])

    attrs_with_expiry =
      case expires_at do
        nil -> attrs
        dt -> Map.put(stringify_keys(attrs), "expires_at", dt)
      end

    %ToolPermissionGrant{}
    |> ToolPermissionGrant.changeset(attrs_with_expiry)
    |> Repo.insert()
  end

  @doc """
  Revokes (hard-deletes) a tool permission grant by id.

  Returns `{:ok, grant}` or `{:error, :not_found}`.
  """
  @spec revoke_permission(binary()) :: {:ok, ToolPermissionGrant.t()} | {:error, :not_found}
  def revoke_permission(id) do
    case Repo.get(ToolPermissionGrant, id) do
      nil -> {:error, :not_found}
      grant -> Repo.delete(grant)
    end
  end

  @doc """
  Checks whether `agent_slug` is permitted to use `tool_name`.

  Options:
    - `:session_id`      — binary_id; required for "session" scope matching
    - `:workspace_slug`  — when provided, also matches workspace-scoped grants;
                           global grants (workspace_slug is nil) always apply

  Returns:
    - `:allowed` — at least one active grant permits the tool
    - `:denied`  — a "never" grant is present
    - `:ask`     — no applicable grant; surface for human decision

  Side effects: consumes "once" grants by setting `used = true`.
  """
  @spec check_permission(String.t(), String.t(), keyword()) ::
          :allowed | :denied | :ask
  def check_permission(agent_slug, tool_name, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    workspace_slug = Keyword.get(opts, :workspace_slug)
    now = DateTime.utc_now()

    grants =
      from(g in ToolPermissionGrant,
        where: g.agent_slug == ^agent_slug and g.tool_name == ^tool_name,
        where: g.used == false,
        where: is_nil(g.expires_at) or g.expires_at > ^now,
        order_by: [asc: g.inserted_at]
      )
      |> filter_by_workspace(workspace_slug)
      |> Repo.all()

    resolve(grants, session_id)
  end

  @doc """
  Lists tool permission grants with optional filters.

  Options (all optional):
    - `:agent_slug`      — filter by agent
    - `:tool_name`       — filter by tool
    - `:workspace_slug`  — filter by workspace
    - `:scope`           — filter by scope
  """
  @spec list_grants(keyword()) :: [ToolPermissionGrant.t()]
  def list_grants(filters \\ []) do
    from(g in ToolPermissionGrant, order_by: [desc: g.inserted_at])
    |> apply_filter(:agent_slug, Keyword.get(filters, :agent_slug))
    |> apply_filter(:tool_name, Keyword.get(filters, :tool_name))
    |> apply_filter(:workspace_slug, Keyword.get(filters, :workspace_slug))
    |> apply_filter(:scope, Keyword.get(filters, :scope))
    |> Repo.all()
  end

  @doc """
  Deletes all expired or consumed grants.

  Removes:
    - "once" grants where `used == true`
    - Any grant where `expires_at < now`

  Safe to call from a cron job or `mix` task.
  """
  @spec cleanup_expired!() :: {non_neg_integer(), nil}
  def cleanup_expired! do
    now = DateTime.utc_now()

    {count, _} =
      from(g in ToolPermissionGrant,
        where: g.used == true or (not is_nil(g.expires_at) and g.expires_at < ^now)
      )
      |> Repo.delete_all()

    Logger.info("[Permissions] cleanup_expired!: removed #{count} grant(s)")
    {count, nil}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Resolve grants in priority order: never > forever > today > session > once.
  @spec resolve([ToolPermissionGrant.t()], binary() | nil) :: :allowed | :denied | :ask
  defp resolve([], _session_id), do: :ask

  defp resolve(grants, session_id) do
    sorted = Enum.sort_by(grants, &scope_rank(&1.scope))

    case find_decisive(sorted, session_id) do
      {:never, _grant} -> :denied
      {:allowed, grant} -> consume_if_once(grant)
      nil -> :ask
    end
  end

  @spec find_decisive([ToolPermissionGrant.t()], binary() | nil) ::
          {:never, ToolPermissionGrant.t()} | {:allowed, ToolPermissionGrant.t()} | nil
  defp find_decisive([], _session_id), do: nil

  defp find_decisive([grant | rest], session_id) do
    case grant.scope do
      "never" ->
        {:never, grant}

      "forever" ->
        {:allowed, grant}

      "today" ->
        {:allowed, grant}

      "session" ->
        if grant.session_id == session_id do
          {:allowed, grant}
        else
          find_decisive(rest, session_id)
        end

      "once" ->
        {:allowed, grant}

      _unknown ->
        find_decisive(rest, session_id)
    end
  end

  @spec consume_if_once(ToolPermissionGrant.t()) :: :allowed
  defp consume_if_once(%ToolPermissionGrant{scope: "once"} = grant) do
    grant
    |> ToolPermissionGrant.changeset(%{used: true})
    |> Repo.update()
    |> case do
      {:ok, _} ->
        :ok

      {:error, cs} ->
        Logger.warning("[Permissions] failed to consume once grant: #{inspect(cs.errors)}")
    end

    :allowed
  end

  defp consume_if_once(_grant), do: :allowed

  @spec scope_rank(String.t()) :: non_neg_integer()
  defp scope_rank(scope) do
    Enum.find_index(@scope_priority, &(&1 == scope)) || 99
  end

  @spec compute_expires_at(String.t() | nil) :: DateTime.t() | nil
  defp compute_expires_at("today") do
    now = DateTime.utc_now()

    Date.utc_today()
    |> Date.end_of_week()
    # end of today: same day, 23:59:59.999999
    |> then(fn _d ->
      %DateTime{
        year: now.year,
        month: now.month,
        day: now.day,
        hour: 23,
        minute: 59,
        second: 59,
        microsecond: {999_999, 6},
        time_zone: "Etc/UTC",
        zone_abbr: "UTC",
        utc_offset: 0,
        std_offset: 0
      }
    end)
  end

  defp compute_expires_at(_other), do: nil

  @spec filter_by_workspace(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp filter_by_workspace(query, nil), do: query

  defp filter_by_workspace(query, workspace_slug) do
    from(g in query,
      where: is_nil(g.workspace_slug) or g.workspace_slug == ^workspace_slug
    )
  end

  @spec apply_filter(Ecto.Query.t(), atom(), term()) :: Ecto.Query.t()
  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: from(g in query, where: field(g, ^field) == ^value)

  @spec stringify_keys(map()) :: map()
  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
