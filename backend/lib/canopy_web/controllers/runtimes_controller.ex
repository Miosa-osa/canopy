defmodule CanopyWeb.RuntimesController do
  @moduledoc """
  HTTP API for AI runtime adapters.

  Delegates all business logic to `Canopy.Runtimes` and the adapter module
  resolved via the Registry. Returns 404 when the runtime type is unknown.

  Routes:
    GET    /api/v1/runtimes                 — list all runtimes with status
    GET    /api/v1/runtimes/:type           — detail (config_schema, models, quota)
    POST   /api/v1/runtimes/:type/test      — runs adapter preflight
    GET    /api/v1/runtimes/:type/models    — list models via adapter
    POST   /api/v1/runtimes/detect          — upsert from Tauri runtime_detect
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Runtimes
  alias Canopy.Vault
  alias CanopyWeb.Schemas.RuntimeSchema

  action_fallback CanopyWeb.FallbackController

  tags ["runtimes"]

  operation :index,
    summary: "List all runtimes",
    description: "Returns all persisted runtime records ordered by name.",
    responses: [
      ok: {"Runtime list", "application/json", RuntimeSchema.RuntimeList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    {:ok, runtimes} = Runtimes.list()
    json(conn, %{data: runtimes})
  end

  operation :show,
    summary: "Get runtime detail",
    description: "Returns detail for a single runtime including config_schema and quota.",
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Runtime detail", "application/json", RuntimeSchema.RuntimeDetail},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"type" => type}) do
    with {:ok, _found_runtime} <- Runtimes.get_by_type(type),
         {:ok, adapter} <- Runtimes.lookup_adapter(type) do
      {:ok, config_schema} = adapter.get_config_schema()
      {:ok, models} = adapter.list_models()

      quota_windows =
        if MapSet.member?(adapter.capabilities(), :quota_windows) do
          case adapter.get_quota_windows() do
            {:ok, windows} -> windows
            _quota_err -> nil
          end
        end

      detail = %{
        type: type,
        capabilities: adapter.capabilities() |> MapSet.to_list() |> Enum.map(&to_string/1),
        config_schema: config_schema,
        models: models,
        quota_windows: quota_windows
      }

      json(conn, detail)
    else
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  operation :test_environment,
    summary: "Test runtime environment",
    description: "Runs preflight checks for the given runtime type.",
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Preflight result", "application/json", RuntimeSchema.EnvironmentCheckList},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec test_environment(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def test_environment(conn, %{"type" => type}) do
    with {:ok, adapter} <- Runtimes.lookup_adapter(type),
         {:ok, checks} <- adapter.test_environment(%{"type" => type}) do
      json(conn, %{checks: checks})
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  operation :models,
    summary: "List models for a runtime",
    description: "Returns models available for the given runtime type.",
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Model list", "application/json", RuntimeSchema.ModelList},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec models(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def models(conn, %{"type" => type}) do
    with {:ok, adapter} <- Runtimes.lookup_adapter(type),
         {:ok, models} <- adapter.list_models() do
      json(conn, %{data: models})
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  operation :detect,
    summary: "Sync runtime detection results from the desktop client",
    description: """
    The Tauri frontend calls `runtime_detect` (scans $PATH for the 9 canonical
    binaries), then POSTs the result here. Each item is upserted into the
    `runtimes` table via `Canopy.Runtimes.upsert_from_detection/1`, preserving
    user-configured `enabled` and `config` while updating `installed`,
    `version`, `binary_path`, and `last_detected_at`.
    """,
    request_body: {"Detection payload", "application/json", RuntimeSchema.DetectRequest},
    responses: [
      ok: {"Upsert results", "application/json", RuntimeSchema.RuntimeList}
    ]

  @spec detect(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def detect(conn, %{"detected" => detected}) when is_list(detected) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    results =
      detected
      |> Enum.map(&build_attrs(&1, now))
      |> Enum.map(&Runtimes.upsert_from_detection/1)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      updated = Enum.map(results, fn {:ok, runtime} -> runtime end)
      json(conn, %{data: updated})
    else
      {:error, :detection_upsert_failed}
    end
  end

  def detect(_conn, _params), do: {:error, :bad_request}

  operation :put_credentials,
    summary: "Store credentials for a runtime",
    description: """
    Encrypts and persists one or more credential values for the given runtime
    type. Values are stored using AES-256-GCM encryption — plaintext is never
    returned. Calling this again for the same field key replaces the previous value.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    request_body: {"Credential values", "application/json", RuntimeSchema.PutCredentialsRequest},
    responses: [
      ok: {"Stored field keys", "application/json", RuntimeSchema.CredentialFieldList}
    ]

  @spec put_credentials(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def put_credentials(conn, %{"type" => runtime_type, "values" => values})
      when is_map(values) do
    results =
      Enum.map(values, fn {field_key, plaintext} ->
        Vault.put(runtime_type, field_key, to_string(plaintext))
      end)

    if Enum.all?(results, &match?({:ok, _}, &1)) do
      field_keys = Vault.list_fields(runtime_type)
      json(conn, %{runtime_type: runtime_type, field_keys: field_keys})
    else
      {:error, :internal_server_error}
    end
  end

  def put_credentials(_conn, _params), do: {:error, :bad_request}

  operation :get_credentials,
    summary: "List stored credential field keys for a runtime",
    description: """
    Returns the list of field keys that have been stored for the given runtime
    type. Plaintext values are never returned.
    """,
    parameters: [
      type: [in: :path, description: "Runtime type identifier", type: :string, required: true]
    ],
    responses: [
      ok: {"Field key list", "application/json", RuntimeSchema.CredentialFieldList}
    ]

  @spec get_credentials(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_credentials(conn, %{"type" => runtime_type}) do
    field_keys = Vault.list_fields(runtime_type)
    json(conn, %{runtime_type: runtime_type, field_keys: field_keys})
  end

  # Maps the Tauri sidecar's `DetectedRuntime` JSON to our Ecto attrs.
  @spec build_attrs(map(), DateTime.t()) :: map()
  defp build_attrs(item, detected_at) do
    %{
      type: Map.get(item, "slug") || Map.get(item, "type"),
      kind: "cli",
      name: Map.get(item, "name") || Map.get(item, "slug"),
      installed: !!Map.get(item, "installed", false),
      version: Map.get(item, "version"),
      binary_path: Map.get(item, "path") || Map.get(item, "binary_path"),
      last_detected_at: detected_at
    }
  end
end
