defmodule Canopy.Sessions.Resume do
  @moduledoc """
  Manages external session ID persistence and lookup for session resume.

  Persists `{workspace_slug, agent_slug, cwd}` → `external_session_id` on every
  `:result` event from an adapter. On new session creation, looks up the most
  recent `external_session_id` for this agent+workspace+cwd triple and injects
  it so the adapter can pass `--resume`.

  ## Lookup rules

  A session is considered resumable when all of the following hold:
  - `status == "completed"` — partial/failed runs are never resumed.
  - `inserted_at` within the last 30 days — stale context caches are avoided.
  - `cwd` matches exactly after `Path.expand/1` normalization.
  - `prompt_bundle_key` matches when both stored and current are non-empty
    (triple-key fallback; ignored when either side is absent).

  ## Cross-layer contract

  This module only touches the database through `Canopy.Repo`. It never calls
  adapter functions — cross-layer calls from Sessions.Resume into runtime
  adapters are forbidden.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Sessions.Session

  @thirty_days_seconds 30 * 24 * 60 * 60

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Finds the most recent resumable `external_session_id` for the given triple.

  Returns `{:ok, external_session_id}` when a matching completed session with a
  stored external_session_id exists within the last 30 days. Returns
  `{:error, :no_resume}` otherwise.

  `cwd` is compared after `Path.expand/1` normalization. `prompt_bundle_key`
  is compared only when both stored and current values are non-empty strings.
  Passing `nil` or `""` for `prompt_bundle_key` skips the key check entirely.
  """
  @spec find_resumable(String.t() | nil, String.t() | nil, String.t(), String.t() | nil) ::
          {:ok, String.t()} | {:error, :no_resume}
  def find_resumable(agent_slug, workspace_slug, cwd, prompt_bundle_key \\ nil) do
    effective_workspace = workspace_slug || "default"
    cutoff = DateTime.add(DateTime.utc_now(), -@thirty_days_seconds, :second)
    expanded_cwd = Path.expand(cwd)

    candidates =
      from(s in Session,
        where:
          s.status == "completed" and
            s.agent_slug == ^agent_slug and
            s.workspace_slug == ^effective_workspace and
            not is_nil(s.external_session_id) and
            s.inserted_at >= ^cutoff,
        order_by: [desc: s.inserted_at],
        limit: 10,
        select: [:id, :cwd, :prompt_bundle_key, :external_session_id]
      )
      |> Repo.all()

    case find_matching(candidates, expanded_cwd, prompt_bundle_key) do
      nil -> {:error, :no_resume}
      external_id -> {:ok, external_id}
    end
  end

  @doc """
  Persists an `external_session_id` onto a session row.

  Called by `Canopy.Sessions.add_message/2` whenever a `:result` transcript
  entry carries a `session_id` key from the adapter CLI.

  Returns `{:ok, session}` or `{:error, :not_found | changeset}`.
  """
  @spec persist(String.t(), String.t()) ::
          {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def persist(session_id, external_session_id)
      when is_binary(session_id) and is_binary(external_session_id) and
             external_session_id != "" do
    case Repo.get(Session, session_id) do
      nil ->
        {:error, :not_found}

      session ->
        session
        |> Session.resume_changeset(%{external_session_id: external_session_id})
        |> Repo.update()
    end
  end

  def persist(_session_id, _external_session_id), do: {:error, :not_found}

  @doc """
  Expires a stored external session ID when the adapter rejects it.

  Sets `external_session_id` to `nil` on the most recent completed session that
  carries the given external ID, so the next `find_resumable/4` call returns
  `{:error, :no_resume}` and the adapter starts a fresh session.

  Returns `:ok` whether or not a matching session was found.
  """
  @spec expire(String.t()) :: :ok
  def expire(external_session_id) when is_binary(external_session_id) do
    from(s in Session,
      where: s.external_session_id == ^external_session_id
    )
    |> Repo.update_all(set: [external_session_id: nil])

    :ok
  end

  def expire(_external_session_id), do: :ok

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec find_matching([map()], String.t(), String.t() | nil) :: String.t() | nil
  defp find_matching([], _cwd, _bundle_key), do: nil

  defp find_matching([candidate | rest], cwd, bundle_key) do
    stored_cwd = candidate.cwd |> to_string() |> String.trim()
    cwd_matches = stored_cwd == "" or Path.expand(stored_cwd) == cwd

    key_matches = bundle_key_matches?(candidate.prompt_bundle_key, bundle_key)

    if cwd_matches and key_matches do
      candidate.external_session_id
    else
      find_matching(rest, cwd, bundle_key)
    end
  end

  @spec bundle_key_matches?(String.t() | nil, String.t() | nil) :: boolean()
  defp bundle_key_matches?(stored, current) do
    stored_clean = to_string(stored) |> String.trim()
    current_clean = to_string(current) |> String.trim()

    # Skip check when either side is absent — triple-key match is optional.
    stored_clean == "" or current_clean == "" or stored_clean == current_clean
  end
end
