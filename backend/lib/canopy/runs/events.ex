defmodule Canopy.Runs.Events do
  @moduledoc """
  Fire-and-forget PubSub emitter for run lifecycle events.

  Every public function broadcasts on two topics simultaneously:
    - `live_runs:workspace:<slug>` — subscribers watching a whole workspace
    - `live_runs:run:<short_id>`   — subscribers watching one specific run
  And also on `live_runs:all` for admin/debug consumers.

  All broadcasts are async (Phoenix.PubSub.broadcast/3) and never block
  the caller. Callers must not rely on delivery — this is telemetry, not RPC.
  """

  @pubsub Canopy.PubSub

  @spec run_started(map()) :: :ok
  def run_started(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_started, payload)

  @spec run_status(map()) :: :ok
  def run_status(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_status, payload)

  @spec run_log(map()) :: :ok
  def run_log(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_log, payload)

  @spec run_event(map()) :: :ok
  def run_event(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_event, payload)

  @spec run_tool_call(map()) :: :ok
  def run_tool_call(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_tool_call, payload)

  @spec run_tool_result(map()) :: :ok
  def run_tool_result(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_tool_result, payload)

  @spec run_finished(map()) :: :ok
  def run_finished(%{short_id: short_id, workspace_slug: slug} = payload),
    do: broadcast_all(short_id, slug, :run_finished, payload)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp broadcast_all(short_id, workspace_slug, event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, "live_runs:run:#{short_id}", {event, payload})
    Phoenix.PubSub.broadcast(@pubsub, "live_runs:workspace:#{workspace_slug}", {event, payload})
    Phoenix.PubSub.broadcast(@pubsub, "live_runs:all", {event, payload})
    :ok
  end
end
