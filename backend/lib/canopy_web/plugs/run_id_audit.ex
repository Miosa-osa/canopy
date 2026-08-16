defmodule CanopyWeb.Plugs.RunIdAudit do
  @moduledoc """
  Reads the `X-Run-Id` header and stamps `conn.assigns.run_id` and
  `conn.assigns.run` for downstream controllers.

  Rules:
  - GETs: X-Run-Id is always optional; ignored if present (no DB hit).
  - Mutations (POST/PUT/PATCH/DELETE) under /api/v1/* except /api/v1/runs/*:
    - If present: validate it exists in DB; 422 if unknown.
    - If absent: passthrough (backward-compat for non-agent clients).
  - /api/v1/runs/* routes: always passthrough (avoids circular dependency).
  """

  import Plug.Conn

  require Logger

  alias Canopy.Runs

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, _opts) do
    run_id_header = get_req_header(conn, "x-run-id") |> List.first()

    cond do
      # Skip for GET requests — no stamping needed, no enforcement
      conn.method == "GET" ->
        conn

      # Skip for /api/v1/runs/* to avoid circular dependency
      runs_route?(conn) ->
        conn

      # No header present — passthrough for backward compat
      is_nil(run_id_header) ->
        conn

      # Header present — validate and stamp
      true ->
        validate_and_stamp(conn, run_id_header)
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp runs_route?(%Plug.Conn{path_info: ["api", "v1", "runs" | _]}), do: true
  defp runs_route?(_), do: false

  defp validate_and_stamp(conn, run_id) do
    case Runs.get(run_id) do
      {:ok, run} ->
        conn
        |> assign(:run_id, run.id)
        |> assign(:run, run)

      {:error, :not_found} ->
        Logger.warning(
          "[RunIdAudit] unknown run_id=#{run_id} on #{conn.method} #{conn.request_path}"
        )

        body = Jason.encode!(%{error: "invalid_run_id", message: "Run '#{run_id}' not found."})

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, body)
        |> halt()
    end
  end
end
