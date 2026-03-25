defmodule CanopyWeb.WorkflowController do
  use CanopyWeb, :controller
  require Logger

  alias Canopy.Repo
  alias Canopy.Schemas.{Workflow, WorkflowStep, WorkflowRun}
  alias Canopy.Workflows.Engine
  import Ecto.Query

  def index(conn, params) do
    workspace_id = params["workspace_id"]

    query =
      from w in Workflow,
        order_by: [asc: w.name],
        preload: [:steps]

    query =
      if workspace_id,
        do: where(query, [w], w.workspace_id == ^workspace_id),
        else: query

    workflows = Repo.all(query)
    json(conn, %{workflows: Enum.map(workflows, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(Workflow, id) |> maybe_preload() do
      nil -> conn |> put_status(404) |> json(%{error: "not_found"})
      workflow -> json(conn, %{workflow: serialize(workflow)})
    end
  end

  def create(conn, params) do
    {step_attrs, workflow_params} = Map.pop(params, "steps", [])

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:workflow, Workflow.changeset(%Workflow{}, workflow_params))
      |> Ecto.Multi.run(:steps, fn repo, %{workflow: workflow} ->
        insert_steps_multi(repo, workflow, step_attrs)
      end)

    case Repo.transaction(multi) do
      {:ok, %{workflow: workflow}} ->
        workflow = Repo.preload(workflow, [:steps])
        conn |> put_status(201) |> json(%{workflow: serialize(workflow)})

      {:error, :workflow, changeset, _changes} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})

      {:error, :steps, reason, _changes} ->
        conn
        |> put_status(422)
        |> json(%{error: "step_creation_failed", details: reason})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Repo.get(Workflow, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workflow ->
        changeset = Workflow.changeset(workflow, params)

        case Repo.update(changeset) do
          {:ok, updated} ->
            updated = Repo.preload(updated, [:steps])
            json(conn, %{workflow: serialize(updated)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{error: "validation_failed", details: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(Workflow, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      workflow ->
        Repo.delete!(workflow)
        json(conn, %{ok: true})
    end
  end

  def steps(conn, %{"workflow_id" => workflow_id}) do
    steps =
      Repo.all(
        from s in WorkflowStep,
          where: s.workflow_id == ^workflow_id,
          order_by: [asc: s.position],
          preload: [:agent]
      )

    json(conn, %{steps: Enum.map(steps, &serialize_step/1)})
  end

  def add_step(conn, %{"workflow_id" => workflow_id} = params) do
    attrs = Map.put(params, "workflow_id", workflow_id)
    changeset = WorkflowStep.changeset(%WorkflowStep{}, attrs)

    case Repo.insert(changeset) do
      {:ok, step} ->
        step = Repo.preload(step, :agent)
        conn |> put_status(201) |> json(%{step: serialize_step(step)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "validation_failed", details: format_errors(changeset)})
    end
  end

  def remove_step(conn, %{"workflow_id" => _workflow_id, "step_id" => step_id}) do
    case Repo.get(WorkflowStep, step_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      step ->
        Repo.delete!(step)
        json(conn, %{ok: true})
    end
  end

  def runs(conn, %{"workflow_id" => workflow_id}) do
    runs =
      Repo.all(
        from r in WorkflowRun,
          where: r.workflow_id == ^workflow_id,
          order_by: [desc: r.inserted_at],
          limit: 50
      )

    json(conn, %{runs: Enum.map(runs, &serialize_run/1)})
  end

  def trigger(conn, %{"workflow_id" => workflow_id} = params) do
    case Engine.start_run(workflow_id, params) do
      {:ok, run} ->
        Logger.info("[WorkflowController] Run #{run.id} started for workflow #{workflow_id}")
        conn |> put_status(201) |> json(%{run: serialize_run(run)})

      {:error, :workflow_not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, reason} ->
        Logger.error("[WorkflowController] Failed to start run: #{inspect(reason)}")

        conn
        |> put_status(422)
        |> json(%{error: "trigger_failed", details: inspect(reason)})
    end
  end

  def pause(conn, %{"workflow_id" => _workflow_id, "run_id" => run_id}) do
    case Engine.pause_run(run_id) do
      {:ok, run} ->
        json(conn, %{run: serialize_run(run)})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, {:invalid_transition, status}} ->
        conn |> put_status(422) |> json(%{error: "invalid_state", current_status: status})
    end
  end

  def resume(conn, %{"workflow_id" => _workflow_id, "run_id" => run_id} = params) do
    resume_params = Map.get(params, "resume_params", %{})

    case Engine.resume_run(run_id, resume_params) do
      {:ok, run} ->
        json(conn, %{run: serialize_run(run)})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, {:invalid_transition, status}} ->
        conn |> put_status(422) |> json(%{error: "invalid_state", current_status: status})
    end
  end

  def cancel(conn, %{"workflow_id" => _workflow_id, "run_id" => run_id}) do
    case Engine.cancel_run(run_id) do
      {:ok, run} ->
        json(conn, %{run: serialize_run(run)})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      {:error, {:invalid_transition, status}} ->
        conn |> put_status(422) |> json(%{error: "invalid_state", current_status: status})
    end
  end

  def step_status(conn, %{"workflow_id" => _workflow_id, "run_id" => run_id}) do
    case Repo.get(WorkflowRun, run_id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "not_found"})

      run ->
        steps =
          Repo.all(
            from s in WorkflowStep,
              where: s.workflow_id == ^run.workflow_id,
              order_by: [asc: s.position]
          )

        step_statuses =
          Enum.map(steps, fn step ->
            result = Map.get(run.step_results, step.id, %{})
            status = Map.get(result, "status", "pending")

            %{
              step_id: step.id,
              step_name: step.name,
              step_type: step.step_type,
              position: step.position,
              status: status,
              result: result
            }
          end)

        json(conn, %{run_id: run_id, status: run.status, steps: step_statuses})
    end
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp maybe_preload(nil), do: nil

  defp maybe_preload(%Workflow{} = w),
    do: Repo.preload(w, [:steps, :runs])

  defp insert_steps_multi(_repo, workflow, step_attrs) when is_list(step_attrs) do
    results =
      step_attrs
      |> Enum.with_index()
      |> Enum.reduce_while([], fn {attrs, _idx}, acc ->
        changeset =
          attrs
          |> Map.put("workflow_id", workflow.id)
          |> then(&WorkflowStep.changeset(%WorkflowStep{}, &1))

        case Repo.insert(changeset) do
          {:ok, step} -> {:cont, [step | acc]}
          {:error, changeset} -> {:halt, {:error, format_errors(changeset)}}
        end
      end)

    case results do
      {:error, reason} -> {:error, reason}
      steps when is_list(steps) -> {:ok, Enum.reverse(steps)}
    end
  end

  defp insert_steps_multi(_repo, _workflow, _), do: {:ok, []}

  defp serialize(%Workflow{} = w) do
    step_count =
      if Ecto.assoc_loaded?(w.steps), do: length(w.steps), else: 0

    last_run_at =
      if Ecto.assoc_loaded?(w.runs) && length(w.runs) > 0 do
        w.runs
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> List.first()
        |> Map.get(:inserted_at)
      else
        nil
      end

    steps =
      if Ecto.assoc_loaded?(w.steps),
        do: Enum.map(w.steps, &serialize_step/1),
        else: []

    %{
      id: w.id,
      name: w.name,
      slug: w.slug,
      description: w.description,
      status: w.status,
      trigger_type: w.trigger_type,
      trigger_config: w.trigger_config,
      created_by: w.created_by,
      version: w.version,
      workspace_id: w.workspace_id,
      organization_id: w.organization_id,
      step_count: step_count,
      last_run_at: last_run_at,
      steps: steps,
      inserted_at: w.inserted_at,
      updated_at: w.updated_at
    }
  end

  defp serialize_step(%WorkflowStep{} = s) do
    agent_name =
      if Ecto.assoc_loaded?(s.agent) && s.agent, do: s.agent.name, else: nil

    agent_emoji =
      if Ecto.assoc_loaded?(s.agent) && s.agent, do: s.agent.avatar_emoji, else: nil

    %{
      id: s.id,
      workflow_id: s.workflow_id,
      agent_id: s.agent_id,
      agent_name: agent_name,
      agent_emoji: agent_emoji,
      name: s.name,
      step_type: s.step_type,
      position: s.position,
      config: s.config,
      depends_on: s.depends_on,
      timeout_seconds: s.timeout_seconds,
      retry_count: s.retry_count,
      on_failure: s.on_failure,
      inserted_at: s.inserted_at,
      updated_at: s.updated_at
    }
  end

  defp serialize_run(%WorkflowRun{} = r) do
    %{
      id: r.id,
      workflow_id: r.workflow_id,
      status: r.status,
      trigger_event: r.trigger_event,
      input: r.input,
      output: r.output,
      started_at: r.started_at,
      completed_at: r.completed_at,
      error: r.error,
      step_results: r.step_results,
      inserted_at: r.inserted_at,
      updated_at: r.updated_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
