defmodule CanopyWeb.SandboxesController do
  @moduledoc """
  HTTP API for MIOSA compute sandbox management.

  Sandboxes are ephemeral VMs provisioned by the MIOSA API and attached to Canopy
  sessions.  Sandbox data is stored as columns on the `sessions` table — there is no
  separate sandboxes table.

  Routes:
    GET    /api/v1/sandboxes               — list all non-destroyed sandboxes
    GET    /api/v1/sandboxes/:sandbox_id   — get sandbox status
    DELETE /api/v1/sandboxes/:sandbox_id   — destroy sandbox and update session
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query, only: [from: 2]

  alias Canopy.Miosa
  alias Canopy.Repo
  alias Canopy.Sessions.Session
  alias CanopyWeb.Schemas.{RuntimeSchema, SandboxSchema}

  require Logger

  action_fallback CanopyWeb.FallbackController

  tags ["sandboxes"]

  operation :index,
    summary: "List active sandboxes",
    description: "Returns all sessions that have a MIOSA sandbox attached (status != destroyed).",
    responses: [
      ok: {"Sandbox list", "application/json", SandboxSchema.SandboxList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _) do
    sandboxes =
      Repo.all(
        from(s in Session,
          where: not is_nil(s.miosa_sandbox_id),
          where: s.miosa_sandbox_status != "destroyed",
          order_by: [desc: s.inserted_at],
          select: %{
            sandbox_id: s.miosa_sandbox_id,
            session_id: s.id,
            url: s.miosa_sandbox_url,
            status: s.miosa_sandbox_status
          }
        )
      )

    json(conn, %{data: sandboxes})
  end

  operation :show,
    summary: "Get sandbox status",
    description: "Returns current status of the MIOSA sandbox with the given ID.",
    parameters: [
      sandbox_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Sandbox", "application/json", SandboxSchema.Sandbox},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"sandbox_id" => sandbox_id}) do
    case find_sandbox(sandbox_id) do
      nil ->
        {:error, :not_found}

      session ->
        json(conn, %{
          sandbox_id: session.miosa_sandbox_id,
          session_id: session.id,
          url: session.miosa_sandbox_url,
          status: session.miosa_sandbox_status
        })
    end
  end

  operation :delete,
    summary: "Destroy a sandbox",
    description:
      "Calls MIOSA to terminate the VM and updates session sandbox status to destroyed.",
    parameters: [
      sandbox_id: [in: :path, type: :string, required: true]
    ],
    responses: [
      no_content: "Sandbox destroyed",
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"sandbox_id" => sandbox_id}) do
    case find_sandbox(sandbox_id) do
      nil ->
        {:error, :not_found}

      session ->
        case Miosa.destroy_for_session(session.id) do
          {:ok, _} ->
            send_resp(conn, :no_content, "")

          {:error, reason} ->
            Logger.error(
              "[SandboxesController] destroy failed sandbox_id=#{sandbox_id}: #{inspect(reason)}"
            )

            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "destroy_failed", message: inspect(reason)})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec find_sandbox(String.t()) :: Session.t() | nil
  defp find_sandbox(sandbox_id) do
    Repo.get_by(Session, miosa_sandbox_id: sandbox_id)
  end
end
