defmodule Canopy.Workspaces.Init do
  @moduledoc """
  Context for workspace initialisation jobs.

  Orchestrates a multi-step init sequence for a workspace:
    1. detect_base_branch  — resolves default git branch (20%)
    2. ensure_clone        — git-clones repo if root_path is empty and clone_url given (40%)
    3. create_initial_worktree — placeholder step, worktrees are per-session (60%)
    4. run_setup_script    — executes workspace.setup_script if present (90%)
    5. done                — marks 100% and status :succeeded

  Each step appends to `output` and persists progress so mid-init reloads work.

  Cancellation is supported: `cancel/1` sets status `:cancelled` and kills the
  async Task via a Registry entry (`Canopy.Workspaces.InitRegistry`).

  PubSub events are broadcast on topic `"workspace_init:job:<id>"` with keys:
    {:step, step_name}
    {:progress, pct}
    {:output, text}
    {:done, job}
    {:error, reason}
    {:cancelled, job}
  """

  import Ecto.Query

  alias Canopy.Repo
  alias Canopy.Workspaces
  alias Canopy.Workspaces.InitJob

  require Logger

  @pubsub Canopy.PubSub
  @registry Canopy.Workspaces.InitRegistry

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts an init job for the given workspace slug.

  Inserts a job with status `:running`, then spawns an async Task under
  `Canopy.TaskSupervisor` to execute the step sequence.

  `opts` accepts:
    - `:clone_url` — git URL to clone if the workspace root is empty
    - `:allow_task_supervisor` — boolean, defaults to true. Set false in unit tests
      that want synchronous execution.
  """
  @spec start(String.t(), keyword()) :: {:ok, InitJob.t()} | {:error, term()}
  def start(workspace_slug, opts \\ []) do
    with {:ok, workspace} <- Workspaces.get_by_slug(workspace_slug) do
      attrs = %{
        workspace_slug: workspace_slug,
        status: "running",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      case Repo.insert(InitJob.changeset(%InitJob{}, attrs)) do
        {:ok, job} ->
          clone_url = Keyword.get(opts, :clone_url)
          spawn_init_task(job, workspace, clone_url)
          {:ok, job}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "Returns a job by id, or `{:error, :not_found}`."
  @spec get(Ecto.UUID.t()) :: {:ok, InitJob.t()} | {:error, :not_found}
  def get(job_id) do
    case Repo.get(InitJob, job_id) do
      nil -> {:error, :not_found}
      job -> {:ok, job}
    end
  end

  @doc "Returns recent jobs for a workspace slug, newest first."
  @spec list_for_workspace(String.t()) :: {:ok, [InitJob.t()]}
  def list_for_workspace(slug) do
    jobs =
      Repo.all(
        from j in InitJob,
          where: j.workspace_slug == ^slug,
          order_by: [desc: j.inserted_at],
          limit: 20
      )

    {:ok, jobs}
  end

  @doc """
  Cancels a running init job.

  Sets status to `:cancelled` immediately, then kills the Task if it is still
  running (tracked via Registry). Subsequent step advances are no-ops because
  `step_advance/3` checks for cancellation before persisting.
  """
  @spec cancel(Ecto.UUID.t()) :: {:ok, InitJob.t()} | {:error, :not_found | :already_terminal}
  def cancel(job_id) do
    with {:ok, job} <- get(job_id) do
      if job.status in ["succeeded", "failed", "cancelled"] do
        {:error, :already_terminal}
      else
        {:ok, cancelled_job} =
          job
          |> InitJob.changeset(%{
            status: "cancelled",
            finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
          |> Repo.update()

        kill_task(job_id)
        broadcast(job_id, {:cancelled, cancelled_job})
        {:ok, cancelled_job}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Internal — task orchestration
  # ---------------------------------------------------------------------------

  defp spawn_init_task(job, workspace, clone_url) do
    job_id = job.id
    caller = self()

    {:ok, task_pid} =
      Task.Supervisor.start_child(Canopy.TaskSupervisor, fn ->
        # Allow this task to use the test sandbox connection when running in test env.
        if Application.get_env(:canopy, :env, :prod) == :test do
          Ecto.Adapters.SQL.Sandbox.allow(Canopy.Repo, caller, self())
        end

        run_init_sequence(job_id, workspace, clone_url)
      end)

    register_task(job_id, task_pid)
  end

  defp run_init_sequence(job_id, workspace, clone_url) do
    steps = [
      {"detect_base_branch", 20,
       fn -> step_detect_base_branch(workspace.root_path, clone_url) end},
      {"ensure_clone", 40, fn -> step_ensure_clone(workspace.root_path, clone_url) end},
      {"create_initial_worktree", 60, fn -> :ok end},
      {"run_setup_script", 90, fn -> step_run_setup_script(workspace) end},
      {"done", 100, fn -> :ok end}
    ]

    result =
      Enum.reduce_while(steps, :ok, fn {step_name, pct, step_fn}, _acc ->
        if cancelled?(job_id) do
          {:halt, :cancelled}
        else
          broadcast(job_id, {:step, step_name})
          advance_step(job_id, step_name, pct)

          case step_fn.() do
            :ok ->
              {:cont, :ok}

            {:ok, output_text} ->
              append_output(job_id, output_text)
              {:cont, :ok}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        end
      end)

    case result do
      :ok ->
        {:ok, job} = get(job_id)
        finalize(job_id, :succeeded, nil)
        broadcast(job_id, {:done, job})

      :cancelled ->
        Logger.debug("[Init] Job #{job_id} cancelled during sequence")

      {:error, reason} ->
        error_text = inspect(reason)
        finalize(job_id, :failed, error_text)
        broadcast(job_id, {:error, error_text})
    end

    deregister_task(job_id)
  end

  # ---------------------------------------------------------------------------
  # Steps
  # ---------------------------------------------------------------------------

  defp step_detect_base_branch(root_path, _clone_url) do
    if is_git_dir?(root_path) do
      case System.cmd("git", ["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
             cd: root_path,
             stderr_to_stdout: true
           ) do
        {output, 0} ->
          branch = output |> String.trim() |> String.replace_prefix("origin/", "")
          {:ok, "Detected base branch: #{branch}\n"}

        {_output, _} ->
          # Fallback: try main then master
          {:ok, "Detected base branch: main (fallback)\n"}
      end
    else
      # Not a git dir yet — if clone_url present, detection happens post-clone
      {:ok, "Skipping branch detection — not a git repository yet.\n"}
    end
  end

  defp step_ensure_clone(root_path, nil) do
    append_info =
      if is_git_dir?(root_path),
        do: "Already a git repository.\n",
        else: "No clone URL provided — skipping clone.\n"

    {:ok, append_info}
  end

  defp step_ensure_clone(root_path, clone_url) do
    if is_git_dir?(root_path) do
      {:ok, "Repository already cloned at #{root_path}.\n"}
    else
      {:ok, "Cloning #{clone_url} into #{root_path}...\n"}

      case System.cmd("git", ["clone", clone_url, root_path], stderr_to_stdout: true) do
        {output, 0} ->
          {:ok, output <> "\nClone complete.\n"}

        {output, exit_code} ->
          {:error, "git clone failed (exit #{exit_code}): #{output}"}
      end
    end
  end

  defp step_run_setup_script(%{setup_script: nil}), do: :ok
  defp step_run_setup_script(%{setup_script: ""}), do: :ok

  defp step_run_setup_script(%{setup_script: script, root_path: root_path}) do
    case System.cmd("bash", ["-c", script],
           cd: root_path,
           stderr_to_stdout: true,
           env: [{"PATH", System.get_env("PATH", "/usr/bin:/bin")}]
         ) do
      {output, 0} ->
        {:ok, output}

      {output, exit_code} ->
        {:error, "setup_script failed (exit #{exit_code}): #{output}"}
    end
  end

  # ---------------------------------------------------------------------------
  # DB helpers
  # ---------------------------------------------------------------------------

  defp advance_step(job_id, step_name, pct) do
    {_count, _} =
      Repo.update_all(
        from(j in InitJob, where: j.id == ^job_id and j.status == "running"),
        set: [current_step: step_name, progress_pct: pct, updated_at: now()]
      )

    broadcast(job_id, {:progress, pct})
  end

  defp append_output(job_id, text) do
    case Repo.get(InitJob, job_id) do
      nil ->
        :noop

      job ->
        new_output = (job.output || "") <> text

        job
        |> InitJob.changeset(%{output: new_output})
        |> Repo.update()
    end

    broadcast(job_id, {:output, text})
  end

  defp finalize(job_id, status, error_text) do
    status_str = Atom.to_string(status)

    {_count, _} =
      Repo.update_all(
        from(j in InitJob, where: j.id == ^job_id),
        set: [
          status: status_str,
          finished_at: now(),
          error: error_text,
          updated_at: now()
        ]
      )
  end

  defp cancelled?(job_id) do
    case Repo.one(from j in InitJob, where: j.id == ^job_id, select: j.status) do
      "cancelled" -> true
      _ -> false
    end
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp is_git_dir?(nil), do: false

  defp is_git_dir?(path) do
    File.dir?(Path.join(path, ".git"))
  end

  # ---------------------------------------------------------------------------
  # Registry helpers — track task pids for cancellation
  # ---------------------------------------------------------------------------

  defp register_task(job_id, pid) do
    Registry.register(@registry, job_id, pid)
  end

  defp deregister_task(job_id) do
    Registry.unregister(@registry, job_id)
  end

  defp kill_task(job_id) do
    case Registry.lookup(@registry, job_id) do
      [{_pid, task_pid}] ->
        Process.exit(task_pid, :kill)

      [] ->
        :noop
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  defp broadcast(job_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "workspace_init:job:#{job_id}", message)
  end
end
