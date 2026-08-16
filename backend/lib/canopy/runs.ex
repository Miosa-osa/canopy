defmodule Canopy.Runs do
  @moduledoc """
  Context for the Runs domain.

  A run is an execution record that ties every agent-originated action back to a
  specific tracked invocation. Every mutation request that carries an `X-Run-Id`
  header is attributed to the run identified by that header.

  Short IDs use the format R-XXXXXXXX (8 random uppercase hex characters).

  ## API

  - `start/1`              — insert with status=:queued, return run
  - `mark_running/2`       — transition queued → running, record process_pid
  - `mark_paused/1`        — transition running → paused
  - `mark_resumed/1`       — transition paused → running
  - `mark_finished/4`      — transition to succeeded | failed | cancelled
  - `get/1`               — accept uuid OR short_id
  - `list/1`              — filter by session_id, workspace_slug, agent_slug, status
  - `append_usage/2`       — merge delta into usage_json atomically
  """

  import Ecto.Query, only: [from: 2, where: 3]

  require Logger

  alias Canopy.Repo
  alias Canopy.Runs.Events
  alias Canopy.Runs.Run
  alias Canopy.Sessions

  # ---------------------------------------------------------------------------
  # Writes
  # ---------------------------------------------------------------------------

  @spec start(map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def start(attrs) do
    normalized = normalize_keys(attrs)

    attrs_with_defaults =
      normalized
      |> Map.put_new(:short_id, generate_short_id())
      |> Map.put_new(:status, "queued")
      |> Map.put_new(:started_at, DateTime.utc_now() |> DateTime.truncate(:second))
      |> Map.put_new(:usage_json, %{})

    result =
      %Run{}
      |> Run.changeset(attrs_with_defaults)
      |> Repo.insert()

    case result do
      {:ok, run} ->
        maybe_stamp_session_latest_run(run)
        {:ok, run}

      error ->
        error
    end
  end

  @spec mark_running(String.t(), integer() | nil) ::
          {:ok, Run.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_running(run_id, process_pid \\ nil) do
    with {:ok, run} <- get(run_id),
         {:ok, updated} <-
           run
           |> Run.changeset(%{status: "running", process_pid: process_pid})
           |> Repo.update() do
      Events.run_started(%{
        run_id: updated.id,
        short_id: updated.short_id,
        session_id: updated.session_id,
        workspace_slug: updated.workspace_slug || "default",
        agent_slug: updated.agent_slug,
        started_at: DateTime.to_iso8601(updated.started_at || DateTime.utc_now())
      })

      {:ok, updated}
    end
  end

  @spec mark_paused(String.t()) ::
          {:ok, Run.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_paused(run_id) do
    with {:ok, run} <- get(run_id),
         {:ok, updated} <- run |> Run.changeset(%{status: "paused"}) |> Repo.update() do
      Events.run_status(%{
        run_id: updated.id,
        short_id: updated.short_id,
        workspace_slug: updated.workspace_slug || "default",
        status: "paused",
        at: DateTime.to_iso8601(DateTime.utc_now())
      })

      {:ok, updated}
    end
  end

  @spec mark_resumed(String.t()) ::
          {:ok, Run.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_resumed(run_id) do
    with {:ok, run} <- get(run_id),
         {:ok, updated} <- run |> Run.changeset(%{status: "running"}) |> Repo.update() do
      Events.run_status(%{
        run_id: updated.id,
        short_id: updated.short_id,
        workspace_slug: updated.workspace_slug || "default",
        status: "running",
        at: DateTime.to_iso8601(DateTime.utc_now())
      })

      {:ok, updated}
    end
  end

  @spec mark_finished(String.t(), String.t(), map(), String.t() | nil) ::
          {:ok, Run.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_finished(run_id, status, usage_json \\ %{}, error \\ nil)
      when status in ~w(succeeded failed cancelled) do
    with {:ok, run} <- get(run_id) do
      merged_usage = merge_usage(run.usage_json || %{}, usage_json || %{})
      finished_at = DateTime.utc_now() |> DateTime.truncate(:second)

      result =
        run
        |> Run.changeset(%{
          status: status,
          finished_at: finished_at,
          usage_json: merged_usage,
          error_reason: error
        })
        |> Repo.update()

      case result do
        {:ok, updated} ->
          Events.run_finished(%{
            run_id: updated.id,
            short_id: updated.short_id,
            workspace_slug: updated.workspace_slug || "default",
            status: status,
            usage_json: merged_usage,
            finished_at: DateTime.to_iso8601(finished_at)
          })

          {:ok, updated}

        error ->
          error
      end
    end
  end

  @doc """
  Merges `delta` into the run's `usage_json` via a single atomic UPDATE.

  Delta keys (all optional):
    tokens_in, tokens_out, cache_read, cache_write, cost_usd
  """
  @spec append_usage(String.t(), map()) ::
          {:ok, Run.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def append_usage(run_id, delta) when is_map(delta) do
    with {:ok, run} <- get(run_id) do
      merged = merge_usage(run.usage_json || %{}, delta)

      run
      |> Run.changeset(%{usage_json: merged})
      |> Repo.update()
    end
  end

  @doc """
  Returns normalized transcript blocks for a run in chronological order.

  Each block is `{kind, payload, at}` where kind ∈
  `:stdout | :stderr | :tool_call | :tool_result | :thinking | :user_prompt |
   :permission_request | :exit`.

  Sources:
  - `hook_events` joined to the run via run_id
  - `agent_tool_calls` joined to the run via run_id
  - Scrollback file referenced by run.log_ref (NDJSON lines)
  """
  @spec transcript(String.t() | Run.t(), keyword()) :: [map()]
  def transcript(run_or_id, _opts \\ [])

  def transcript(%Run{} = run, opts) do
    do_transcript(run, opts)
  end

  def transcript(run_id, opts) when is_binary(run_id) do
    case get(run_id) do
      {:ok, run} -> do_transcript(run, opts)
      {:error, _} -> []
    end
  end

  defp do_transcript(run, _opts) do
    hook_blocks = load_hook_blocks(run)
    tool_blocks = load_tool_blocks(run)
    scrollback_blocks = load_scrollback_blocks(run)

    (hook_blocks ++ tool_blocks ++ scrollback_blocks)
    |> Enum.sort_by(fn %{at: at} -> at end)
  end

  defp load_hook_blocks(%Run{id: run_id}) do
    import Ecto.Query, only: [from: 2]

    from(he in Canopy.Hooks.HookEvent,
      where: he.run_id == ^run_id,
      order_by: [asc: he.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(&hook_to_block/1)
  end

  defp hook_to_block(he) do
    kind =
      case he.event do
        "UserPromptSubmit" -> :user_prompt
        "PermissionRequest" -> :permission_request
        "Stop" -> :exit
        "PostToolUse" -> :tool_result
        "PostToolUseFailure" -> :tool_result
        _ -> :stdout
      end

    %{
      kind: kind,
      payload: Map.merge(%{"event" => he.event, "agent" => he.agent}, he.payload || %{}),
      at: DateTime.to_iso8601(he.inserted_at)
    }
  end

  defp load_tool_blocks(%Run{id: run_id}) do
    import Ecto.Query, only: [from: 2]

    from(tc in Canopy.Agents.ToolCall,
      where: tc.run_id == ^run_id,
      order_by: [asc: tc.inserted_at]
    )
    |> Repo.all()
    |> Enum.flat_map(&tool_call_to_blocks/1)
  end

  defp tool_call_to_blocks(tc) do
    at = DateTime.to_iso8601(tc.inserted_at)

    call_block = %{
      kind: :tool_call,
      payload: %{
        "tool_name" => tc.tool_name,
        "params" => tc.params,
        "agent_id" => tc.agent_id
      },
      at: at
    }

    result_block =
      if tc.result || tc.error do
        %{
          kind: :tool_result,
          payload: %{
            "tool_name" => tc.tool_name,
            "status" => tc.status,
            "result" => tc.result,
            "error" => tc.error
          },
          at: at
        }
      end

    [call_block | List.wrap(result_block)]
  end

  defp load_scrollback_blocks(%Run{log_ref: nil}), do: []

  defp load_scrollback_blocks(%Run{log_ref: log_ref}) do
    path =
      case log_ref do
        "file://" <> p -> p
        p -> p
      end

    case File.read(path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_scrollback_line/1)

      {:error, _} ->
        []
    end
  end

  defp parse_scrollback_line(line) do
    case Jason.decode(line) do
      {:ok, %{"kind" => kind} = parsed} ->
        %{
          kind: String.to_existing_atom(kind),
          payload: Map.delete(parsed, "kind"),
          at: Map.get(parsed, "at", DateTime.to_iso8601(DateTime.utc_now()))
        }

      {:ok, parsed} ->
        %{kind: :stdout, payload: parsed, at: Map.get(parsed, "at", "")}

      {:error, _} ->
        %{kind: :stdout, payload: %{"data" => line}, at: ""}
    end
  rescue
    _ -> %{kind: :stdout, payload: %{"data" => line}, at: ""}
  end

  # ---------------------------------------------------------------------------
  # Reads
  # ---------------------------------------------------------------------------

  @spec get(String.t()) :: {:ok, Run.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} ->
        case Repo.get(Run, id) do
          nil -> {:error, :not_found}
          run -> {:ok, run}
        end

      :error ->
        # Treat as short_id
        case Repo.get_by(Run, short_id: id) do
          nil -> {:error, :not_found}
          run -> {:ok, run}
        end
    end
  end

  @spec list(map()) :: [Run.t()]
  def list(filters \\ %{}) do
    limit = filters |> Map.get(:limit, 50) |> min(200)

    from(r in Run, order_by: [desc: r.started_at], limit: ^limit)
    |> maybe_filter_session(filters)
    |> maybe_filter_workspace(filters)
    |> maybe_filter_agent(filters)
    |> maybe_filter_status(filters)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_short_id do
    hex = :crypto.strong_rand_bytes(4) |> Base.encode16()
    "R-#{hex}"
  end

  defp merge_usage(existing, delta) do
    numeric_keys = ~w(tokens_in tokens_out cache_read cache_write)

    Enum.reduce(numeric_keys, existing, fn key, acc ->
      existing_val = Map.get(acc, key, 0)
      delta_val = Map.get(delta, key, Map.get(delta, String.to_atom(key), 0))
      Map.put(acc, key, existing_val + delta_val)
    end)
    |> merge_cost_usd(delta)
  end

  defp merge_cost_usd(acc, delta) do
    existing_cost = parse_decimal(Map.get(acc, "cost_usd", "0"))
    delta_cost = parse_decimal(Map.get(delta, "cost_usd", Map.get(delta, :cost_usd, "0")))

    Map.put(acc, "cost_usd", Decimal.to_string(Decimal.add(existing_cost, delta_cost)))
  end

  defp parse_decimal(val) when is_binary(val) do
    case Decimal.parse(val) do
      {d, ""} -> d
      _ -> Decimal.new(0)
    end
  end

  defp parse_decimal(val) when is_float(val), do: Decimal.from_float(val)
  defp parse_decimal(val) when is_integer(val), do: Decimal.new(val)
  defp parse_decimal(%Decimal{} = d), do: d
  defp parse_decimal(_), do: Decimal.new(0)

  defp maybe_stamp_session_latest_run(%Run{session_id: nil}), do: :ok

  defp maybe_stamp_session_latest_run(%Run{session_id: session_id, id: run_id}) do
    case Sessions.get(session_id) do
      {:ok, session} ->
        session
        |> Ecto.Changeset.change(%{latest_run_id: run_id})
        |> Repo.update()

        :ok

      _ ->
        :ok
    end
  end

  @known_string_keys ~w(short_id session_id agent_slug workspace_slug issue_short_id
                        task_short_id project_slug status prompt_bundle_key log_ref
                        wake_reason error_reason)

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

  defp maybe_filter_session(query, %{session_id: sid}) when is_binary(sid),
    do: where(query, [r], r.session_id == ^sid)

  defp maybe_filter_session(query, _), do: query

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [r], r.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_agent(query, %{agent_slug: slug}) when is_binary(slug),
    do: where(query, [r], r.agent_slug == ^slug)

  defp maybe_filter_agent(query, _), do: query

  defp maybe_filter_status(query, %{status: status}) when is_binary(status),
    do: where(query, [r], r.status == ^status)

  defp maybe_filter_status(query, _), do: query
end
