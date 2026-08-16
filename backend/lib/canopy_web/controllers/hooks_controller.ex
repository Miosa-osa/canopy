defmodule CanopyWeb.HooksController do
  @moduledoc """
  HTTP API for Canopy agent lifecycle hooks.

  Routes:
    POST /api/v1/hooks/notify   — receives a hook event from the notify script
    POST /api/v1/hooks/install  — triggers Manager.install!/0
    POST /api/v1/hooks/uninstall — triggers Manager.uninstall!/0
    GET  /api/v1/hooks/status   — per-runtime install status + last 20 events

  The notify endpoint accepts any JSON body. It normalises the `agent` field
  (defaults to "claude" when absent) and the `event` field, persists to
  hook_events, then broadcasts on `hooks:global` via PubSub.

  Auth: none required for Week-0 dev (all routes open).
  """

  use CanopyWeb, :controller

  alias Canopy.Hooks.{HookEvent, Manager}
  alias Canopy.Repo
  alias Phoenix.PubSub

  require Logger

  import Ecto.Query, only: [from: 2]

  action_fallback CanopyWeb.FallbackController

  @pubsub Canopy.PubSub
  @topic "hooks:global"

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/notify
  # ---------------------------------------------------------------------------

  @doc "Receives a lifecycle hook event from an AI agent notify script."
  def notify(conn, params) do
    agent = normalise_agent(params)
    event = normalise_event(params)
    # The agent's own session identifier string
    agent_session_id = params["session_id"]

    payload = Map.drop(params, ["_format"])

    # Attempt to match a Canopy session by external_session_id or latest_run_id
    {canopy_session_id, run_id} = resolve_canopy_context(agent_session_id, params)

    attrs = %{
      agent: agent,
      event: event,
      session_id: agent_session_id,
      run_id: run_id,
      canopy_session_id: canopy_session_id,
      payload: payload
    }

    case %HookEvent{} |> HookEvent.changeset(attrs) |> Repo.insert() do
      {:ok, hook_event} ->
        broadcast_event(hook_event)

        conn
        |> put_status(200)
        |> json(%{ok: true, hook_event_id: hook_event.id})

      {:error, changeset} ->
        Logger.warning(
          "[HooksController] Invalid hook event: #{inspect(changeset.errors)} params=#{inspect(params)}"
        )

        conn
        |> put_status(422)
        |> json(%{ok: false, errors: format_errors(changeset)})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/install
  # ---------------------------------------------------------------------------

  @doc "Installs Canopy hooks into all supported agent global configs."
  def install(conn, _params) do
    results = Manager.install!()
    json(conn, %{ok: true, results: serialise_results(results)})
  end

  # ---------------------------------------------------------------------------
  # POST /api/v1/hooks/uninstall
  # ---------------------------------------------------------------------------

  @doc "Removes Canopy hooks from all supported agent global configs."
  def uninstall(conn, _params) do
    results = Manager.uninstall!()
    json(conn, %{ok: true, results: serialise_results(results)})
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/hooks/status
  # ---------------------------------------------------------------------------

  @doc "Returns per-runtime install status and the last 20 hook events."
  def show(conn, _params) do
    runtime_status = Manager.status() |> serialise_results()

    recent =
      from(e in HookEvent,
        order_by: [desc: e.inserted_at],
        limit: 20
      )
      |> Repo.all()

    json(conn, %{
      ok: true,
      runtimes: runtime_status,
      recent_events: recent
    })
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp normalise_agent(%{"agent" => a}) when is_binary(a) and a != "", do: a
  defp normalise_agent(_), do: "claude"

  defp normalise_event(%{"hook_event_name" => e}) when is_binary(e), do: e
  defp normalise_event(%{"event" => e}) when is_binary(e), do: e
  defp normalise_event(_), do: "Stop"

  # Attempt to match the hook's session_id against a Canopy session's
  # external_session_id. Returns {canopy_session_id | nil, run_id | nil}.
  defp resolve_canopy_context(nil, _params), do: {nil, nil}

  defp resolve_canopy_context(agent_session_id, _params) when is_binary(agent_session_id) do
    alias Canopy.Sessions.Session

    result =
      from(s in Session,
        where: s.external_session_id == ^agent_session_id,
        select: {s.id, s.latest_run_id},
        limit: 1
      )
      |> Repo.one()

    case result do
      {session_id, run_id} -> {session_id, run_id}
      nil -> {nil, nil}
    end
  rescue
    _ -> {nil, nil}
  end

  defp broadcast_event(hook_event) do
    PubSub.broadcast(@pubsub, @topic, {:hook_event, hook_event})
  rescue
    e ->
      Logger.warning("[HooksController] PubSub broadcast failed: #{Exception.message(e)}")
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp serialise_results(results) do
    Map.new(results, fn {k, v} ->
      {to_string(k),
       case v do
         :ok -> %{status: "ok"}
         :installed -> %{status: "installed"}
         :not_installed -> %{status: "not_installed"}
         {:error, msg} -> %{status: "error", reason: msg}
       end}
    end)
  end
end
