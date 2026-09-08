defmodule Canopy.Routines do
  @moduledoc """
  Context for the Routines domain.

  Recurring automations. Each routine has a cron schedule and a prompt template.
  On `fire/1`, the template is rendered and the configured work-unit is created.
  Short IDs use a random 8-digit numeric suffix: `R-XXXXXXXX`.

  No scheduler GenServer yet — cron execution is a follow-up. `fire/1` supports
  manual triggering and is wired to the HTTP endpoint.

  ## API

  - `list/1`    — query with optional filters
  - `get/1`     — by short_id or uuid
  - `create/1`  — inserts, auto-generates short_id
  - `update/2`  — by short_id
  - `enable/1`  — set enabled = true
  - `disable/1` — set enabled = false
  - `delete/1`  — hard delete by short_id
  - `fire/1`    — render template + create configured work-unit
  """

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  alias Canopy.Goals
  alias Canopy.Issues
  alias Canopy.Repo
  alias Canopy.Routines.{Cron, Routine}
  alias Canopy.Tasks

  @spec list(map()) :: [Routine.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(r in Routine, order_by: [desc: r.updated_at], limit: ^limit)
    |> maybe_filter_workspace(filters)
    |> maybe_filter_enabled(filters)
    |> Repo.all()
  end

  @spec get(String.t()) :: {:ok, Routine.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} ->
        case Repo.get(Routine, id) do
          nil -> {:error, :not_found}
          routine -> {:ok, routine}
        end

      :error ->
        case Repo.get_by(Routine, short_id: id) do
          nil -> {:error, :not_found}
          routine -> {:ok, routine}
        end
    end
  end

  @spec create(map()) :: {:ok, Routine.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    normalized = normalize_keys(attrs)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs_with_id =
      normalized
      |> Map.put_new(:short_id, generate_short_id())
      |> maybe_set_next_run_at(now)

    %Routine{}
    |> Routine.changeset(attrs_with_id)
    |> Repo.insert()
  end

  @spec update(String.t(), map()) ::
          {:ok, Routine.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update(id, attrs) do
    with {:ok, routine} <- get(id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Recompute next_run_at whenever cron changes
      attrs_with_next =
        if Map.has_key?(attrs, :cron) or Map.has_key?(attrs, "cron") do
          cron = Map.get(attrs, :cron) || Map.get(attrs, "cron") || routine.cron
          Map.put(attrs, :next_run_at, safe_next_after(cron, now))
        else
          attrs
        end

      routine
      |> Routine.changeset(attrs_with_next)
      |> Repo.update()
    end
  end

  @spec enable(String.t()) :: {:ok, Routine.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def enable(id) do
    with {:ok, routine} <- get(id) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      next = safe_next_after(routine.cron, now)

      routine
      |> Routine.changeset(%{enabled: true, next_run_at: next})
      |> Repo.update()
    end
  end

  @spec disable(String.t()) :: {:ok, Routine.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def disable(id) do
    with {:ok, routine} <- get(id) do
      routine
      |> Routine.changeset(%{enabled: false, next_run_at: nil})
      |> Repo.update()
    end
  end

  @doc """
  Returns enabled routines whose `next_run_at` is <= `now` (or NULL), deduplicated
  by the 30-second safety window: routines fired less than 30 seconds ago are excluded.
  """
  @spec list_due(DateTime.t()) :: [Routine.t()]
  def list_due(%DateTime{} = now) do
    cutoff = DateTime.add(now, -30, :second)

    from(r in Routine,
      where: r.enabled == true,
      where: is_nil(r.next_run_at) or r.next_run_at <= ^now,
      where: r.in_flight == false,
      where: is_nil(r.last_run_at) or r.last_run_at <= ^cutoff,
      order_by: [asc: r.next_run_at]
    )
    |> Repo.all()
  end

  @doc """
  Atomically claims a routine for firing using SELECT … FOR UPDATE SKIP LOCKED.
  Returns `{:ok, routine}` if claimed, `{:skip, :already_claimed}` otherwise.
  """
  @spec claim_for_fire(String.t()) :: {:ok, Routine.t()} | {:skip, :already_claimed}
  def claim_for_fire(id) do
    Repo.transaction(fn ->
      result =
        from(r in Routine,
          where: r.id == ^id and r.in_flight == false,
          lock: "FOR UPDATE SKIP LOCKED"
        )
        |> Repo.one()

      case result do
        nil ->
          Repo.rollback(:already_claimed)

        routine ->
          {:ok, claimed} =
            routine
            |> Routine.changeset(%{in_flight: true})
            |> Repo.update()

          claimed
      end
    end)
    |> case do
      {:ok, routine} -> {:ok, routine}
      {:error, :already_claimed} -> {:skip, :already_claimed}
    end
  end

  @doc """
  Releases the in_flight lock after a fire attempt (success or failure).
  Updates last_run_at, run_count, next_run_at on success; bumps error_count on failure.
  """
  @spec release_after_fire(Routine.t(), DateTime.t(), :ok | {:error, term()}) ::
          {:ok, Routine.t()} | {:error, Ecto.Changeset.t()}
  def release_after_fire(routine, now, :ok) do
    next = safe_next_after(routine.cron, now)

    routine
    |> Routine.changeset(%{
      in_flight: false,
      last_run_at: now,
      run_count: routine.run_count + 1,
      next_run_at: next
    })
    |> Repo.update()
  end

  def release_after_fire(routine, now, {:error, reason}) do
    Logger.warning("[Routines] fire failed for #{routine.short_id}: #{inspect(reason)}")

    next = safe_next_after(routine.cron, now)

    routine
    |> Routine.changeset(%{
      in_flight: false,
      error_count: routine.error_count + 1,
      next_run_at: next
    })
    |> Repo.update()
  end

  @spec delete(String.t()) :: :ok | {:error, :not_found}
  def delete(id) do
    with {:ok, routine} <- get(id) do
      Repo.delete!(routine)
      :ok
    end
  end

  @doc """
  Fires the routine manually. Renders the prompt template and creates the
  configured work-unit (`:issue | :task | :goal`) in the routine's workspace.

  Updates `last_run_at` and increments `run_count` on success.
  Returns `{:ok, %{routine: updated, created: work_unit}}`.
  """
  @spec fire(String.t()) ::
          {:ok, %{routine: Routine.t(), created: map()}}
          | {:error, :not_found}
          | {:error, Ecto.Changeset.t()}
  def fire(id) do
    with {:ok, routine} <- get(id) do
      prompt = render_template(routine)

      work_unit_attrs = %{
        title: prompt,
        workspace_slug: routine.workspace_slug,
        assignee_type: if(routine.target_agent_id, do: "agent"),
        assignee_id: routine.target_agent_id
      }

      result =
        case routine.creates do
          "issue" -> Issues.create(work_unit_attrs)
          "goal" -> Goals.create(work_unit_attrs)
          _task -> Tasks.create(work_unit_attrs)
        end

      case result do
        {:ok, created} ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          {:ok, updated} =
            routine
            |> Routine.changeset(%{
              last_run_at: now,
              run_count: routine.run_count + 1
            })
            |> Repo.update()

          {:ok, %{routine: updated, created: created}}

        {:error, _} = err ->
          err
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Tiny template renderer: replaces {{date}}, {{workspace}}, {{now_iso}}, {{last_run}} placeholders.
  @spec render_template(Routine.t(), DateTime.t() | nil) :: String.t()
  defp render_template(routine, now \\ nil) do
    now = now || DateTime.utc_now()
    date = now |> DateTime.to_date() |> Date.to_string()
    now_iso = DateTime.to_iso8601(now)
    last_run = if routine.last_run_at, do: DateTime.to_iso8601(routine.last_run_at), else: "never"

    routine.prompt_template
    |> String.replace("{{date}}", date)
    |> String.replace("{{workspace}}", routine.workspace_slug)
    |> String.replace("{{name}}", routine.name)
    |> String.replace("{{now_iso}}", now_iso)
    |> String.replace("{{last_run}}", last_run)
  end

  @spec maybe_set_next_run_at(map(), DateTime.t()) :: map()
  defp maybe_set_next_run_at(attrs, now) do
    cron = Map.get(attrs, :cron)

    if cron && !Map.has_key?(attrs, :next_run_at) do
      Map.put(attrs, :next_run_at, safe_next_after(cron, now))
    else
      attrs
    end
  end

  @spec safe_next_after(String.t() | nil, DateTime.t()) :: DateTime.t() | nil
  defp safe_next_after(nil, _now), do: nil

  defp safe_next_after(cron, now) do
    Cron.next_after(cron, now)
  rescue
    _ -> nil
  end

  defp generate_short_id do
    n = :rand.uniform(100_000_000) - 1
    "R-" <> String.pad_leading(Integer.to_string(n), 8, "0")
  end

  @known_string_keys ~w(short_id name description cron prompt_template creates
                        target_agent_id target_runtime_type workspace_slug enabled
                        last_run_at next_run_at run_count)

  @spec normalize_keys(map()) :: map()
  defp normalize_keys(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, k, v)

      {k, v}, acc when is_binary(k) and k in @known_string_keys ->
        Map.put(acc, String.to_existing_atom(k), v)

      _, acc ->
        acc
    end)
  end

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [r], r.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_enabled(query, %{enabled: e}) when is_boolean(e),
    do: where(query, [r], r.enabled == ^e)

  defp maybe_filter_enabled(query, _), do: query
end
