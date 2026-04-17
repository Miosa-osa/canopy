defmodule CanopyWeb.HealthController do
  @moduledoc """
  Health + readiness endpoints for Canopy.

  - `GET /api/v1/health` — fast liveness probe. Returns 200 if the web layer is up.
  - `GET /api/v1/health/ready` — slow readiness probe. Verifies database,
    pgvector extension, adapter registry, and Oban are all functional. Returns
    200 with per-check results, or 503 if any check fails.

  Used by the Tauri app's boot flow (block navigation until /ready returns 200),
  by CI smoke tests, and by load balancers.
  """

  use CanopyWeb, :controller

  alias Canopy.{Repo, Runtimes}
  alias Ecto.Adapters.SQL

  action_fallback CanopyWeb.FallbackController

  @doc "GET /api/v1/health — liveness."
  def index(conn, _params) do
    json(conn, %{
      status: "ok",
      version: Application.spec(:canopy, :vsn) |> to_string()
    })
  end

  @doc "GET /api/v1/health/ready — readiness, verifies dependencies."
  def ready(conn, _params) do
    checks = %{
      database: check_database(),
      pgvector: check_pgvector(),
      adapters: check_adapters(),
      oban: check_oban()
    }

    all_ok = Enum.all?(checks, fn {_k, v} -> v.ok end)

    conn
    |> put_status(if all_ok, do: 200, else: 503)
    |> json(%{
      status: if(all_ok, do: "ready", else: "not_ready"),
      version: Application.spec(:canopy, :vsn) |> to_string(),
      checks: checks
    })
  end

  # ---------------------------------------------------------------------------
  # Per-check helpers — each returns %{ok: boolean, detail: String.t()}
  # ---------------------------------------------------------------------------

  defp check_database do
    case SQL.query(Repo, "SELECT 1", []) do
      {:ok, _result} -> %{ok: true, detail: "connected"}
      {:error, reason} -> %{ok: false, detail: inspect(reason)}
    end
  rescue
    e -> %{ok: false, detail: Exception.message(e)}
  end

  defp check_pgvector do
    case SQL.query(Repo, "SELECT extname FROM pg_extension WHERE extname = 'vector'", []) do
      {:ok, %{num_rows: 1}} -> %{ok: true, detail: "installed"}
      {:ok, _none} -> %{ok: false, detail: "extension not present"}
      {:error, reason} -> %{ok: false, detail: inspect(reason)}
    end
  rescue
    e -> %{ok: false, detail: Exception.message(e)}
  end

  defp check_adapters do
    adapters = Runtimes.list_adapters()
    count = length(adapters)

    if count >= 1 do
      %{ok: true, detail: "#{count} adapter(s) registered"}
    else
      %{ok: false, detail: "no adapters registered"}
    end
  rescue
    e -> %{ok: false, detail: Exception.message(e)}
  end

  defp check_oban do
    running? =
      Application.started_applications()
      |> Enum.any?(fn {app, _desc, _vsn} -> app == :oban end)

    if running? do
      %{ok: true, detail: "app running"}
    else
      %{ok: false, detail: "oban application not started"}
    end
  rescue
    e -> %{ok: false, detail: Exception.message(e)}
  end
end
