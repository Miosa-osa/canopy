defmodule CanopyWeb.TemplatesController do
  @moduledoc """
  HTTP API for the Templates super-module.

  Routes:
    GET    /api/v1/templates                       — list templates (gallery)
    GET    /api/v1/templates/:slug                 — fetch a single template
    POST   /api/v1/templates                       — create a template
    PATCH  /api/v1/templates/:slug                 — update a template
    POST   /api/v1/templates/:slug/preview         — render parameter-substituted preview
    POST   /api/v1/templates/:slug/instantiate     — materialize a template
    POST   /api/v1/templates/:slug/publish         — publish + snapshot version
    POST   /api/v1/templates/:slug/fork            — fork into a new template
    GET    /api/v1/templates/:slug/versions        — list version history
    GET    /api/v1/templates/instantiations        — list instantiation audit log
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Templates
  alias Canopy.Templates.Template
  alias CanopyWeb.Schemas.TemplatesSchema

  action_fallback CanopyWeb.FallbackController

  tags ["templates"]

  @max_limit 1000
  @default_limit 100
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @uuid_regex ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  # ---------------------------------------------------------------------------
  # Index / show
  # ---------------------------------------------------------------------------

  operation :index,
    summary: "List templates",
    description:
      "Returns templates ordered by popularity. Filter by kind, verified, search.",
    parameters: [
      kind: [in: :query, type: :string, required: false],
      verified: [in: :query, type: :string, required: false],
      published: [in: :query, type: :string, required: false],
      search: [in: :query, type: :string, required: false],
      tag: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Template list", "application/json", TemplatesSchema.TemplateList}]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    with :ok <- validate_kind_opt(params["kind"]) do
      opts =
        []
        |> maybe_put(:kind, params["kind"])
        |> maybe_put(:verified, parse_bool(params["verified"]))
        |> maybe_put(:published, parse_bool(params["published"]))
        |> maybe_put(:search, params["search"])
        |> maybe_put(:tag, params["tag"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Templates.list_templates(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :show,
    summary: "Get a template by slug",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Template", "application/json", TemplatesSchema.Template},
      not_found: "Not found"
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      try do
        json(conn, Templates.get_template!(slug))
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Create / update
  # ---------------------------------------------------------------------------

  operation :create,
    summary: "Create a template",
    request_body: {"Template create", "application/json", TemplatesSchema.TemplateCreate},
    responses: [
      created: {"Template", "application/json", TemplatesSchema.Template}
    ]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    with :ok <- validate_slug_opt(params["slug"]),
         :ok <- validate_kind_opt(params["kind"]) do
      case Templates.create_template(params) do
        {:ok, template} ->
          conn |> put_status(:created) |> json(template)

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :update,
    summary: "Update a template",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Template update", "application/json", TemplatesSchema.TemplateCreate},
    responses: [
      ok: {"Template", "application/json", TemplatesSchema.Template},
      not_found: "Not found"
    ]

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      try do
        template = Templates.get_template!(slug)

        case Templates.update_template(template, Map.delete(params, "slug")) do
          {:ok, updated} -> json(conn, updated)
          {:error, changeset} -> {:error, changeset}
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Preview
  # ---------------------------------------------------------------------------

  operation :preview,
    summary: "Render parameter-substituted preview of a template",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Preview body", "application/json", TemplatesSchema.PreviewRequest},
    responses: [
      ok: {"Preview", "application/json", TemplatesSchema.PreviewResponse},
      bad_request: "Invalid params",
      not_found: "Not found"
    ]

  @spec preview(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def preview(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      try do
        template = Templates.get_template!(slug)
        supplied = params["params"] || %{}

        case Templates.preview_template(template, supplied) do
          {:ok, %{body: body, resolved_params: resolved}} ->
            json(conn, %{
              slug: template.slug,
              kind: template.kind,
              version: template.version,
              body: body,
              resolved_params: resolved,
              parameter_schema: template.parameters
            })

          {:error, {:missing_parameters, missing}} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "missing_parameters", missing: missing})
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Instantiate
  # ---------------------------------------------------------------------------

  operation :instantiate,
    summary: "Instantiate a template into a workspace",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body:
      {"Instantiate body", "application/json", TemplatesSchema.InstantiateRequest},
    responses: [
      ok: {"Instantiation", "application/json", TemplatesSchema.Instantiation},
      bad_request: "Invalid params",
      not_found: "Not found"
    ]

  @spec instantiate(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def instantiate(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         {:ok, agent_id} <- validate_uuid_opt(params["instantiated_by_agent_id"]) do
      try do
        template = %Template{} = Templates.get_template!(slug)
        supplied = params["params"] || %{}

        case Templates.preview_template(template, supplied) do
          {:ok, %{body: body, resolved_params: resolved}} ->
            file_tree = extract_file_tree(body)
            agents = extract_list(body, "agents")
            skills = extract_list(body, "skills")

            attrs = %{
              template_id: template.id,
              template_slug: template.slug,
              template_version: template.version,
              target_workspace_slug: params["target_workspace_slug"],
              target_path: params["target_path"],
              params: resolved,
              files_written: length(file_tree),
              agents_created: length(agents),
              skills_installed: length(skills),
              status: "success",
              instantiated_by_agent_id: agent_id,
              instantiated_by: params["instantiated_by"]
            }

            case Templates.record_instantiation(attrs) do
              {:ok, inst} -> json(conn, inst)
              {:error, changeset} -> {:error, changeset}
            end

          {:error, {:missing_parameters, missing}} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "missing_parameters", missing: missing})
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Publish / fork
  # ---------------------------------------------------------------------------

  operation :publish,
    summary: "Publish a template + snapshot a version",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Publish body", "application/json", TemplatesSchema.PublishRequest},
    responses: [
      ok: {"Publish result", "application/json", TemplatesSchema.PublishResponse},
      not_found: "Not found"
    ]

  @spec publish(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def publish(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      try do
        template = Templates.get_template!(slug)

        opts =
          []
          |> maybe_put_kw(:version, params["version"])
          |> maybe_put_kw(:changelog, params["changelog"])
          |> maybe_put_kw(:authored_by, params["authored_by"])

        case Templates.publish_template(template, opts) do
          {:ok, result} -> json(conn, result)
          {:error, reason} -> bad_request(conn, "publish_failed: #{inspect(reason)}")
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :fork,
    summary: "Fork a template into a new template",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Fork body", "application/json", TemplatesSchema.ForkRequest},
    responses: [
      created: {"Template", "application/json", TemplatesSchema.Template},
      not_found: "Not found"
    ]

  @spec fork(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def fork(conn, %{"slug" => slug} = params) do
    new_slug = params["new_slug"]
    new_name = params["new_name"]

    with :ok <- validate_slug(slug),
         :ok <- validate_slug(new_slug),
         :ok <- validate_present(new_name, "new_name") do
      try do
        parent = Templates.get_template!(slug)

        case Templates.fork_template(parent, %{slug: new_slug, name: new_name}) do
          {:ok, forked} -> conn |> put_status(:created) |> json(forked)
          {:error, changeset} -> {:error, changeset}
        end
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Versions / instantiations index
  # ---------------------------------------------------------------------------

  operation :versions,
    summary: "List versions for a template",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Versions", "application/json", TemplatesSchema.VersionList}
    ]

  @spec versions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def versions(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug) do
      try do
        template = Templates.get_template!(slug)
        opts = [] |> maybe_put_kw(:limit, parse_limit(params["limit"]))
        versions = Templates.list_versions(template.id, opts)
        json(conn, %{slug: slug, count: length(versions), data: versions})
      rescue
        Ecto.NoResultsError ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "template_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :instantiations,
    summary: "List instantiation audit records",
    parameters: [
      template_slug: [in: :query, type: :string, required: false],
      target_workspace_slug: [in: :query, type: :string, required: false],
      status: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [
      ok: {"Instantiations", "application/json", TemplatesSchema.InstantiationList}
    ]

  @spec instantiations(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def instantiations(conn, params) do
    opts =
      []
      |> maybe_put(:template_slug, params["template_slug"])
      |> maybe_put(:target_workspace_slug, params["target_workspace_slug"])
      |> maybe_put(:status, params["status"])
      |> maybe_put(:limit, parse_limit(params["limit"]))

    json(conn, %{data: Templates.list_instantiations(opts)})
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: [{key, value} | opts]

  defp maybe_put_kw(opts, _key, nil), do: opts
  defp maybe_put_kw(opts, _key, ""), do: opts
  defp maybe_put_kw(opts, key, value), do: [{key, value} | opts]

  # ── Slug validation ────────────────────────────────────────────────────────

  defp validate_slug_opt(nil), do: :ok
  defp validate_slug_opt(""), do: {:error, "slug cannot be empty"}
  defp validate_slug_opt(str) when is_binary(str), do: validate_slug(str)
  defp validate_slug_opt(_), do: {:error, "slug must be a string"}

  defp validate_slug(str) when is_binary(str) do
    if Regex.match?(@slug_regex, str) do
      :ok
    else
      {:error,
       "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars; must start with letter or digit"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  # ── UUID validation ────────────────────────────────────────────────────────

  defp validate_uuid_opt(nil), do: {:ok, nil}
  defp validate_uuid_opt(""), do: {:ok, nil}
  defp validate_uuid_opt(str) when is_binary(str), do: validate_uuid(str, "uuid")
  defp validate_uuid_opt(_), do: {:error, "invalid uuid"}

  defp validate_uuid(str, field_name) when is_binary(str) do
    if Regex.match?(@uuid_regex, str) do
      {:ok, str}
    else
      {:error, "invalid #{field_name}: must be a UUID"}
    end
  end

  defp validate_uuid(_, field_name), do: {:error, "invalid #{field_name}"}

  # ── Kind validation ────────────────────────────────────────────────────────

  defp validate_kind_opt(nil), do: :ok
  defp validate_kind_opt(""), do: :ok
  defp validate_kind_opt("workspace"), do: :ok
  defp validate_kind_opt("persona"), do: :ok
  defp validate_kind_opt("workflow"), do: :ok
  defp validate_kind_opt(_), do: {:error, "invalid kind: must be workspace, persona, or workflow"}

  # ── Required string ────────────────────────────────────────────────────────

  defp validate_present(nil, name), do: {:error, "#{name} is required"}
  defp validate_present("", name), do: {:error, "#{name} cannot be empty"}
  defp validate_present(s, _) when is_binary(s), do: :ok
  defp validate_present(_, name), do: {:error, "#{name} must be a string"}

  # ── Bounded limit ──────────────────────────────────────────────────────────

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
  defp parse_bool(true), do: true
  defp parse_bool(false), do: false
  defp parse_bool(_), do: nil

  # ── Body inspection helpers ────────────────────────────────────────────────

  defp extract_file_tree(body) when is_map(body) do
    case Map.get(body, "files") do
      list when is_list(list) ->
        Enum.map(list, fn
          %{"path" => p} -> p
          p when is_binary(p) -> p
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp extract_file_tree(_), do: []

  defp extract_list(body, key) when is_map(body) do
    case Map.get(body, key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp extract_list(_, _), do: []

  # ── Error response ─────────────────────────────────────────────────────────

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
