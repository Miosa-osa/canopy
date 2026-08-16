defmodule Canopy.Reviews do
  @moduledoc """
  Context for the human-review approval queue.

  ## Two flows

  ### Flow A: Artifact review
  When an agent creates a doc / task / issue / PR / file / kb_chunk and governance
  marks it `requires_review`, the artifact is staged here. A human approves, rejects,
  or requests changes via the review queue. The agent receives a PubSub event on the
  `reviews:workspace:<workspace_slug>` topic.

  ### Flow B: Inline tool-call approval
  When an agent session tries to invoke a dangerous tool (e.g., `exec_shell`,
  `send_email`, `create_pr`), a tool_call review is created. The session polls
  `GET /api/v1/reviews/:id` every 2 s (max 60 s) and proceeds when status changes
  from `pending`.

  ## API

  - `list/1`                  — query with optional filters
  - `get/1`                   — by uuid
  - `request_artifact/1`      — create artifact review, broadcast PubSub
  - `request_tool_call/3`     — create tool_call review, broadcast PubSub
  - `approve/2`               — pending → approved, broadcast
  - `reject/3`                — pending → rejected, broadcast
  - `request_changes/3`       — pending → changes_requested, broadcast
  """

  import Ecto.Query, only: [from: 2, where: 3]

  alias Canopy.Repo
  alias Canopy.Reviews.Review

  @pubsub Canopy.PubSub
  @default_expiry_hours 24

  # ---------------------------------------------------------------------------
  # Query
  # ---------------------------------------------------------------------------

  @spec list(map()) :: [Review.t()]
  def list(filters \\ %{}) do
    from(r in Review, order_by: [desc: r.requested_at])
    |> maybe_filter_workspace(filters)
    |> maybe_filter_status(filters)
    |> maybe_filter_kind(filters)
    |> maybe_filter_agent(filters)
    |> maybe_filter_session(filters)
    |> Repo.all()
  end

  @doc """
  Return an operational summary for the review queue using the same filters as
  `list/1`.
  """
  @spec summary(map()) :: map()
  def summary(filters \\ %{}) do
    reviews = list(filters)

    %{
      total: length(reviews),
      pending_count: count_status(reviews, "pending"),
      decided_count: Enum.count(reviews, &(&1.status in ["approved", "rejected"])),
      changes_requested_count: count_status(reviews, "changes_requested"),
      by_status: count_by(reviews, & &1.status),
      by_kind: count_by(reviews, & &1.kind),
      by_workspace: count_by(reviews, &(&1.workspace_slug || "global")),
      by_agent: count_by(reviews, &(&1.agent_id || "unassigned")),
      oldest_pending_at: oldest_pending_at(reviews),
      next_expiry_at: next_expiry_at(reviews),
      recent: Enum.take(reviews, 5)
    }
  end

  @spec get(String.t()) :: {:ok, Review.t()} | {:error, :not_found}
  def get(id) when is_binary(id) do
    case Repo.get(Review, id) do
      nil -> {:error, :not_found}
      review -> {:ok, review}
    end
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  @doc """
  Stage an artifact review. Broadcasts `{:review_requested, review}` on
  `reviews:workspace:<workspace_slug>`.
  """
  @spec request_artifact(map()) :: {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def request_artifact(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, @default_expiry_hours * 3600, :second)

    attrs =
      Map.merge(
        %{
          kind: "artifact",
          requested_at: now,
          expires_at: expires_at
        },
        normalize_keys(attrs)
      )

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  @doc """
  Stage a tool-call review for inline session approval.
  Broadcasts `{:review_requested, review}` on `reviews:workspace:<workspace_slug>`.

  The caller (session pty handler) should poll `get/1` every 2 s with a max 60 s
  timeout. When status changes from `pending`, proceed or abort accordingly.
  """
  @spec request_tool_call(String.t() | nil, String.t(), map(), keyword()) ::
          {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def request_tool_call(session_id, tool_name, tool_args \\ %{}, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, @default_expiry_hours * 3600, :second)
    run_id = Keyword.get(opts, :run_id)
    workspace_slug = Keyword.get(opts, :workspace_slug)
    agent_id = Keyword.get(opts, :agent_id)

    attrs = %{
      kind: "tool_call",
      tool_name: tool_name,
      tool_args: tool_args,
      session_id: session_id,
      workspace_slug: workspace_slug,
      agent_id: agent_id,
      requested_at: now,
      expires_at: expires_at,
      created_by_run_id: run_id
    }

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  # ---------------------------------------------------------------------------
  # Decisions
  # ---------------------------------------------------------------------------

  @doc "Approve a pending review. Returns `{:error, :not_pending}` if already decided."
  @spec approve(String.t(), String.t() | nil) ::
          {:ok, Review.t()}
          | {:error, :not_found}
          | {:error, :not_pending}
          | {:error, Ecto.Changeset.t()}
  def approve(id, reviewer_id \\ nil) do
    with {:ok, review} <- get(id),
         :ok <- assert_pending(review) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      review
      |> Review.decision_changeset(%{
        status: "approved",
        reviewer_id: reviewer_id,
        decided_at: now
      })
      |> Repo.update()
      |> tap_broadcast(:review_decided)
    end
  end

  @doc "Reject a pending review."
  @spec reject(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, Review.t()}
          | {:error, :not_found}
          | {:error, :not_pending}
          | {:error, Ecto.Changeset.t()}
  def reject(id, reviewer_id \\ nil, feedback \\ nil) do
    with {:ok, review} <- get(id),
         :ok <- assert_pending(review) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      review
      |> Review.decision_changeset(%{
        status: "rejected",
        reviewer_id: reviewer_id,
        decided_at: now,
        feedback: feedback
      })
      |> Repo.update()
      |> tap_broadcast(:review_decided)
    end
  end

  @doc "Request changes on a pending artifact review. Not valid for tool_call reviews."
  @spec request_changes(String.t(), String.t() | nil, String.t() | nil) ::
          {:ok, Review.t()}
          | {:error, :not_found}
          | {:error, :not_pending}
          | {:error, Ecto.Changeset.t()}
  def request_changes(id, reviewer_id \\ nil, feedback \\ nil) do
    with {:ok, review} <- get(id),
         :ok <- assert_pending(review) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      review
      |> Review.decision_changeset(%{
        status: "changes_requested",
        reviewer_id: reviewer_id,
        decided_at: now,
        feedback: feedback
      })
      |> Repo.update()
      |> tap_broadcast(:review_decided)
    end
  end

  @doc """
  Resubmit a review from `changes_requested` back to `pending`.
  Bumps `revision_count`. Optionally updates `artifact_preview`.
  """
  @spec resubmit(String.t(), map()) ::
          {:ok, Review.t()}
          | {:error, :not_found}
          | {:error, :not_changes_requested}
          | {:error, Ecto.Changeset.t()}
  def resubmit(id, attrs \\ %{}) do
    with {:ok, review} <- get(id),
         :ok <- assert_changes_requested(review) do
      review
      |> Review.resubmit_changeset(attrs)
      |> Repo.update()
      |> tap_broadcast(:review_requested)
    end
  end

  @doc """
  Create a `hire_agent` review gate for `canopy.spawn_session` when the target
  agent has `requires_hire_approval: true` in its config.
  """
  @spec request_hire_agent(String.t() | nil, String.t(), String.t(), map(), keyword()) ::
          {:ok, Review.t()} | {:error, Ecto.Changeset.t()}
  def request_hire_agent(
        parent_session_id,
        child_agent_slug,
        initial_prompt,
        extra_args \\ %{},
        opts \\ []
      ) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires_at = DateTime.add(now, @default_expiry_hours * 3600, :second)
    run_id = Keyword.get(opts, :run_id)
    workspace_slug = Keyword.get(opts, :workspace_slug, "default")

    attrs = %{
      kind: "hire_agent",
      tool_name: "canopy.spawn_session",
      tool_args:
        Map.merge(extra_args, %{
          "parent_session_id" => parent_session_id,
          "child_agent_slug" => child_agent_slug,
          "initial_prompt" => initial_prompt
        }),
      session_id: parent_session_id,
      agent_id: child_agent_slug,
      workspace_slug: workspace_slug,
      requested_at: now,
      expires_at: expires_at,
      created_by_run_id: run_id
    }

    %Review{}
    |> Review.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp assert_pending(%Review{status: "pending"}), do: :ok
  defp assert_pending(_review), do: {:error, :not_pending}

  defp assert_changes_requested(%Review{status: "changes_requested"}), do: :ok
  defp assert_changes_requested(_review), do: {:error, :not_changes_requested}

  defp tap_broadcast(result, event \\ :review_requested)

  defp tap_broadcast({:ok, review} = result, event) do
    topic = "reviews:workspace:#{review.workspace_slug || "global"}"
    Phoenix.PubSub.broadcast(@pubsub, topic, {event, review})
    result
  end

  defp tap_broadcast(error, _event), do: error

  defp maybe_filter_workspace(query, %{workspace_slug: ws}) when is_binary(ws),
    do: where(query, [r], r.workspace_slug == ^ws)

  defp maybe_filter_workspace(query, _), do: query

  defp maybe_filter_status(query, %{status: s}) when is_binary(s),
    do: where(query, [r], r.status == ^s)

  defp maybe_filter_status(query, _), do: query

  defp maybe_filter_kind(query, %{kind: k}) when is_binary(k),
    do: where(query, [r], r.kind == ^k)

  defp maybe_filter_kind(query, _), do: query

  defp maybe_filter_agent(query, %{agent_id: a}) when is_binary(a),
    do: where(query, [r], r.agent_id == ^a)

  defp maybe_filter_agent(query, _), do: query

  defp maybe_filter_session(query, %{session_id: sid}) when is_binary(sid),
    do: where(query, [r], r.session_id == ^sid)

  defp maybe_filter_session(query, _), do: query

  defp count_status(reviews, status), do: Enum.count(reviews, &(&1.status == status))

  defp count_by(reviews, key_fun) do
    reviews
    |> Enum.map(key_fun)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
  end

  defp oldest_pending_at(reviews) do
    reviews
    |> Enum.filter(&(&1.status == "pending"))
    |> Enum.map(& &1.requested_at)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(&datetime_lte?/2, fn -> nil end)
  end

  defp next_expiry_at(reviews) do
    reviews
    |> Enum.filter(&(&1.status == "pending"))
    |> Enum.map(& &1.expires_at)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(&datetime_lte?/2, fn -> nil end)
  end

  defp datetime_lte?(left, right), do: DateTime.compare(left, right) != :gt

  @known_string_keys ~w(workspace_slug kind artifact_type artifact_id artifact_preview
                        tool_name tool_args session_id agent_id reviewer_id
                        status feedback requested_at decided_at expires_at revision_count)

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
end
