defmodule Canopy.Miosa do
  @moduledoc """
  Public API for MIOSA compute sandbox operations.

  MIOSA provisions ephemeral VMs (Firecracker-based) on demand.  Canopy uses
  sandboxes to give agent sessions an isolated compute environment.  The agent
  process runs inside the sandbox; adapter env injection (Track C) reads
  `miosa_sandbox_url` from the session row and injects `CANOPY_MIOSA_SANDBOX_URL`.

  ## Sandbox lifecycle per session

  1. `provision_for_session/2` — request a new VM; stores sandbox ID + URL on the
     session row with `miosa_sandbox_status: "provisioning"`.
  2. MIOSA signals ready → `mark_ready/1` transitions status to `"ready"` and
     broadcasts on PubSub so the frontend can display the sandbox panel.
  3. Agent runs.
  4. `destroy_for_session/1` — terminate VM; updates status to `"destroyed"`.

  When `configured?/0` returns `false` (no `MIOSA_API_URL` / `MIOSA_API_KEY` set),
  `provision_for_session/2` skips provisioning and returns `{:ok, session}` with
  `miosa_sandbox_status: "skipped"`.  This lets the app work in local dev without
  MIOSA credentials.

  ## Track C note

  The adapter env injection (adding `CANOPY_MIOSA_SANDBOX_URL` to the process env)
  is owned by Track C (`lib/canopy/sessions/resume.ex` + adapter args modules).
  Track C should call `Canopy.Sessions.get/1` which now returns `miosa_sandbox_url`.
  """

  alias Canopy.Repo
  alias Canopy.Sessions
  alias Canopy.Sessions.Session

  require Logger

  @pubsub Canopy.PubSub

  # ---------------------------------------------------------------------------
  # Configuration check
  # ---------------------------------------------------------------------------

  @doc """
  Returns `true` when both `MIOSA_API_URL` and `MIOSA_API_KEY` are configured.

  Use this guard before calling any provisioning functions.  The app works
  without MIOSA for local development.
  """
  @spec configured?() :: boolean()
  def configured? do
    url = Application.get_env(:canopy, :miosa_api_url)
    key = Application.get_env(:canopy, :miosa_api_key)
    is_binary(url) and url != "" and is_binary(key) and key != ""
  end

  # ---------------------------------------------------------------------------
  # Session-scoped operations
  # ---------------------------------------------------------------------------

  @doc """
  Provisions a MIOSA sandbox for the given session.

  If MIOSA is not configured, sets `miosa_sandbox_status` to `"skipped"` and
  returns `{:ok, session}` — the session remains functional without a sandbox.

  ## Options
    - `:template` — VM template (default `"default"`)
    - `:ttl_seconds` — sandbox TTL in seconds (default `3600`)

  ## Returns
    - `{:ok, session}` with sandbox fields populated
    - `{:error, :not_found}` when session ID is invalid
    - `{:error, term}` on MIOSA API failure
  """
  @spec provision_for_session(binary(), keyword()) ::
          {:ok, Session.t()} | {:error, :not_found | term()}
  def provision_for_session(session_id, opts \\ []) do
    with {:session, {:ok, session}} <- {:session, Sessions.get(session_id)} do
      if configured?() do
        do_provision(session, opts)
      else
        update_sandbox_fields(session, %{miosa_sandbox_status: "skipped"})
      end
    else
      {:session, {:error, :not_found}} -> {:error, :not_found}
    end
  end

  @doc """
  Transitions a sandbox to `"ready"` status and broadcasts on PubSub.

  Called when MIOSA signals the VM is ready to accept connections.

  ## Returns
    - `{:ok, session}` on success
    - `{:error, :not_found}` when no session has this sandbox ID
    - `{:error, changeset}` on DB write failure
  """
  @spec mark_ready(String.t()) :: {:ok, Session.t()} | {:error, :not_found | term()}
  def mark_ready(sandbox_id) when is_binary(sandbox_id) do
    case find_by_sandbox_id(sandbox_id) do
      nil ->
        {:error, :not_found}

      session ->
        case update_sandbox_fields(session, %{miosa_sandbox_status: "ready"}) do
          {:ok, updated} ->
            Phoenix.PubSub.broadcast(
              @pubsub,
              "session:#{updated.id}",
              {:sandbox_ready, %{sandbox_id: sandbox_id, url: updated.miosa_sandbox_url}}
            )

            {:ok, updated}

          err ->
            err
        end
    end
  end

  @doc """
  Destroys the MIOSA sandbox associated with the given session.

  Calls the MIOSA API and then transitions the session's sandbox status to
  `"destroyed"`.  If no sandbox is attached, returns `{:ok, session}` without
  making any API call.

  ## Returns
    - `{:ok, session}`
    - `{:error, :not_found}`
    - `{:error, term}`
  """
  @spec destroy_for_session(binary()) ::
          {:ok, Session.t()} | {:error, :not_found | term()}
  def destroy_for_session(session_id) do
    case Sessions.get(session_id) do
      {:error, :not_found} ->
        {:error, :not_found}

      {:ok, %Session{miosa_sandbox_id: nil} = session} ->
        {:ok, session}

      {:ok, %Session{miosa_sandbox_id: sandbox_id} = session} ->
        case client().destroy_sandbox(sandbox_id) do
          :ok ->
            update_sandbox_fields(session, %{miosa_sandbox_status: "destroyed"})

          {:error, :not_found} ->
            # Already gone on MIOSA side — still update local state
            update_sandbox_fields(session, %{miosa_sandbox_status: "destroyed"})

          {:error, reason} ->
            Logger.warning(
              "[Canopy.Miosa] destroy_sandbox failed sandbox_id=#{sandbox_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  @doc """
  Returns the sandbox status atom for a session, or `nil` if none is set.

  Reads from the DB — does NOT call the MIOSA API.
  """
  @spec get_sandbox_status(binary()) :: String.t() | nil
  def get_sandbox_status(session_id) do
    case Sessions.get(session_id) do
      {:ok, session} -> session.miosa_sandbox_status
      {:error, :not_found} -> nil
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_provision(session, opts) do
    case client().provision_sandbox(opts) do
      {:ok, %{sandbox_id: sandbox_id, url: url}} ->
        update_sandbox_fields(session, %{
          miosa_sandbox_id: sandbox_id,
          miosa_sandbox_url: url,
          miosa_sandbox_status: "provisioning"
        })

      {:error, reason} ->
        Logger.warning(
          "[Canopy.Miosa] provision_sandbox failed session_id=#{session.id}: #{inspect(reason)}"
        )

        update_sandbox_fields(session, %{miosa_sandbox_status: "failed"})
    end
  end

  @spec update_sandbox_fields(Session.t(), map()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  defp update_sandbox_fields(session, attrs) do
    session
    |> Session.sandbox_changeset(attrs)
    |> Repo.update()
  end

  @spec find_by_sandbox_id(String.t()) :: Session.t() | nil
  defp find_by_sandbox_id(sandbox_id) do
    Repo.get_by(Session, miosa_sandbox_id: sandbox_id)
  end

  @spec client() :: module()
  defp client do
    Application.get_env(:canopy, :miosa_client, Canopy.Miosa.Client)
  end
end
