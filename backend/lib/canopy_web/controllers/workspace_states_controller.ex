defmodule CanopyWeb.WorkspaceStatesController do
  @moduledoc """
  HTTP API for the per-workspace state store.

  Routes:
    GET    /api/v1/workspaces/:workspace_slug/state           — full state map
    GET    /api/v1/workspaces/:workspace_slug/state/:key      — single value
    PUT    /api/v1/workspaces/:workspace_slug/state/:key      — upsert value
    DELETE /api/v1/workspaces/:workspace_slug/state/:key      — drop entry

  Validation mirrors `analytics_controller.ex`:
    * slug/key format (regex, max 128 chars)
    * value size cap (1 MB) → 422 `value_too_large`
    * key count cap (100/workspace) → 422 `too_many_keys`
    * unknown workspace → 404
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Workspaces
  alias Canopy.Workspaces.States
  alias CanopyWeb.Schemas.WorkspaceStatesSchema

  action_fallback CanopyWeb.FallbackController

  tags ["workspaces"]

  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @key_regex ~r/\A[a-z0-9][a-z0-9._-]{0,127}\z/

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_slug/state
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List all state entries for a workspace",
    parameters: [
      workspace_slug: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"State map", "application/json", WorkspaceStatesSchema.StateMap}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"workspace_slug" => slug}) do
    with :ok <- validate_slug(slug, "workspace_slug"),
         {:ok, _ws} <- Workspaces.get_by_slug(slug) do
      json(conn, %{workspace_slug: slug, data: States.list(slug)})
    else
      {:error, :not_found} -> not_found(conn, "workspace_not_found", slug)
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # GET /workspaces/:workspace_slug/state/:key
  # ---------------------------------------------------------------------------

  operation :show,
    summary: "Read one state value by key",
    parameters: [
      workspace_slug: [in: :path, type: :string, required: true],
      key: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"State value", "application/json", WorkspaceStatesSchema.StateValue}]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"workspace_slug" => slug, "key" => key}) do
    with :ok <- validate_slug(slug, "workspace_slug"),
         :ok <- validate_key(key),
         {:ok, _ws} <- Workspaces.get_by_slug(slug),
         {:ok, value} <- States.get(slug, key) do
      json(conn, %{key: key, value: value})
    else
      {:error, :not_found} -> not_found(conn, "state_not_found", "#{slug}/#{key}")
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /workspaces/:workspace_slug/state/:key
  # ---------------------------------------------------------------------------

  operation :put,
    summary: "Insert or replace a state value",
    parameters: [
      workspace_slug: [in: :path, type: :string, required: true],
      key: [in: :path, type: :string, required: true]
    ],
    request_body: {"State put", "application/json", WorkspaceStatesSchema.StatePutBody},
    responses: [ok: {"State value", "application/json", WorkspaceStatesSchema.StateValue}]

  @spec put(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def put(conn, %{"workspace_slug" => slug, "key" => key} = params) do
    with :ok <- validate_slug(slug, "workspace_slug"),
         :ok <- validate_key(key),
         {:ok, value} <- extract_value(params),
         {:ok, _ws} <- Workspaces.get_by_slug(slug),
         {:ok, state} <- States.put(slug, key, value) do
      conn
      |> put_status(:ok)
      |> json(%{key: state.key, value: state.value, updated_at: state.updated_at})
    else
      {:error, :not_found} ->
        not_found(conn, "workspace_not_found", slug)

      {:error, :value_too_large} ->
        unprocessable(conn, "value_too_large", value_too_large_message())

      {:error, :too_many_keys} ->
        unprocessable(conn, "too_many_keys", too_many_keys_message())

      {:error, :invalid_value} ->
        bad_request(conn, "value is not JSON-encodable")

      {:error, %Ecto.Changeset{} = cs} ->
        {:error, cs}

      {:error, reason} ->
        bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /workspaces/:workspace_slug/state/:key
  # ---------------------------------------------------------------------------

  operation :delete,
    summary: "Delete a state entry",
    parameters: [
      workspace_slug: [in: :path, type: :string, required: true],
      key: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Delete confirmation", "application/json", WorkspaceStatesSchema.StateDeleteResponse}
    ]

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"workspace_slug" => slug, "key" => key}) do
    with :ok <- validate_slug(slug, "workspace_slug"),
         :ok <- validate_key(key),
         {:ok, _ws} <- Workspaces.get_by_slug(slug),
         {:ok, _state} <- States.delete(slug, key) do
      json(conn, %{deleted: true, workspace_slug: slug, key: key})
    else
      {:error, :not_found} -> not_found(conn, "state_not_found", "#{slug}/#{key}")
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Validation helpers
  # ---------------------------------------------------------------------------

  defp validate_slug(str, field_name) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error,
       "invalid #{field_name}: must be lowercase alphanumeric/dashes/underscores, 1-128 chars"}
    end
  end

  defp validate_slug(_, field_name), do: {:error, "invalid #{field_name}"}

  defp validate_key(str) when is_binary(str) do
    if Regex.match?(@key_regex, str) do
      :ok
    else
      {:error, "invalid key: must be lowercase alphanumeric/dashes/underscores/dots, 1-128 chars"}
    end
  end

  defp validate_key(_), do: {:error, "invalid key"}

  # PUT body must contain a `"value"` field. `null` is allowed (clears to null).
  # Missing field → 400.
  defp extract_value(%{"value" => value}), do: {:ok, value}
  defp extract_value(_), do: {:error, "request body must include a 'value' field"}

  # ---------------------------------------------------------------------------
  # Response helpers
  # ---------------------------------------------------------------------------

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end

  defp not_found(conn, code, ref) do
    conn
    |> put_status(:not_found)
    |> json(%{error: code, ref: ref})
  end

  defp unprocessable(conn, code, message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: code, message: message})
  end

  defp value_too_large_message do
    cap = States.max_value_bytes()
    "value exceeds #{cap}-byte cap (1 MB per key)"
  end

  defp too_many_keys_message do
    cap = States.max_keys_per_workspace()
    "workspace has reached the #{cap}-key cap; delete unused keys before adding new ones"
  end
end
