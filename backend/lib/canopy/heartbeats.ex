defmodule Canopy.Heartbeats do
  @moduledoc """
  Context for pty heartbeat telemetry.

  Heartbeats are immutable event rows emitted by live pty runs. They drive the
  activity feed and liveness indicators for the Canopy UI.

  ## Coalescence

  High-frequency :output events are coalesced: if the same session has an
  :output heartbeat inserted within the last 500ms, `record/4` increments
  `byte_count` on the existing row instead of inserting a new one. This keeps
  the table from exploding when an agent dumps megabytes of output.

  Coalescence is implemented via an Ecto.Multi + SELECT-then-update — no
  GenServer buffer required for v1. The SELECT uses the composite index on
  (session_id, kind, inserted_at) and is fast.

  ## Async writes from PtyBridge

  Call `record/4` via `Task.Supervisor.async_nolink(Canopy.TaskSupervisor, ...)`
  so DB writes never block the pty output loop.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Heartbeats.Heartbeat
  alias Canopy.Repo

  require Logger

  @preview_limit 200
  # 500ms in microseconds
  @coalesce_window_us 500_000

  # ---------------------------------------------------------------------------
  # Write
  # ---------------------------------------------------------------------------

  @doc """
  Records a heartbeat event for a session.

  - `session_id` — the session UUID
  - `kind` — one of :output | :input | :error | :exit | :pause | :resume
  - `payload` — binary data from the pty (used for byte_count + preview)
  - `meta` — optional extra context (e.g. %{"exit_code" => 0} for :exit)

  For :output kind, coalesces with an existing row within the last 500ms.
  All other kinds always insert a fresh row.

  Returns {:ok, heartbeat} or {:error, reason}.
  """
  @spec record(binary(), atom(), binary(), map()) ::
          {:ok, Heartbeat.t()} | {:error, term()}
  def record(session_id, kind, payload, meta \\ %{})

  def record(session_id, :output, payload, meta) when is_binary(payload) do
    coalesce_or_insert(session_id, :output, payload, meta)
  end

  def record(session_id, kind, payload, meta) when is_binary(payload) do
    do_insert(session_id, kind, payload, meta)
  end

  def record(session_id, kind, _payload, meta) do
    # Non-binary payload (e.g. called with integer or nil) — insert with 0 bytes
    do_insert(session_id, kind, "", meta)
  end

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  @doc """
  Returns heartbeats for a session, most-recent-first.

  Options:
  - `:limit` — max rows (default 50)
  - `:kind` — filter by kind atom
  """
  @spec list_for_session(binary(), keyword()) :: [Heartbeat.t()]
  def list_for_session(session_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    kind = Keyword.get(opts, :kind)

    from(h in Heartbeat,
      where: h.session_id == ^session_id,
      order_by: [desc: h.inserted_at],
      limit: ^limit
    )
    |> maybe_filter_kind(kind)
    |> Repo.all()
  end

  @doc """
  Returns heartbeats for all sessions in a workspace, most-recent-first.

  Joins through sessions on workspace_slug. Limit defaults to 200.
  """
  @spec list_for_workspace(binary(), keyword()) :: [Heartbeat.t()]
  def list_for_workspace(workspace_slug, opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)

    alias Canopy.Sessions.Session

    from(h in Heartbeat,
      join: s in Session,
      on: s.id == h.session_id,
      where: s.workspace_slug == ^workspace_slug,
      order_by: [desc: h.inserted_at],
      limit: ^limit,
      select: h
    )
    |> Repo.all()
  end

  @doc """
  Returns heartbeats across all sessions (company-level view).

  For v1 single-tenant Canopy this is equivalent to list_for_workspace/2 with
  the default workspace slug. Pass `workspace_slug:` to scope.
  """
  @spec list_for_company(keyword()) :: [Heartbeat.t()]
  def list_for_company(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)
    workspace_slug = Keyword.get(opts, :workspace_slug)

    if workspace_slug do
      list_for_workspace(workspace_slug, limit: limit)
    else
      from(h in Heartbeat,
        order_by: [desc: h.inserted_at],
        limit: ^limit
      )
      |> Repo.all()
    end
  end

  @doc """
  Returns aggregate stats for a session:

  - `total_output_bytes` — sum of byte_count for :output heartbeats
  - `total_input_bytes` — sum of byte_count for :input heartbeats
  - `last_activity_at` — inserted_at of most recent heartbeat
  - `started_at` — inserted_at of first heartbeat
  - `heartbeat_count` — total row count
  """
  @spec stats(binary()) :: map()
  def stats(session_id) do
    rows =
      from(h in Heartbeat,
        where: h.session_id == ^session_id,
        select: %{
          kind: h.kind,
          byte_count: h.byte_count,
          inserted_at: h.inserted_at
        }
      )
      |> Repo.all()

    {output_bytes, input_bytes} =
      Enum.reduce(rows, {0, 0}, fn
        %{kind: :output, byte_count: b}, {out, inp} -> {out + b, inp}
        %{kind: :input, byte_count: b}, {out, inp} -> {out, inp + b}
        _, acc -> acc
      end)

    timestamps = Enum.map(rows, & &1.inserted_at)

    %{
      total_output_bytes: output_bytes,
      total_input_bytes: input_bytes,
      last_activity_at: timestamps |> Enum.max(DateTime, fn -> nil end),
      started_at: timestamps |> Enum.min(DateTime, fn -> nil end),
      heartbeat_count: length(rows)
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec coalesce_or_insert(binary(), atom(), binary(), map()) ::
          {:ok, Heartbeat.t()} | {:error, term()}
  defp coalesce_or_insert(session_id, kind, payload, meta) do
    window_start =
      DateTime.utc_now()
      |> DateTime.add(-@coalesce_window_us, :microsecond)

    # Find the most recent :output heartbeat within the coalesce window
    existing =
      from(h in Heartbeat,
        where:
          h.session_id == ^session_id and
            h.kind == ^kind and
            h.inserted_at >= ^window_start,
        order_by: [desc: h.inserted_at],
        limit: 1
      )
      |> Repo.one()

    case existing do
      nil ->
        do_insert(session_id, kind, payload, meta)

      heartbeat ->
        new_bytes = heartbeat.byte_count + byte_size(payload)

        heartbeat
        |> Ecto.Changeset.change(%{byte_count: new_bytes})
        |> Repo.update()
    end
  end

  @spec do_insert(binary(), atom(), binary(), map()) ::
          {:ok, Heartbeat.t()} | {:error, term()}
  defp do_insert(session_id, kind, payload, meta) do
    bytes = if is_binary(payload), do: byte_size(payload), else: 0
    preview = build_preview(payload)

    %Heartbeat{}
    |> Heartbeat.changeset(%{
      session_id: session_id,
      kind: kind,
      byte_count: bytes,
      preview: preview,
      meta: meta
    })
    |> Repo.insert()
  end

  @spec build_preview(binary()) :: String.t() | nil
  defp build_preview(payload) when is_binary(payload) and byte_size(payload) > 0 do
    # Take first @preview_limit bytes; handle multi-byte UTF-8 safely
    truncated = binary_part(payload, 0, min(byte_size(payload), @preview_limit))

    # Ensure valid UTF-8 — strip invalid sequences rather than crash
    case String.valid?(truncated) do
      true -> truncated
      false -> truncated |> :unicode.characters_to_binary(:utf8, :utf8) |> to_string()
    end
  end

  defp build_preview(_), do: nil

  @spec maybe_filter_kind(Ecto.Query.t(), atom() | nil) :: Ecto.Query.t()
  defp maybe_filter_kind(query, nil), do: query
  defp maybe_filter_kind(query, kind), do: from(h in query, where: h.kind == ^kind)
end
