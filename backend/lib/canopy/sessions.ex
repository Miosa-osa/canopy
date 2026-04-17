defmodule Canopy.Sessions do
  @moduledoc """
  Public API for Canopy session management.

  A session represents one agent execution: a runtime is selected, a prompt is
  submitted, the subprocess runs, and a structured transcript is captured via
  `SessionMessage` records. Sessions form chains via `parent_session_id`.

  The Paperclip triple-key resume pattern uses `id + cwd + prompt_bundle_key`
  to decide whether a session can be resumed without re-injecting skills.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Sessions.{Session, SessionMessage}

  # ---------------------------------------------------------------------------
  # Session lifecycle
  # ---------------------------------------------------------------------------

  @doc "Creates a new session. Returns `{:ok, session}` or `{:error, changeset}`."
  @spec create(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Returns the session by id, raising `Ecto.NoResultsError` if not found."
  @spec get!(binary()) :: Session.t()
  def get!(id), do: Repo.get!(Session, id)

  @doc "Returns sessions matching the given status, ordered by insertion time descending."
  @spec list_by_status(String.t()) :: {:ok, [Session.t()]}
  def list_by_status(status) do
    sessions =
      Repo.all(
        from(s in Session,
          where: s.status == ^status,
          order_by: [desc: s.inserted_at]
        )
      )

    {:ok, sessions}
  end

  @doc """
  Transitions the session status.

  Returns `{:ok, session}`, `{:error, :not_found}`, or `{:error, changeset}`.
  """
  @spec update_status(binary(), String.t()) ::
          {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def update_status(id, status) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        session
        |> Session.status_changeset(%{status: status})
        |> Repo.update()
    end
  end

  @doc """
  Finalizes a session: sets status to `completed`, records `completed_at`,
  and persists cost and token usage.

  Returns `{:ok, session}` or `{:error, :not_found | changeset}`.
  """
  @spec finalize(binary(), map()) ::
          {:ok, Session.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def finalize(id, attrs) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      session ->
        finalize_attrs =
          Map.merge(attrs, %{status: "completed", completed_at: DateTime.utc_now()})

        session
        |> Session.finalize_changeset(finalize_attrs)
        |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Messages (transcript entries)
  # ---------------------------------------------------------------------------

  @doc """
  Appends a `SessionMessage` to the session transcript.

  Returns `{:ok, message}` or `{:error, changeset}`.
  """
  @spec add_message(binary(), map()) ::
          {:ok, SessionMessage.t()} | {:error, Ecto.Changeset.t()}
  def add_message(session_id, attrs) do
    %SessionMessage{}
    |> SessionMessage.changeset(Map.put(attrs, :session_id, session_id))
    |> Repo.insert()
  end

  @doc "Returns all messages for a session, ordered by sequence ascending."
  @spec list_messages(binary()) :: {:ok, [SessionMessage.t()]}
  def list_messages(session_id) do
    messages =
      Repo.all(
        from(m in SessionMessage,
          where: m.session_id == ^session_id,
          order_by: [asc: m.sequence]
        )
      )

    {:ok, messages}
  end

  @doc """
  Legacy stub for the TranscriptEntry streaming path.
  Superseded by `add_message/2`. Retained until Runner is updated.
  """
  @spec append_message(binary(), map()) :: :ok | {:error, term()}
  def append_message(_session_id, _entry), do: {:error, :not_implemented}
end
