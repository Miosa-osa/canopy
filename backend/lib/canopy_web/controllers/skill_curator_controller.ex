defmodule CanopyWeb.SkillCuratorController do
  @moduledoc """
  HTTP API for the Skill Curator super-module.

  Routes:
    GET    /api/v1/skill-curator/lockfile               — list lockfile entries
    POST   /api/v1/skill-curator/lockfile               — lock a skill
    DELETE /api/v1/skill-curator/lockfile/:workspace/:slug — unlock
    GET    /api/v1/skill-curator/skills/:slug/versions  — list version history
    GET    /api/v1/skill-curator/skills/:slug/diff      — diff two versions
    POST   /api/v1/skill-curator/skills/:slug/verify    — mark verified
    DELETE /api/v1/skill-curator/skills/:slug/verify    — clear verified
    GET    /api/v1/skill-curator/unverified             — list unverified slugs
    GET    /api/v1/skill-curator/sources                — list registry sources
    POST   /api/v1/skill-curator/sources                — add a registry source
    POST   /api/v1/skill-curator/sources/refresh        — refresh registry index
  """

  use CanopyWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Canopy.Skills.Curator
  alias CanopyWeb.Schemas.SkillCuratorSchema

  action_fallback CanopyWeb.FallbackController

  tags ["skill-curator"]

  @max_limit 1000
  @default_limit 200
  @slug_regex ~r/\A[a-z0-9][a-z0-9_-]{0,127}\z/
  @version_regex ~r/\A[a-zA-Z0-9][a-zA-Z0-9._\-+]{0,63}\z/
  @hash_regex ~r/\A[a-f0-9]{1,128}\z/

  # ---------------------------------------------------------------------------
  # Lockfile
  # ---------------------------------------------------------------------------

  operation :lockfile_index,
    summary: "List skill lockfile entries",
    parameters: [
      workspace_slug: [in: :query, type: :string, required: false],
      skill_slug: [in: :query, type: :string, required: false],
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Lockfile list", "application/json", SkillCuratorSchema.LockfileList}]

  @spec lockfile_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def lockfile_index(conn, params) do
    with :ok <- validate_slug_opt(params["workspace_slug"]),
         :ok <- validate_slug_opt(params["skill_slug"]) do
      opts =
        []
        |> maybe_put(:workspace_slug, params["workspace_slug"])
        |> maybe_put(:skill_slug, params["skill_slug"])
        |> maybe_put(:limit, parse_limit(params["limit"]))

      json(conn, %{data: Curator.list_lockfile(opts)})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :lockfile_create,
    summary: "Lock a skill to a specific version",
    request_body:
      {"Lockfile create", "application/json", SkillCuratorSchema.LockfileCreate},
    responses: [
      created: {"Lockfile entry", "application/json", SkillCuratorSchema.LockfileEntry}
    ]

  @spec lockfile_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def lockfile_create(conn, params) do
    workspace = params["workspace_slug"] || Curator.default_workspace()
    skill_slug = params["skill_slug"]

    with :ok <- validate_slug(workspace),
         :ok <- validate_slug(skill_slug),
         :ok <- validate_version(params["locked_version"]),
         :ok <- validate_hash(params["content_hash"]) do
      attrs = %{
        locked_version: params["locked_version"],
        content_hash: params["content_hash"],
        source: params["source"],
        source_url: params["source_url"],
        notes: params["notes"]
      }

      case Curator.lock_skill(workspace, skill_slug, attrs) do
        {:ok, entry} -> conn |> put_status(:created) |> json(entry)
        {:error, changeset} -> {:error, changeset}
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :lockfile_delete,
    summary: "Unlock a skill",
    parameters: [
      workspace_slug: [in: :path, type: :string, required: true],
      skill_slug: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Removed entry", "application/json", SkillCuratorSchema.LockfileEntry}]

  @spec lockfile_delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def lockfile_delete(conn, %{"workspace_slug" => ws, "skill_slug" => slug}) do
    with :ok <- validate_slug(ws),
         :ok <- validate_slug(slug) do
      case Curator.unlock_skill(ws, slug) do
        {:ok, entry} ->
          json(conn, entry)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "lockfile_entry_not_found", workspace_slug: ws, skill_slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Versions
  # ---------------------------------------------------------------------------

  operation :versions_index,
    summary: "List version history for a skill",
    parameters: [
      slug: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Version list", "application/json", SkillCuratorSchema.VersionList}]

  @spec versions_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def versions_index(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      versions = Curator.list_versions(slug)
      json(conn, %{skill_slug: slug, data: versions})
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :versions_diff,
    summary: "Diff two versions of a skill",
    parameters: [
      slug: [in: :path, type: :string, required: true],
      from: [in: :query, type: :string, required: true],
      to: [in: :query, type: :string, required: true]
    ],
    responses: [ok: {"Version diff", "application/json", SkillCuratorSchema.VersionDiff}]

  @spec versions_diff(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def versions_diff(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         :ok <- validate_version(params["from"]),
         :ok <- validate_version(params["to"]) do
      case Curator.diff_versions(slug, params["from"], params["to"]) do
        {:ok, diff} ->
          json(conn, diff)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "version_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Verification
  # ---------------------------------------------------------------------------

  operation :verify,
    summary: "Mark a skill as verified",
    parameters: [slug: [in: :path, type: :string, required: true]],
    request_body: {"Verify request", "application/json", SkillCuratorSchema.VerifyRequest},
    responses: [ok: {"Verification", "application/json", SkillCuratorSchema.Verification}]

  @spec verify(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def verify(conn, %{"slug" => slug} = params) do
    with :ok <- validate_slug(slug),
         {:ok, by} <- validate_verified_by(params["verified_by"]) do
      case Curator.verify_skill(slug, by) do
        {:ok, payload} ->
          json(conn, payload)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "skill_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :unverify,
    summary: "Clear the verified badge on a skill",
    parameters: [slug: [in: :path, type: :string, required: true]],
    responses: [ok: {"Verification", "application/json", SkillCuratorSchema.Verification}]

  @spec unverify(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unverify(conn, %{"slug" => slug}) do
    with :ok <- validate_slug(slug) do
      case Curator.unverify_skill(slug) do
        {:ok, payload} ->
          json(conn, payload)

        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "skill_not_found", slug: slug})
      end
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :unverified_index,
    summary: "List unverified skill slugs",
    parameters: [
      limit: [in: :query, type: :integer, required: false]
    ],
    responses: [ok: {"Unverified list", "application/json", SkillCuratorSchema.UnverifiedList}]

  @spec unverified_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def unverified_index(conn, params) do
    opts = [] |> maybe_put(:limit, parse_limit(params["limit"]))
    slugs = Curator.find_unverified(opts)
    json(conn, %{count: length(slugs), data: slugs})
  end

  # ---------------------------------------------------------------------------
  # Registry sources
  # ---------------------------------------------------------------------------

  operation :sources_index,
    summary: "List configured registry sources",
    responses: [
      ok: {"Registry sources", "application/json", SkillCuratorSchema.RegistrySources}
    ]

  @spec sources_index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sources_index(conn, _params) do
    {:ok, payload} = Canopy.Tools.SkillCurator.list_sources(%{})
    json(conn, payload)
  end

  operation :sources_create,
    summary: "Add a registry source",
    request_body:
      {"Source create", "application/json", SkillCuratorSchema.RegistrySourceCreate},
    responses: [
      created: {"Registry source", "application/json", SkillCuratorSchema.RegistrySource}
    ]

  @spec sources_create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sources_create(conn, params) do
    with :ok <- validate_source_name(params["name"]),
         :ok <- validate_source_url(params["url"]) do
      {:ok, %{added: source}} =
        Canopy.Tools.SkillCurator.add_source(%{
          "name" => params["name"],
          "url" => params["url"],
          "kind" => params["kind"]
        })

      conn |> put_status(:created) |> json(source)
    else
      {:error, reason} -> bad_request(conn, reason)
    end
  end

  operation :sources_refresh,
    summary: "Refresh a registry index",
    request_body:
      {"Refresh request", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{source: %OpenApiSpex.Schema{type: :string, nullable: true}}
       }},
    responses: [
      ok: {"Refresh result", "application/json", SkillCuratorSchema.RefreshResult}
    ]

  @spec sources_refresh(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sources_refresh(conn, params) do
    {:ok, payload} = Canopy.Tools.SkillCurator.refresh_index(%{"source" => params["source"]})
    json(conn, payload)
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

  defp validate_slug_opt(nil), do: :ok
  defp validate_slug_opt(""), do: :ok
  defp validate_slug_opt(s) when is_binary(s), do: validate_slug(s)
  defp validate_slug_opt(_), do: {:error, "slug must be a string"}

  defp validate_slug(s) when is_binary(s) do
    if Regex.match?(@slug_regex, s) do
      :ok
    else
      {:error,
       "invalid slug: must be lowercase alphanumeric, dashes, underscores; max 128 chars"}
    end
  end

  defp validate_slug(_), do: {:error, "slug must be a string"}

  defp validate_version(nil), do: {:error, "version is required"}
  defp validate_version(""), do: {:error, "version cannot be empty"}

  defp validate_version(s) when is_binary(s) do
    if Regex.match?(@version_regex, s) do
      :ok
    else
      {:error, "invalid version: must match #{inspect(@version_regex.source)}"}
    end
  end

  defp validate_version(_), do: {:error, "version must be a string"}

  defp validate_hash(nil), do: {:error, "content_hash is required"}
  defp validate_hash(""), do: {:error, "content_hash cannot be empty"}

  defp validate_hash(s) when is_binary(s) do
    if Regex.match?(@hash_regex, s) do
      :ok
    else
      {:error, "invalid content_hash: must be lowercase hex, max 128 chars"}
    end
  end

  defp validate_hash(_), do: {:error, "content_hash must be a string"}

  defp validate_verified_by(nil), do: {:error, "verified_by is required"}
  defp validate_verified_by(""), do: {:error, "verified_by cannot be empty"}

  defp validate_verified_by(s) when is_binary(s) do
    if String.length(s) <= 128 do
      {:ok, s}
    else
      {:error, "verified_by too long (max 128 chars)"}
    end
  end

  defp validate_verified_by(_), do: {:error, "verified_by must be a string"}

  defp validate_source_name(nil), do: {:error, "name is required"}
  defp validate_source_name(""), do: {:error, "name cannot be empty"}

  defp validate_source_name(s) when is_binary(s) and byte_size(s) <= 128, do: :ok
  defp validate_source_name(_), do: {:error, "invalid source name"}

  defp validate_source_url(nil), do: {:error, "url is required"}
  defp validate_source_url(""), do: {:error, "url cannot be empty"}

  defp validate_source_url(s) when is_binary(s) do
    cond do
      String.starts_with?(s, "http://") -> :ok
      String.starts_with?(s, "https://") -> :ok
      String.starts_with?(s, "file://") -> :ok
      true -> {:error, "url must start with http://, https://, or file://"}
    end
  end

  defp validate_source_url(_), do: {:error, "url must be a string"}

  defp bad_request(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request", message: to_string(reason)})
  end
end
