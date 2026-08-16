defmodule CanopyWeb.EngineController do
  @moduledoc """
  HTTP API for Optimal Engine operations on a workspace.

  All actions delegate to `Canopy.Engine.Bridge`, which shells out through
  the workspace's local engine directory.
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Engine.Bridge

  action_fallback CanopyWeb.FallbackController

  tags ["engine"]

  operation :search,
    summary: "Search workspace knowledge base",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Search params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [ok: {"Search results", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def search(conn, %{"slug" => slug, "query" => query} = params) do
    opts = if limit = params["limit"], do: [limit: limit], else: []

    with {:ok, result} <- Bridge.search(slug, query, opts) do
      json(conn, %{data: result})
    end
  end

  def search(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "query is required"})
  end

  operation :ingest,
    summary: "Ingest a signal into workspace engine",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Ingest params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [ok: {"Ingest result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def ingest(conn, %{"slug" => slug, "text" => text} = params) do
    opts = if genre = params["genre"], do: [genre: genre], else: []

    with {:ok, result} <- Bridge.ingest(slug, text, opts) do
      json(conn, %{data: result})
    end
  end

  def ingest(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "text is required"})
  end

  operation :l0,
    summary: "Load L0 cache for workspace engine",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"L0 cache", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def l0(conn, %{"slug" => slug}) do
    with {:ok, result} <- Bridge.l0(slug) do
      json(conn, %{data: result})
    end
  end

  operation :assemble,
    summary: "Assemble tiered context for a topic",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Assemble params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [ok: {"Assembled context", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def assemble(conn, %{"slug" => slug, "topic" => topic}) do
    with {:ok, result} <- Bridge.assemble(slug, topic) do
      json(conn, %{data: result})
    end
  end

  def assemble(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "topic is required"})
  end

  operation :engine_health,
    summary: "Run engine health diagnostic",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Health result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def engine_health(conn, %{"slug" => slug}) do
    with {:ok, result} <- Bridge.health(slug) do
      json(conn, %{data: result})
    end
  end

  operation :remember,
    summary: "Store a key/value observation in workspace memory",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Memory params", "application/json", %OpenApiSpex.Schema{type: :object}},
    responses: [ok: {"Memory result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def remember(conn, %{"slug" => slug, "key" => key, "value" => value}) do
    with {:ok, result} <- Bridge.memory_store(slug, key, value) do
      json(conn, %{data: result})
    end
  end

  def remember(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "key and value are required"})
  end

  operation :recall,
    summary: "Recall a value from workspace memory",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      key: [in: :query, type: :string, required: true]
    ],
    responses: [ok: {"Recall result", "application/json", %OpenApiSpex.Schema{type: :object}}]

  def recall(conn, %{"slug" => slug, "key" => key}) do
    with {:ok, result} <- Bridge.memory_recall(slug, key) do
      json(conn, %{data: result})
    end
  end

  def recall(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: "key is required"})
  end
end
