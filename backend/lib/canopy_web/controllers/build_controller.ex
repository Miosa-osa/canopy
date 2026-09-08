defmodule CanopyWeb.BuildController do
  @moduledoc """
  HTTP API for the Build super-super-module.

  Routes:
    GET    /api/v1/build/layouts                       — list saved layouts
    POST   /api/v1/build/layouts                       — create a layout
    GET    /api/v1/build/layouts/:slug                 — show a layout
    PATCH  /api/v1/build/layouts/:slug                 — update a layout
    DELETE /api/v1/build/layouts/:slug                 — archive (soft-delete)
    POST   /api/v1/build/suggest                       — suggest layouts for an intent
    GET    /api/v1/build/default                       — default layout for a workspace
    POST   /api/v1/build/layouts/:slug/set-default     — pin a layout as workspace default
    GET    /api/v1/build/commands                      — multi-source slash-command registry
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Build
  alias Canopy.Build.Commands
  alias CanopyWeb.Schemas.BuildSchema

  action_fallback CanopyWeb.FallbackController

  tags ["build"]

  @max_limit 200
  @default_limit 100
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  @scopes ~w(personal team workspace)

  # ---------------------------------------------------------------------------
  # list_layouts
  # ---------------------------------------------------------------------------

  operation :list_layouts,
    summary: "List saved Build layouts",
    parameters: [
      scope: [in: :query, type: :string, required: false],
      owner_id: [in: :query, type: :string, required: false],
      workspace_slug: [in: :query, type: :string, required: false],
      include_archived: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Layout list", "application/json", BuildSchema.LayoutList}]

  @spec list_layouts(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_layouts(conn, params) do
    with :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      opts =
        []
        |> maybe_put(:scope, params["scope"])
        |> maybe_put(:owner_id, owner_id)
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:include_archived, parse_bool(params["include_archived"]))
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Build.list_layouts(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # show_layout
  # ---------------------------------------------------------------------------

  operation :show_layout,
    summary: "Fetch a saved layout by slug",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      scope: [in: :query, type: :string, required: false],
      owner_id: [in: :query, type: :string, required: false]
    ],
    responses: [ok: {"Layout", "application/json", BuildSchema.Layout}]

  @spec show_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show_layout(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      scope = params["scope"] || "personal"

      case Build.get_layout_by_slug(slug, scope: scope, owner_id: owner_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "layout_not_found", slug: slug, scope: scope})

        layout ->
          json(conn, layout)
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # create_layout
  # ---------------------------------------------------------------------------

  operation :create_layout,
    summary: "Create a saved Build layout",
    request_body: {"Layout create", "application/json", BuildSchema.LayoutCreate},
    responses: [created: {"Layout", "application/json", BuildSchema.Layout}]

  @spec create_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_layout(conn, params) do
    with :ok <- validate_slug(params["slug"]),
         :ok <- validate_scope_opt(params["scope"]) do
      case Build.create_layout(params) do
        {:ok, layout} ->
          conn |> put_status(:created) |> json(layout)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # update_layout
  # ---------------------------------------------------------------------------

  operation :update_layout,
    summary: "Update a saved Build layout",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Layout update", "application/json", BuildSchema.LayoutUpdate},
    responses: [ok: {"Layout", "application/json", BuildSchema.Layout}]

  @spec update_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_layout(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      scope = params["scope"] || "personal"

      case Build.get_layout_by_slug(slug, scope: scope, owner_id: owner_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "layout_not_found", slug: slug, scope: scope})

        layout ->
          attrs = Map.drop(params, ["slug", "scope", "owner_id"])

          case Build.update_layout(layout, attrs) do
            {:ok, updated} -> json(conn, updated)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # archive_layout
  # ---------------------------------------------------------------------------

  operation :archive_layout,
    summary: "Archive (soft-delete) a saved Build layout",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Layout", "application/json", BuildSchema.Layout}]

  @spec archive_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def archive_layout(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      scope = params["scope"] || "personal"

      case Build.get_layout_by_slug(slug, scope: scope, owner_id: owner_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "layout_not_found", slug: slug, scope: scope})

        layout ->
          case Build.archive_layout(layout) do
            {:ok, archived} -> json(conn, archived)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # suggest_layout
  # ---------------------------------------------------------------------------

  operation :suggest_layout,
    summary: "Suggest layouts ranked against a stated intent",
    request_body:
      {"Suggest input", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           intent: %OpenApiSpex.Schema{type: :string},
           scope: %OpenApiSpex.Schema{type: :string},
           owner_id: %OpenApiSpex.Schema{type: :string},
           workspace_slug: %OpenApiSpex.Schema{type: :string}
         },
         required: [:intent]
       }},
    responses: [ok: {"Suggestions", "application/json", BuildSchema.SuggestionResult}]

  @spec suggest_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def suggest_layout(conn, params) do
    with :ok <- require_string(params["intent"], "intent"),
         :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      opts =
        []
        |> maybe_put(:scope, params["scope"])
        |> maybe_put(:owner_id, owner_id)
        |> maybe_put(:workspace_slug, params["workspace_slug"])

      results =
        params["intent"]
        |> Build.suggest_layout(opts)
        |> Enum.map(fn %{layout: layout, score: score} ->
          %{
            slug: layout.slug,
            name: layout.name,
            scope: layout.scope,
            description: layout.description,
            use_count: layout.use_count,
            score: score
          }
        end)

      json(conn, %{intent: params["intent"], count: length(results), suggestions: results})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # default_layout
  # ---------------------------------------------------------------------------

  operation :default_layout,
    summary: "Default layout for a workspace",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: true]
    ],
    responses: [ok: {"Layout or empty", "application/json", BuildSchema.Layout}]

  @spec default_layout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def default_layout(conn, params) do
    case params["workspace_slug"] do
      ws when is_binary(ws) and ws != "" ->
        case Build.default_layout(ws) do
          nil -> json(conn, %{data: nil})
          layout -> json(conn, %{data: layout})
        end

      _ ->
        bad_request(conn, "workspace_slug is required")
    end
  end

  # ---------------------------------------------------------------------------
  # set_default
  # ---------------------------------------------------------------------------

  operation :set_default,
    summary: "Pin a saved layout as the workspace default",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Set default", "application/json", BuildSchema.SetDefaultRequest},
    responses: [ok: {"Layout", "application/json", BuildSchema.Layout}]

  @spec set_default(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def set_default(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         {:ok, ws} <- require_workspace(params["workspace_slug"]),
         :ok <- validate_scope_opt(params["scope"]),
         {:ok, owner_id} <- validate_uuid_opt(params["owner_id"]) do
      scope = params["scope"] || "personal"

      case Build.get_layout_by_slug(slug, scope: scope, owner_id: owner_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "layout_not_found", slug: slug, scope: scope})

        layout ->
          case Build.set_default(layout, ws) do
            {:ok, updated} -> json(conn, updated)
            {:error, changeset} -> {:error, changeset}
          end
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # commands — multi-source slash command registry
  # ---------------------------------------------------------------------------

  operation :commands,
    summary:
      "List slash commands aggregated across builtin / runtimes / drive / templates / skills",
    parameters: [
      q: [
        in: :query,
        type: :string,
        required: false,
        description: "Substring filter on name+description"
      ],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Command list", "application/json", BuildSchema.CommandList}]

  @spec commands(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def commands(conn, params) do
    opts =
      []
      |> maybe_put(:q, params["q"])
      |> maybe_put(:limit, parse_limit(params["limit"]))

    json(conn, %{data: Commands.list(opts)})
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp parse_limit(nil), do: @default_limit
  defp parse_limit(""), do: @default_limit
  defp parse_limit(n) when is_integer(n) and n > 0, do: min(n, @max_limit)

  defp parse_limit(s) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} when n > 0 -> min(n, @max_limit)
      _ -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp parse_bool(nil), do: nil
  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: nil

  defp validate_slug(str) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error, "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  defp validate_scope_opt(nil), do: :ok
  defp validate_scope_opt(""), do: :ok
  defp validate_scope_opt(s) when s in @scopes, do: :ok

  defp validate_scope_opt(_),
    do: {:error, "scope must be one of: #{Enum.join(@scopes, ", ")}"}

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}

  defp validate_uuid_opt(str) when is_binary(str) do
    if Regex.match?(@uuid_regex, str), do: {:ok, str}, else: {:error, "invalid uuid"}
  end

  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

  defp require_string(s, _name) when is_binary(s) and s != "", do: :ok
  defp require_string(_, name), do: {:error, "#{name} is required"}

  defp require_workspace(s) when is_binary(s) and s != "", do: {:ok, s}
  defp require_workspace(_), do: {:error, "workspace_slug is required"}

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
