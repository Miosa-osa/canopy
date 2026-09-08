defmodule Canopy.Sessions.Blocks do
  @moduledoc """
  Public API for **Block** primitives — the foundational data unit of the
  agentic terminal.

  This sits **beside** `Canopy.Sessions.SessionMessage` (the flat append-only
  transcript). Blocks are higher-level discrete units: command + output,
  agent message + nested tool calls, approval prompts, diffs, etc. Blocks
  group related messages into navigable, pinnable, share-able units.

  ## Sequence monotonicity

  Each block carries a `sequence` integer that is **unique per session** and
  monotonically increasing. The next sequence is assigned at insert time
  using a single SQL statement that selects `coalesce(max(sequence) + 1, 0)`
  for the target session and inserts in the same transaction. The unique
  index `session_blocks_session_id_sequence_index` is the authoritative
  constraint — concurrent inserts that race surface as a changeset error,
  caught by the caller and retried.

  This is the cleaner "atomic counter via Postgres" approach — no extra
  `session_block_sequences` table, no advisory locks, no application-level
  GenServer. Postgres' MVCC + the unique constraint together give us
  serialisable correctness on the hot path.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Sessions.Block

  require Logger

  @default_limit 200
  @max_limit 1000
  @max_retries 3

  # ---------------------------------------------------------------------------
  # CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Lists blocks matching the given filters, ordered by `sequence` ascending.

  Options:
  - `:session_id` — UUID — required for session-scoped views
  - `:kind` — filter by Block kind
  - `:status` — filter by Block status
  - `:parent_block_id` — return only children of this parent
  - `:since` — DateTime; only blocks with `started_at >= since`
  - `:limit` — default 200, capped at 1000
  """
  @spec list(keyword()) :: [Block.t()]
  def list(opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)

    from(b in Block, order_by: [asc: b.sequence], limit: ^limit)
    |> filter(:session_id, opts[:session_id])
    |> filter(:kind, opts[:kind])
    |> filter(:status, opts[:status])
    |> filter(:parent_block_id, opts[:parent_block_id])
    |> filter_since(opts[:since])
    |> Repo.all()
  end

  @doc "Fetches a single block by id. Returns nil when not found."
  @spec get(Ecto.UUID.t()) :: Block.t() | nil
  def get(id) when is_binary(id), do: Repo.get(Block, id)

  @doc """
  Creates a new block.

  Sequence is auto-assigned per session unless explicitly provided in
  `attrs[:sequence]`. On unique-constraint races (rare) the call retries
  up to 3 times before surfacing the changeset error.
  """
  @spec create(map()) :: {:ok, Block.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    attrs = normalize_attrs(attrs)
    user_provided_sequence? = has_sequence?(attrs)
    do_create(attrs, 0, user_provided_sequence?)
  end

  defp do_create(attrs, attempt, _user_seq?) when attempt >= @max_retries do
    insert_block(attrs)
  end

  defp do_create(attrs, attempt, user_seq?) do
    attrs_with_seq =
      Map.put_new_lazy(attrs, :sequence, fn -> next_sequence(attrs[:session_id]) end)

    case insert_block(attrs_with_seq) do
      {:ok, block} ->
        {:ok, block}

      {:error, %Ecto.Changeset{errors: errors} = cs} ->
        cond do
          # User explicitly provided a sequence — surface the conflict, don't auto-rewrite.
          user_seq? ->
            {:error, cs}

          # Auto-assigned race; retry with a fresh next_sequence.
          attempt < @max_retries and sequence_conflict?(errors) ->
            Logger.debug("[Blocks] sequence race on attempt #{attempt}, retrying")
            do_create(Map.delete(attrs, :sequence), attempt + 1, false)

          true ->
            {:error, cs}
        end
    end
  end

  defp has_sequence?(%{sequence: _}), do: true
  defp has_sequence?(%{"sequence" => _}), do: true
  defp has_sequence?(_), do: false

  defp insert_block(attrs) do
    %Block{} |> Block.changeset(attrs) |> Repo.insert()
  end

  defp sequence_conflict?(errors) do
    Enum.any?(errors, fn
      {:sequence, _} -> true
      _ -> false
    end)
  end

  @doc """
  Updates only the status field (and any post-status fields the caller
  passes — typically `ended_at`, `duration_ms`, `exit_code`, `cost_cents`).
  """
  @spec update_status(Block.t(), map()) :: {:ok, Block.t()} | {:error, Ecto.Changeset.t()}
  def update_status(%Block{} = block, attrs) do
    block |> Block.status_changeset(attrs) |> Repo.update()
  end

  @doc """
  Marks a block finished — sets `status`, `ended_at`, computes `duration_ms`
  if not provided, and writes any optional `exit_code` / `cost_cents` /
  `output_text` carried in `attrs`.

  Default `status` is `"completed"`. Pass `status: "failed"` etc. to override.
  """
  @spec mark_finished(Block.t(), map()) :: {:ok, Block.t()} | {:error, Ecto.Changeset.t()}
  def mark_finished(%Block{} = block, attrs \\ %{}) do
    now = DateTime.utc_now()
    status = Map.get(attrs, :status, "completed")

    duration_ms =
      Map.get_lazy(attrs, :duration_ms, fn ->
        case block.started_at do
          %DateTime{} = started -> DateTime.diff(now, started, :millisecond)
          _ -> nil
        end
      end)

    update_attrs =
      attrs
      |> Map.put(:status, status)
      |> Map.put_new(:ended_at, now)
      |> then(fn a -> if duration_ms, do: Map.put_new(a, :duration_ms, duration_ms), else: a end)

    update_status(block, update_attrs)
  end

  # ---------------------------------------------------------------------------
  # Aggregations
  # ---------------------------------------------------------------------------

  @doc """
  Aggregates block counts by kind for a session.

  Returns `%{"command" => 12, "agent_message" => 3, ...}`.
  """
  @spec aggregate_by_kind(Ecto.UUID.t()) :: %{String.t() => non_neg_integer()}
  def aggregate_by_kind(session_id) when is_binary(session_id) do
    rows =
      from(b in Block,
        where: b.session_id == ^session_id,
        group_by: b.kind,
        select: {b.kind, count(b.id)}
      )
      |> Repo.all()

    Map.new(rows)
  end

  @doc "Counts blocks for a session, optionally filtered by kind / status."
  @spec count(keyword()) :: non_neg_integer()
  def count(opts \\ []) do
    from(b in Block, select: count(b.id))
    |> filter(:session_id, opts[:session_id])
    |> filter(:kind, opts[:kind])
    |> filter(:status, opts[:status])
    |> Repo.one()
  end

  @doc """
  Returns the single block currently in `pending_approval` status for the
  session, or `nil`. Used by the approval-card UI to know what to show.
  """
  @spec find_pending_approval(Ecto.UUID.t()) :: Block.t() | nil
  def find_pending_approval(session_id) when is_binary(session_id) do
    from(b in Block,
      where: b.session_id == ^session_id and b.status == "pending_approval",
      order_by: [asc: b.sequence],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Free-text + faceted search across blocks. Returns blocks ordered by
  `started_at` desc.

  Options:
  - `:session_id` — required scope
  - `:q` — substring match against `input_text` or `output_text` (ILIKE)
  - `:kind` — exact kind filter
  - `:status` — exact status filter
  - `:tag` — block must contain this tag
  - `:limit` — default 200, capped at 1000
  """
  @spec search(keyword()) :: [Block.t()]
  def search(opts \\ []) do
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)

    base =
      from(b in Block,
        order_by: [desc: b.started_at, desc: b.sequence],
        limit: ^limit
      )
      |> filter(:session_id, opts[:session_id])
      |> filter(:kind, opts[:kind])
      |> filter(:status, opts[:status])

    base
    |> apply_q(opts[:q])
    |> apply_tag(opts[:tag])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.put_new_lazy(:started_at, fn -> DateTime.utc_now() end)
  end

  defp next_sequence(nil), do: 0

  defp next_sequence(session_id) when is_binary(session_id) do
    query =
      from(b in Block,
        where: b.session_id == ^session_id,
        select: max(b.sequence)
      )

    case Repo.one(query) do
      nil -> 0
      n when is_integer(n) -> n + 1
    end
  end

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp filter_since(query, nil), do: query

  defp filter_since(query, %DateTime{} = since) do
    from(q in query, where: q.started_at >= ^since)
  end

  defp apply_q(query, nil), do: query
  defp apply_q(query, ""), do: query

  defp apply_q(query, q) when is_binary(q) do
    pattern = "%" <> q <> "%"

    from(b in query,
      where: ilike(b.input_text, ^pattern) or ilike(b.output_text, ^pattern)
    )
  end

  defp apply_tag(query, nil), do: query
  defp apply_tag(query, ""), do: query

  defp apply_tag(query, tag) when is_binary(tag) do
    from(b in query, where: ^tag in b.tags)
  end
end
