defmodule Canopy.Missions do
  @moduledoc """
  Context for the Missions domain.

  A mission is a high-level objective decomposed into ordered milestones.
  Milestones can depend on each other — `advance_milestone/2` checks that
  all `depends_on_ids` are completed before transitioning to active/completed,
  then optionally runs a `validation_spec` to gate completion.

  ## API

  - `create_mission/1`       — insert a new mission
  - `list_missions/1`        — list with optional filters
  - `get_mission/1`          — fetch mission + preloaded milestones
  - `add_milestone/2`        — append a milestone to a mission
  - `advance_milestone/2`    — check deps + run validation + move to completed
  - `block_milestone/2`      — mark milestone as blocked with a reason
  - `fail_milestone/2`       — mark milestone as failed with a reason
  - `mission_progress/1`     — %{total: N, completed: N, pct: float}
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Missions.{Milestone, Mission}
  alias Canopy.Repo

  require Logger

  # ---------------------------------------------------------------------------
  # Mission CRUD
  # ---------------------------------------------------------------------------

  @spec create_mission(map()) :: {:ok, Mission.t()} | {:error, Ecto.Changeset.t()}
  def create_mission(attrs) do
    %Mission{}
    |> Mission.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_missions(map()) :: [Mission.t()]
  def list_missions(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(m in Mission, order_by: [desc: m.updated_at], limit: ^limit)
    |> maybe_filter_status(filters)
    |> maybe_filter_workspace(filters)
    |> Repo.all()
  end

  @spec get_mission(String.t()) :: {:ok, Mission.t()} | {:error, :not_found}
  def get_mission(id) when is_binary(id) do
    case Repo.get(Mission, id) do
      nil ->
        {:error, :not_found}

      mission ->
        {:ok, Repo.preload(mission, :milestones)}
    end
  end

  # ---------------------------------------------------------------------------
  # Milestone operations
  # ---------------------------------------------------------------------------

  @spec add_milestone(String.t(), map()) ::
          {:ok, Milestone.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def add_milestone(mission_id, attrs) when is_binary(mission_id) do
    with {:ok, _mission} <- get_mission(mission_id) do
      next_order = next_milestone_order(mission_id)

      %Milestone{}
      |> Milestone.changeset(Map.merge(%{order: next_order, mission_id: mission_id}, attrs))
      |> Repo.insert()
    end
  end

  @doc """
  Advances a milestone toward completion.

  Checks that all `depends_on_ids` milestones are completed first.
  If deps are clear and a `validation_spec` is present, runs it.
  On success, marks the milestone completed and sets `completed_at`.

  Returns:
  - `{:ok, milestone}` — milestone completed
  - `{:error, :deps_not_met}` — blocking deps still pending/active/failed
  - `{:error, :validation_failed, reason}` — validation_spec check failed
  - `{:error, :not_found}` — milestone does not exist
  """
  @spec advance_milestone(String.t(), map()) ::
          {:ok, Milestone.t()}
          | {:error, :not_found}
          | {:error, :deps_not_met}
          | {:error, :validation_failed, String.t()}
          | {:error, Ecto.Changeset.t()}
  def advance_milestone(milestone_id, _opts \\ %{}) when is_binary(milestone_id) do
    with {:ok, milestone} <- get_milestone(milestone_id),
         :ok <- check_dependencies(milestone),
         :ok <- run_validation(milestone) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      milestone
      |> Milestone.changeset(%{status: "completed", completed_at: now})
      |> Repo.update()
    end
  end

  @spec block_milestone(String.t(), String.t()) ::
          {:ok, Milestone.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def block_milestone(milestone_id, _reason \\ "") when is_binary(milestone_id) do
    with {:ok, milestone} <- get_milestone(milestone_id) do
      milestone
      |> Milestone.changeset(%{status: "blocked"})
      |> Repo.update()
    end
  end

  @spec fail_milestone(String.t(), String.t()) ::
          {:ok, Milestone.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def fail_milestone(milestone_id, _reason \\ "") when is_binary(milestone_id) do
    with {:ok, milestone} <- get_milestone(milestone_id) do
      milestone
      |> Milestone.changeset(%{status: "failed"})
      |> Repo.update()
    end
  end

  @doc """
  Returns mission completion progress.

      %{total: 5, completed: 3, pct: 60.0}
  """
  @spec mission_progress(String.t()) ::
          {:ok, %{total: non_neg_integer(), completed: non_neg_integer(), pct: float()}}
          | {:error, :not_found}
  def mission_progress(mission_id) when is_binary(mission_id) do
    with {:ok, _mission} <- get_mission(mission_id) do
      total =
        Repo.aggregate(
          from(m in Milestone, where: m.mission_id == ^mission_id),
          :count,
          :id
        )

      completed =
        Repo.aggregate(
          from(m in Milestone,
            where: m.mission_id == ^mission_id and m.status == "completed"
          ),
          :count,
          :id
        )

      pct = if total == 0, do: 0.0, else: completed / total * 100.0

      {:ok, %{total: total, completed: completed, pct: Float.round(pct, 1)}}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec get_milestone(String.t()) :: {:ok, Milestone.t()} | {:error, :not_found}
  defp get_milestone(id) do
    case Repo.get(Milestone, id) do
      nil -> {:error, :not_found}
      m -> {:ok, m}
    end
  end

  @spec check_dependencies(Milestone.t()) :: :ok | {:error, :deps_not_met}
  defp check_dependencies(%Milestone{depends_on_ids: []}), do: :ok

  defp check_dependencies(%Milestone{depends_on_ids: dep_ids}) do
    completed_ids =
      Repo.all(
        from(m in Milestone,
          where: m.id in ^dep_ids and m.status == "completed",
          select: m.id
        )
      )

    if length(completed_ids) == length(dep_ids) do
      :ok
    else
      {:error, :deps_not_met}
    end
  end

  @spec run_validation(Milestone.t()) :: :ok | {:error, :validation_failed, String.t()}
  defp run_validation(%Milestone{validation_spec: spec}) when map_size(spec) == 0, do: :ok

  defp run_validation(%Milestone{validation_spec: %{"type" => "shell", "command" => cmd} = spec}) do
    expected = Map.get(spec, "expected", "")

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {output, 0} ->
        if expected == "" or String.contains?(output, expected) do
          :ok
        else
          {:error, :validation_failed, "expected #{inspect(expected)} in output: #{output}"}
        end

      {output, code} ->
        {:error, :validation_failed, "command exited #{code}: #{String.trim(output)}"}
    end
  end

  defp run_validation(%Milestone{validation_spec: %{"type" => type}}) do
    Logger.warning("[Missions] unknown validation type=#{type}, skipping")
    :ok
  end

  defp run_validation(_), do: :ok

  @spec next_milestone_order(String.t()) :: non_neg_integer()
  defp next_milestone_order(mission_id) do
    case Repo.aggregate(
           from(m in Milestone, where: m.mission_id == ^mission_id),
           :max,
           :order
         ) do
      nil -> 0
      max -> max + 1
    end
  end

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [m], m.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [m], m.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query
end
