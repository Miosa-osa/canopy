defmodule CanopyWeb.SkillsController do
  @moduledoc """
  HTTP API for Canopy skills.

  Routes (add to router.ex — see note at end of file):
    GET    /api/v1/skills          — list skills (filter: ?source=, ?tag=, ?enabled=)
    GET    /api/v1/skills/:slug    — get skill detail
    POST   /api/v1/skills/import  — bulk import from external registry
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Skills
  alias Canopy.Skills.Registry.Clawhub
  alias Canopy.Skills.Registry.SkillsSh
  alias CanopyWeb.Schemas.RuntimeSchema
  alias CanopyWeb.Schemas.SkillSchema

  action_fallback CanopyWeb.FallbackController

  tags ["skills"]

  operation :index,
    summary: "List skills",
    description: """
    Returns all skills. Supports filtering by source, enabled status, and tag.
    """,
    parameters: [
      source: [
        in: :query,
        description: "Filter by source: local | clawhub | skills_sh | user",
        type: :string,
        required: false
      ],
      enabled: [
        in: :query,
        description: "Filter by enabled status: true | false",
        type: :string,
        required: false
      ],
      tag: [
        in: :query,
        description: "Filter to skills that include this tag",
        type: :string,
        required: false
      ]
    ],
    responses: [
      ok: {"Skill list", "application/json", SkillSchema.SkillList}
    ]

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    opts =
      []
      |> maybe_put(:source, Map.get(params, "source"))
      |> maybe_put(:enabled, parse_boolean(Map.get(params, "enabled")))
      |> maybe_put(:tag, Map.get(params, "tag"))

    {:ok, skills} = Skills.list(opts)
    json(conn, %{data: skills})
  end

  operation :show,
    summary: "Get skill detail",
    description: "Returns a single skill by slug.",
    parameters: [
      slug: [in: :path, description: "Skill slug", type: :string, required: true]
    ],
    responses: [
      ok: {"Skill detail", "application/json", SkillSchema.Skill},
      not_found: {"Not found", "application/json", RuntimeSchema.ErrorResponse}
    ]

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug}) do
    with {:ok, skill} <- Skills.get_by_slug(slug) do
      json(conn, skill)
    end
  end

  operation :import,
    summary: "Import skills from external registry",
    description: """
    Fetches all skills from the specified external registry (clawhub or skills_sh)
    and bulk-upserts them into the local database. Idempotent — running twice is safe.
    """,
    request_body: {"Import request", "application/json", SkillSchema.ImportRequest},
    responses: [
      ok: {"Import result", "application/json", SkillSchema.ImportResponse}
    ]

  @spec import(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def import(conn, %{"source" => source}) when source in ["clawhub", "skills_sh"] do
    {:ok, raw_skills} = fetch_from_registry(source)

    {imported, errors} =
      Enum.reduce(raw_skills, {0, 0}, fn raw, {ok_count, err_count} ->
        attrs = normalize_registry_attrs(raw, source)

        case Skills.upsert(attrs) do
          {:ok, _} -> {ok_count + 1, err_count}
          {:error, _} -> {ok_count, err_count + 1}
        end
      end)

    json(conn, %{imported: imported, errors: errors})
  end

  def import(conn, _) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "invalid_source", message: "source must be 'clawhub' or 'skills_sh'"})
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  @spec fetch_from_registry(String.t()) :: {:ok, [map()]}
  defp fetch_from_registry("clawhub"), do: Clawhub.fetch_all()
  defp fetch_from_registry("skills_sh"), do: SkillsSh.fetch_all()

  @spec normalize_registry_attrs(map(), String.t()) :: map()
  defp normalize_registry_attrs(raw, source) do
    %{
      "slug" => get_raw(raw, "slug"),
      "name" => get_raw(raw, "name"),
      "description" => get_raw(raw, "description"),
      "content" => get_raw(raw, "content") || "",
      "provider_format" => get_raw(raw, "provider_format") || "generic",
      "source" => source,
      "source_url" => get_raw(raw, "source_url"),
      "imported_at" => DateTime.utc_now(),
      "tags" => get_raw(raw, "tags") || []
    }
  end

  @spec get_raw(map(), String.t()) :: term()
  defp get_raw(raw, key) do
    atom_key = try_atom(key)
    raw[key] || (atom_key && raw[atom_key])
  end

  @spec try_atom(String.t()) :: atom() | nil
  defp try_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  @spec maybe_put(keyword(), atom(), term()) :: keyword()
  defp maybe_put(opts, _, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @spec parse_boolean(String.t() | nil) :: boolean() | nil
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(_), do: nil
end

# ---------------------------------------------------------------------------
# ROUTER NOTE (for @devops-engineer or router owner to merge):
#
# Add under the `scope "/api/v1"` block in router.ex:
#
#   get  "/skills",        SkillsController, :index
#   get  "/skills/:slug",  SkillsController, :show
#   post "/skills/import", SkillsController, :import
#
# Order matters: `/skills/import` must come before `/skills/:slug` so the
# literal "import" path is matched before the slug wildcard.
# ---------------------------------------------------------------------------
