defmodule Canopy.Skills.Curator do
  @moduledoc """
  Curator extension for the Skills super-module.

  This module is the operational data layer for the **Skill Curator** runtime
  agent. It wraps `Canopy.Skills` (which owns CRUD and injection) and adds the
  curator-only concerns: lockfile management, version history, verification
  badges, and unverified-source discovery.

  ## Architecture

  ```
  Canopy.Skills           — base CRUD, injection, registry sync
       ▲
       │ wraps
       │
  Canopy.Skills.Curator   — lockfile, versions, verification (this module)
       ▲
       │ called by
       │
  Canopy.Tools.SkillCurator         — 16 tools the curator agent invokes
  CanopyWeb.SkillCuratorController  — HTTP surface under /api/v1/skill-curator/*
  ```

  ## Verification storage

  The `verified`, `verified_at`, and `verified_by` columns are added to the
  `skills` table by migration `20260428030001`, but the base `Skill` schema
  is intentionally not extended — the curator reads/writes those columns via
  Ecto fragments so existing CRUD paths stay untouched.
  """

  import Ecto.Query, only: [from: 2]

  alias Canopy.Repo
  alias Canopy.Skills
  alias Canopy.Skills.LockfileEntry
  alias Canopy.Skills.Version

  @default_workspace "default"

  # ---------------------------------------------------------------------------
  # Lockfile
  # ---------------------------------------------------------------------------

  @doc """
  Locks a skill to a specific version + content hash for a workspace.

  Idempotent on `(workspace_slug, skill_slug)` — a second call updates the
  existing row in place. Returns `{:ok, entry}` or `{:error, changeset}`.

  Required attrs:
  - `:locked_version` — the version string being pinned
  - `:content_hash` — SHA256 of the skill content at lock time

  Optional attrs:
  - `:source` / `:source_url` — provenance metadata
  - `:locked_by` — who initiated the lock (defaults to `"skill-curator"`)
  - `:notes` — freeform note about why this version was pinned
  """
  @spec lock_skill(String.t(), String.t(), map()) ::
          {:ok, LockfileEntry.t()} | {:error, Ecto.Changeset.t()}
  def lock_skill(workspace_slug, skill_slug, attrs) when is_map(attrs) do
    base = %{
      workspace_slug: workspace_slug,
      skill_slug: skill_slug,
      locked_at: DateTime.utc_now(),
      locked_by: Map.get(attrs, :locked_by, "skill-curator")
    }

    full = Map.merge(base, attrs)

    case Repo.get_by(LockfileEntry, workspace_slug: workspace_slug, skill_slug: skill_slug) do
      nil ->
        %LockfileEntry{}
        |> LockfileEntry.changeset(full)
        |> Repo.insert()

      existing ->
        existing
        |> LockfileEntry.changeset(full)
        |> Repo.update()
    end
  end

  @doc """
  Removes a lockfile entry. Returns `{:ok, entry}` or `{:error, :not_found}`.
  """
  @spec unlock_skill(String.t(), String.t()) ::
          {:ok, LockfileEntry.t()} | {:error, :not_found}
  def unlock_skill(workspace_slug, skill_slug) do
    case Repo.get_by(LockfileEntry, workspace_slug: workspace_slug, skill_slug: skill_slug) do
      nil -> {:error, :not_found}
      entry -> Repo.delete(entry)
    end
  end

  @doc """
  Lists lockfile entries, optionally scoped to a workspace.

  Options:
  - `:workspace_slug` — filter to a single workspace
  - `:skill_slug` — filter to a single skill
  - `:limit` — default 500
  """
  @spec list_lockfile(keyword()) :: [LockfileEntry.t()]
  def list_lockfile(opts \\ []) do
    limit = Keyword.get(opts, :limit, 500)

    from(l in LockfileEntry, order_by: [asc: l.workspace_slug, asc: l.skill_slug], limit: ^limit)
    |> filter(:workspace_slug, opts[:workspace_slug])
    |> filter(:skill_slug, opts[:skill_slug])
    |> Repo.all()
  end

  @doc "Returns the lockfile entry for a `(workspace, skill)` pair, or nil."
  @spec get_lock(String.t(), String.t()) :: LockfileEntry.t() | nil
  def get_lock(workspace_slug, skill_slug) do
    Repo.get_by(LockfileEntry, workspace_slug: workspace_slug, skill_slug: skill_slug)
  end

  @doc """
  Returns the workspace slug treated as default when callers do not specify
  one. Single-tenant constant for v0.1; multi-workspace lookup arrives later.
  """
  @spec default_workspace() :: String.t()
  def default_workspace, do: @default_workspace

  # ---------------------------------------------------------------------------
  # Versions
  # ---------------------------------------------------------------------------

  @doc """
  Records a new version row for a skill.

  Typically called immediately after `Canopy.Skills.update/2` when content
  has changed, or at initial create time.
  """
  @spec record_version(map()) :: {:ok, Version.t()} | {:error, Ecto.Changeset.t()}
  def record_version(attrs) when is_map(attrs) do
    attrs = Map.put_new_lazy(attrs, :published_at, fn -> DateTime.utc_now() end)

    %Version{}
    |> Version.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists all versions for a skill, newest first.
  """
  @spec list_versions(String.t()) :: [Version.t()]
  def list_versions(skill_slug) when is_binary(skill_slug) do
    Repo.all(
      from(v in Version,
        where: v.skill_slug == ^skill_slug,
        order_by: [desc: v.published_at]
      )
    )
  end

  @doc """
  Returns the version row matching `(skill_slug, version)`, or nil.
  """
  @spec get_version(String.t(), String.t()) :: Version.t() | nil
  def get_version(skill_slug, version) do
    Repo.get_by(Version, skill_slug: skill_slug, version: version)
  end

  # ---------------------------------------------------------------------------
  # Verification (stored on `skills` table via fragments)
  # ---------------------------------------------------------------------------

  @doc """
  Marks a skill as verified.

  Records `verified = true`, `verified_at = now`, `verified_by = <by>` on the
  underlying skills row. Returns `{:ok, %{slug: ..., verified: true, ...}}`
  or `{:error, :not_found}`.
  """
  @spec verify_skill(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def verify_skill(skill_slug, verified_by) when is_binary(skill_slug) do
    case Skills.get_by_slug(skill_slug) do
      {:ok, _skill} ->
        now = DateTime.utc_now()

        Repo.query!(
          "UPDATE skills SET verified = true, verified_at = $1, verified_by = $2, updated_at = $1 WHERE slug = $3",
          [now, verified_by, skill_slug]
        )

        {:ok, %{slug: skill_slug, verified: true, verified_at: now, verified_by: verified_by}}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Clears the verified badge on a skill.
  """
  @spec unverify_skill(String.t()) :: {:ok, map()} | {:error, :not_found}
  def unverify_skill(skill_slug) when is_binary(skill_slug) do
    case Skills.get_by_slug(skill_slug) do
      {:ok, _skill} ->
        now = DateTime.utc_now()

        Repo.query!(
          "UPDATE skills SET verified = false, verified_at = NULL, verified_by = NULL, updated_at = $1 WHERE slug = $2",
          [now, skill_slug]
        )

        {:ok, %{slug: skill_slug, verified: false, verified_at: nil, verified_by: nil}}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns the verification record for a skill, or nil if not found.
  Shape: `%{slug, verified, verified_at, verified_by}`.
  """
  @spec get_verification(String.t()) :: map() | nil
  def get_verification(skill_slug) when is_binary(skill_slug) do
    case Repo.query!(
           "SELECT slug, verified, verified_at, verified_by FROM skills WHERE slug = $1",
           [skill_slug]
         ) do
      %{rows: [[slug, verified, verified_at, verified_by]]} ->
        %{
          slug: slug,
          verified: verified,
          verified_at: verified_at,
          verified_by: verified_by
        }

      _ ->
        nil
    end
  end

  @doc """
  Returns slugs of skills that have not yet been verified.

  Used by the curator's heartbeat to decide which skills must be gated
  behind explicit user approval at install time.
  """
  @spec find_unverified(keyword()) :: [String.t()]
  def find_unverified(opts \\ []) do
    limit = Keyword.get(opts, :limit, 200)

    %{rows: rows} =
      Repo.query!(
        "SELECT slug FROM skills WHERE verified = false ORDER BY slug ASC LIMIT $1",
        [limit]
      )

    Enum.map(rows, fn [slug] -> slug end)
  end

  @doc """
  Returns true if a skill installation should be gated behind explicit
  user approval — i.e. the skill (or its source) is not verified.
  """
  @spec install_requires_approval?(String.t() | map()) :: boolean()
  def install_requires_approval?(skill_slug) when is_binary(skill_slug) do
    case get_verification(skill_slug) do
      %{verified: true} -> false
      _ -> true
    end
  end

  def install_requires_approval?(%{verified: verified}) when is_boolean(verified),
    do: not verified

  def install_requires_approval?(_), do: true

  # ---------------------------------------------------------------------------
  # Diff
  # ---------------------------------------------------------------------------

  @doc """
  Returns a structured diff between two recorded versions of a skill.

  Output shape: `{:ok, %{from: version, to: version, hash_changed: bool, ...}}`
  or `{:error, :not_found}` if either version is missing.
  """
  @spec diff_versions(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, :not_found}
  def diff_versions(skill_slug, from_version, to_version) do
    with %Version{} = a <- get_version(skill_slug, from_version),
         %Version{} = b <- get_version(skill_slug, to_version) do
      {:ok,
       %{
         skill_slug: skill_slug,
         from: serialize_version(a),
         to: serialize_version(b),
         hash_changed: a.content_hash != b.content_hash
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter(query, _field, nil), do: query

  defp filter(query, field, value) do
    from(q in query, where: field(q, ^field) == ^value)
  end

  defp serialize_version(%Version{} = v) do
    %{
      version: v.version,
      content_hash: v.content_hash,
      published_at: v.published_at,
      published_by: v.published_by,
      changelog: v.changelog,
      source: v.source
    }
  end
end
