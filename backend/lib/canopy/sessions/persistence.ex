defmodule Canopy.Sessions.Persistence do
  @moduledoc """
  Disk snapshot of live sessions so a Canopy restart can bring them back.

  `save_state/0` writes `~/.canopy/session-state.json` (overridable via
  `:canopy, :session_state_path`). `restore_state/1` rehydrates the rows
  and, unless `relaunch: false`, asks `SpawnPipeline` to start the PTY
  again in the saved cwd.

  This is the process-list snapshot, not a PTY screen dump. Scrollback
  already lives under `~/.canopy/scrollback/<id>.log`.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Agents.SpawnPipeline
  alias Canopy.Repo
  alias Canopy.Sessions.Session

  require Logger

  @snapshot_version 1
  @live_statuses ~w(pending running paused pending_approval)
  @relaunch_statuses ~w(running)

  @type save_result :: %{path: String.t(), count: non_neg_integer()}
  @type restore_result :: %{
          :restored => non_neg_integer(),
          :skipped => non_neg_integer(),
          optional(:error) => atom()
        }

  @doc "Absolute path of the session snapshot file."
  @spec state_path() :: String.t()
  def state_path do
    Application.get_env(:canopy, :session_state_path) ||
      Path.join(System.user_home!(), ".canopy/session-state.json")
  end

  @doc """
  Writes every live session (pending / running / paused / pending_approval)
  to the snapshot file. Completed, cancelled, and failed rows are omitted.
  """
  @spec save_state() :: {:ok, save_result()} | {:error, term()}
  def save_state do
    path = state_path()

    sessions =
      Repo.all(
        from(s in Session, where: s.status in ^@live_statuses, order_by: [asc: s.inserted_at])
      )

    payload = %{
      "version" => @snapshot_version,
      "saved_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "sessions" => Enum.map(sessions, &snapshot_entry/1)
    }

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- atomic_write(path, Jason.encode!(payload)) do
      Logger.info("[Sessions.Persistence] saved #{length(sessions)} session(s) to #{path}")
      {:ok, %{path: path, count: length(sessions)}}
    end
  end

  @doc """
  Reads the snapshot and upserts each entry.

  Options:
    * `:relaunch` — when `true` (default), spawn a PTY for `running`
      entries via `SpawnPipeline`. Tests pass `relaunch: false`.
  """
  @spec restore_state(keyword()) :: {:ok, restore_result()}
  def restore_state(opts \\ []) do
    relaunch? = Keyword.get(opts, :relaunch, true)
    path = state_path()

    case File.read(path) do
      {:error, :enoent} ->
        {:ok, %{restored: 0, skipped: 0}}

      {:error, reason} ->
        Logger.warning("[Sessions.Persistence] could not read #{path}: #{inspect(reason)}")
        {:ok, %{restored: 0, skipped: 0, error: reason}}

      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, %{"version" => @snapshot_version, "sessions" => entries}} when is_list(entries) ->
            tallies =
              Enum.reduce(entries, %{restored: 0, skipped: 0}, fn entry, acc ->
                case restore_entry(entry, relaunch?) do
                  :ok -> %{acc | restored: acc.restored + 1}
                  :skip -> %{acc | skipped: acc.skipped + 1}
                end
              end)

            Logger.info(
              "[Sessions.Persistence] restore restored=#{tallies.restored} skipped=#{tallies.skipped}"
            )

            {:ok, tallies}

          {:ok, _} ->
            {:ok, %{restored: 0, skipped: 0, error: :invalid_snapshot}}

          {:error, _} ->
            Logger.warning("[Sessions.Persistence] invalid snapshot at #{path}")
            {:ok, %{restored: 0, skipped: 0, error: :invalid_snapshot}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec snapshot_entry(Session.t()) :: map()
  defp snapshot_entry(%Session{} = session) do
    %{
      "id" => session.id,
      "kind" => session.kind,
      "runtime_type" => session.runtime_type,
      "model_id" => session.model_id,
      "agent_slug" => session.agent_slug,
      "workspace_slug" => session.workspace_slug,
      "status" => session.status,
      "cwd" => session.cwd,
      "prompt" => session.prompt,
      "prompt_bundle_key" => session.prompt_bundle_key,
      "external_session_id" => session.external_session_id,
      "worktree_path" => session.worktree_path,
      "branch" => session.branch,
      "base_branch" => session.base_branch,
      "parent_session_id" => session.parent_session_id,
      "sequence_number" => session.sequence_number,
      "started_at" => encode_dt(session.started_at)
    }
  end

  @spec restore_entry(map(), boolean()) :: :ok | :skip
  defp restore_entry(entry, relaunch?) when is_map(entry) do
    id = entry["id"]
    attrs = restore_attrs(entry)

    cond do
      Ecto.UUID.cast(id) == :error ->
        :skip

      attrs[:status] not in @live_statuses ->
        :skip

      is_nil(attrs[:runtime_type]) or is_nil(attrs[:cwd]) ->
        :skip

      true ->
        case upsert_session(id, attrs) do
          {:ok, session} ->
            maybe_relaunch(session, relaunch?)
            :ok

          {:error, reason} ->
            Logger.warning(
              "[Sessions.Persistence] restore failed id=#{inspect(id)} reason=#{inspect(reason)}"
            )

            :skip
        end
    end
  end

  defp restore_entry(_entry, _relaunch?), do: :skip

  @spec upsert_session(String.t(), map()) :: {:ok, Session.t()} | {:error, term()}
  defp upsert_session(id, attrs) do
    case Repo.get(Session, id) do
      nil ->
        %Session{id: id}
        |> Session.changeset(attrs)
        |> Repo.insert()

      %Session{status: status} when status not in @live_statuses ->
        {:error, :terminal_session}

      session ->
        # The database is current authority. A stale snapshot must not roll back
        # approval, workspace, status, or resume identity changes.
        {:ok, session}
    end
  end

  @spec maybe_relaunch(Session.t(), boolean()) :: :ok
  defp maybe_relaunch(%Session{status: status} = session, true)
       when status in @relaunch_statuses do
    case SpawnPipeline.spawn(session, wake_reason: "restore") do
      {:ok, _} ->
        :ok

      {:error, stage, reason} ->
        Logger.warning(
          "[Sessions.Persistence] relaunch failed session=#{session.id} stage=#{stage} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  defp maybe_relaunch(_session, _relaunch?), do: :ok

  @spec restore_attrs(map()) :: map()
  defp restore_attrs(entry) do
    %{
      kind: entry["kind"],
      runtime_type: entry["runtime_type"],
      model_id: entry["model_id"],
      agent_slug: entry["agent_slug"],
      workspace_slug: entry["workspace_slug"],
      status: entry["status"],
      cwd: entry["cwd"],
      prompt: entry["prompt"],
      prompt_bundle_key: entry["prompt_bundle_key"],
      external_session_id: entry["external_session_id"],
      worktree_path: entry["worktree_path"],
      branch: entry["branch"],
      base_branch: entry["base_branch"],
      parent_session_id: entry["parent_session_id"],
      sequence_number: entry["sequence_number"],
      started_at: entry["started_at"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  @spec encode_dt(DateTime.t() | nil) :: String.t() | nil
  defp encode_dt(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp encode_dt(_), do: nil

  @spec atomic_write(String.t(), iodata()) :: :ok | {:error, term()}
  defp atomic_write(path, contents) do
    tmp = path <> ".tmp-" <> Integer.to_string(System.unique_integer([:positive]))

    with {:ok, file} <- File.open(tmp, [:write, :binary, :exclusive]) do
      result =
        with :ok <- File.chmod(tmp, 0o600),
             :ok <- IO.binwrite(file, contents),
             :ok <- :file.sync(file) do
          :ok
        end

      File.close(file)

      result = with :ok <- result, do: File.rename(tmp, path)
      if result != :ok, do: File.rm(tmp)
      result
    end
  end
end
