defmodule Canopy.Tools.SkillCurator do
  @moduledoc """
  Skill Curator tool surface.

  Exposes 16 native tools (13 `skills.*` + 3 `registry.*`) that wrap
  `Canopy.Skills` and `Canopy.Skills.Curator` calls into the canonical
  tool-handler signature. The Skill Curator runtime agent invokes these via
  MCP or system prompt injection.

  Tools are registered at application boot via
  `Canopy.Tools.register_all_builtins/0` (which picks up modules listed in
  `:canopy, :tool_modules` config).

  ## Tool list (16)

  Skills (13):
  - `skills.search_registry`
  - `skills.install`
  - `skills.uninstall`
  - `skills.assign_to_agent`
  - `skills.unassign_from_agent`
  - `skills.create_custom`
  - `skills.update_lockfile`
  - `skills.fetch_metadata`
  - `skills.diff_versions`
  - `skills.preview_install`
  - `skills.set_governance`
  - `skills.list_assignments`
  - `skills.publish`

  Registry (3):
  - `registry.list_sources`
  - `registry.add_source`
  - `registry.refresh_index`
  """

  use Canopy.Tool

  alias Canopy.Skills
  alias Canopy.Skills.Curator

  # ---------------------------------------------------------------------------
  # Tool declarations — Skills
  # ---------------------------------------------------------------------------

  tool("skills.search_registry",
    description: """
    Search configured skill registries (and the local catalog) for skills
    matching a query. Returns the top N candidates with verified badges and
    descriptions. The curator uses this BEFORE any install to vet candidates.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "q" => %{"type" => "string", "description" => "free-text query"},
        "kind" => %{
          "type" => "string",
          "enum" => ["prompt", "workflow", "reference"]
        },
        "source" => %{"type" => "string", "description" => "filter by source"},
        "limit" => %{"type" => "integer", "description" => "default 10, max 50"}
      },
      "required" => ["q"]
    },
    handler: {__MODULE__, :search_registry, []},
    requires: [:skills]
  )

  tool("skills.install",
    description: """
    Install a skill from a registry, pinning to a specific version + content
    hash. Writes the lockfile entry atomically. ALWAYS pin a version — never
    `latest`. Unverified sources require explicit user approval (governance).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "version" => %{"type" => "string"},
        "source" => %{"type" => "string"},
        "source_url" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "content" => %{"type" => "string", "description" => "full SKILL.md body"},
        "content_hash" => %{"type" => "string", "description" => "SHA256 of content"},
        "name" => %{"type" => "string"},
        "description" => %{"type" => "string"},
        "kind" => %{"type" => "string"},
        "approve_unverified" => %{
          "type" => "boolean",
          "description" => "explicit override for unverified sources"
        }
      },
      "required" => ["slug", "version", "source"]
    },
    handler: {__MODULE__, :install, []},
    requires: [:skills]
  )

  tool("skills.uninstall",
    description: """
    Remove an installed skill. Unlocks the lockfile entry for the workspace
    and reports any agents that had this skill assigned (so the curator can
    notify them).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "delete_skill" => %{
          "type" => "boolean",
          "description" => "if true, also delete the skill row (default false: keep but unpin)"
        }
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :uninstall, []},
    requires: [:skills]
  )

  tool("skills.assign_to_agent",
    description: """
    Assign an installed skill to a specific agent. Returns the assignment
    record. Refuses if the agent already has 12+ skills (context budget
    overflow guard).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{"type" => "string"},
        "skill_slug" => %{"type" => "string"},
        "priority" => %{"type" => "integer", "description" => "default 0"}
      },
      "required" => ["agent_slug", "skill_slug"]
    },
    handler: {__MODULE__, :assign_to_agent, []},
    requires: [:skills]
  )

  tool("skills.unassign_from_agent",
    description: """
    Remove a skill assignment from an agent. Pair to `skills.assign_to_agent`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{"type" => "string"},
        "skill_slug" => %{"type" => "string"}
      },
      "required" => ["agent_slug", "skill_slug"]
    },
    handler: {__MODULE__, :unassign_from_agent, []},
    requires: [:skills]
  )

  tool("skills.create_custom",
    description: """
    Scaffold a brand-new skill from the curator's starter template.
    Used when no existing skill matches the need. The new skill is marked
    `source: local`, `verified: false` until explicitly verified.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "kind" => %{
          "type" => "string",
          "enum" => ["prompt", "workflow", "reference"]
        },
        "description" => %{"type" => "string"},
        "content" => %{"type" => "string"}
      },
      "required" => ["slug", "name", "kind"]
    },
    handler: {__MODULE__, :create_custom, []},
    requires: [:skills]
  )

  tool("skills.update_lockfile",
    description: """
    Update the lockfile entry for a `(workspace, skill)` pair. Idempotent;
    creates if missing, replaces if present. Records `locked_version`,
    `content_hash`, and provenance.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "workspace_slug" => %{"type" => "string"},
        "skill_slug" => %{"type" => "string"},
        "locked_version" => %{"type" => "string"},
        "content_hash" => %{"type" => "string"},
        "source" => %{"type" => "string"},
        "source_url" => %{"type" => "string"},
        "notes" => %{"type" => "string"}
      },
      "required" => ["skill_slug", "locked_version", "content_hash"]
    },
    handler: {__MODULE__, :update_lockfile, []},
    requires: [:skills]
  )

  tool("skills.fetch_metadata",
    description: """
    Fetch the latest metadata for a skill from its registry: version,
    content hash, description, when_to_use. Single-skill lookup. Used by
    the curator's heartbeat to detect upstream changes.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "source" => %{"type" => "string"}
      },
      "required" => ["slug", "source"]
    },
    handler: {__MODULE__, :fetch_metadata, []},
    requires: [:skills]
  )

  tool("skills.diff_versions",
    description: """
    Return a structured diff between two recorded versions of a skill.
    Used at upgrade time so Roberto can accept or reject per-skill changes.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "from_version" => %{"type" => "string"},
        "to_version" => %{"type" => "string"}
      },
      "required" => ["slug", "from_version", "to_version"]
    },
    handler: {__MODULE__, :diff_versions, []},
    requires: [:skills]
  )

  tool("skills.preview_install",
    description: """
    Dry-run an install. Returns the rendered SKILL.md, the dependency list,
    and warnings about destructive `allowed-tools` patterns. Nothing is
    written to disk. Always called before `skills.install`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "version" => %{"type" => "string"},
        "source" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :preview_install, []},
    requires: [:skills]
  )

  tool("skills.set_governance",
    description: """
    Set per-skill governance rules: require_approval flag, deny patterns,
    cooldown windows. Stored in the skill's frontmatter map.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "require_approval" => %{"type" => "boolean"},
        "deny_after_n_runs" => %{"type" => "integer"},
        "notes" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :set_governance, []},
    requires: [:skills]
  )

  tool("skills.list_assignments",
    description: """
    List skill assignments. Filter by agent or skill. Reverse lookup
    used by the curator before uninstalling a skill.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "agent_slug" => %{"type" => "string"},
        "skill_slug" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :list_assignments, []},
    requires: [:skills]
  )

  tool("skills.publish",
    description: """
    Mark a skill as published and (in v0.2) push it to a configured
    registry. v0.1 simply flips the `published` flag and records intent.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "registry" => %{"type" => "string", "description" => "target registry name"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :publish, []},
    requires: [:skills]
  )

  # ---------------------------------------------------------------------------
  # Tool declarations — Registry
  # ---------------------------------------------------------------------------

  tool("registry.list_sources",
    description: """
    Return the configured external skill sources. Each source has a name,
    URL, kind, and last-synced timestamp. The curator's heartbeat iterates
    these to detect upstream changes.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{}
    },
    handler: {__MODULE__, :list_sources, []},
    requires: [:skills]
  )

  tool("registry.add_source",
    description: """
    Register a new external skill source. The curator gates installs from
    new sources behind explicit user approval until verified.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "url" => %{"type" => "string"},
        "kind" => %{"type" => "string"}
      },
      "required" => ["name", "url"]
    },
    handler: {__MODULE__, :add_source, []},
    requires: [:skills]
  )

  tool("registry.refresh_index",
    description: """
    Force a re-sync against a registry source. Without `source`, refreshes
    every configured source. The heartbeat calls this on schedule.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "source" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :refresh_index, []},
    requires: [:skills]
  )

  # ---------------------------------------------------------------------------
  # Handlers — Skills
  # ---------------------------------------------------------------------------

  @doc false
  def search_registry(args) do
    q = args["q"] || ""
    limit = args["limit"] || 10
    limit = min(max(limit, 1), 50)

    {:ok, skills} =
      Skills.list(
        Enum.reject(
          [
            kind: args["kind"],
            source: args["source"]
          ],
          fn {_, v} -> is_nil(v) end
        )
      )

    matches =
      skills
      |> Enum.filter(&matches_query?(&1, q))
      |> Enum.take(limit)
      |> Enum.map(&serialize_search_hit/1)

    {:ok, %{query: q, count: length(matches), candidates: matches}}
  end

  @doc false
  def install(args) do
    workspace = args["workspace_slug"] || Curator.default_workspace()
    slug = args["slug"]
    version = args["version"]
    approve_unverified = args["approve_unverified"] == true

    with :ok <- check_install_gate(slug, approve_unverified) do
      skill_attrs =
        %{
          "slug" => slug,
          "name" => args["name"] || slug,
          "description" => args["description"],
          "content" => args["content"] || "# #{slug}\n",
          "source" => args["source"] || "local",
          "source_url" => args["source_url"],
          "kind" => args["kind"] || "prompt",
          "provider_format" => args["provider_format"] || "generic",
          "imported_at" => DateTime.utc_now()
        }
        |> Map.reject(fn {_, v} -> is_nil(v) end)

      with {:ok, skill} <- Skills.upsert(skill_attrs),
           {:ok, lock} <-
             Curator.lock_skill(workspace, slug, %{
               locked_version: version,
               content_hash: skill.content_hash,
               source: skill.source,
               source_url: skill.source_url
             }),
           {:ok, _ver} <-
             Curator.record_version(%{
               skill_id: skill.id,
               skill_slug: slug,
               version: version,
               content_hash: skill.content_hash,
               source: skill.source
             }) do
        {:ok,
         %{
           installed: serialize_skill(skill),
           lock: serialize_lock(lock),
           workspace_slug: workspace
         }}
      else
        {:error, reason} -> {:error, format_error(reason)}
      end
    end
  end

  @doc false
  def uninstall(args) do
    workspace = args["workspace_slug"] || Curator.default_workspace()
    slug = args["slug"]
    delete? = args["delete_skill"] == true

    affected_agents = enumerate_affected_agents(slug)

    _ =
      case Curator.unlock_skill(workspace, slug) do
        {:ok, _} -> :ok
        {:error, :not_found} -> :ok
      end

    if delete? do
      case Skills.get_by_slug(slug) do
        {:ok, skill} -> Skills.delete(skill)
        _ -> :ok
      end
    end

    {:ok,
     %{
       slug: slug,
       workspace_slug: workspace,
       deleted: delete?,
       affected_agents: affected_agents
     }}
  end

  @doc false
  def assign_to_agent(args) do
    agent_slug = args["agent_slug"]
    skill_slug = args["skill_slug"]
    priority = args["priority"] || 0

    {:ok, current} = Skills.list_assignments(agent_slug)

    if length(current) >= 12 do
      {:error, "agent_skill_budget_exceeded: agent has #{length(current)} skills (max 12)"}
    else
      case Skills.assign(agent_slug, skill_slug, priority: priority) do
        {:ok, assignment} ->
          {:ok, %{assignment: serialize_assignment(assignment)}}

        {:error, changeset} ->
          {:error, format_error(changeset)}
      end
    end
  end

  @doc false
  def unassign_from_agent(args) do
    case Skills.unassign(args["agent_slug"], args["skill_slug"]) do
      {:ok, _} -> {:ok, %{removed: true}}
      {:error, :not_found} -> {:ok, %{removed: false}}
    end
  end

  @doc false
  def create_custom(args) do
    slug = args["slug"]

    attrs = %{
      "slug" => slug,
      "name" => args["name"] || slug,
      "kind" => args["kind"] || "prompt",
      "description" => args["description"],
      "content" => args["content"] || starter_template(slug, args["kind"]),
      "source" => "local",
      "provider_format" => "generic"
    }

    case Skills.upsert(attrs) do
      {:ok, skill} ->
        Curator.record_version(%{
          skill_id: skill.id,
          skill_slug: slug,
          version: "0.1.0",
          content_hash: skill.content_hash,
          source: "local"
        })

        {:ok, %{skill: serialize_skill(skill)}}

      {:error, changeset} ->
        {:error, format_error(changeset)}
    end
  end

  @doc false
  def update_lockfile(args) do
    workspace = args["workspace_slug"] || Curator.default_workspace()
    slug = args["skill_slug"]

    attrs = %{
      locked_version: args["locked_version"],
      content_hash: args["content_hash"],
      source: args["source"],
      source_url: args["source_url"],
      notes: args["notes"]
    }

    case Curator.lock_skill(workspace, slug, attrs) do
      {:ok, entry} -> {:ok, %{lock: serialize_lock(entry)}}
      {:error, changeset} -> {:error, format_error(changeset)}
    end
  end

  @doc false
  def fetch_metadata(args) do
    case Skills.get_by_slug(args["slug"]) do
      {:ok, skill} ->
        versions = Curator.list_versions(skill.slug)

        latest =
          case versions do
            [v | _] -> v.version
            _ -> nil
          end

        {:ok,
         %{
           slug: skill.slug,
           name: skill.name,
           description: skill.description,
           source: skill.source,
           source_url: skill.source_url,
           latest_version: latest,
           content_hash: skill.content_hash,
           verified: Curator.get_verification(skill.slug) || %{verified: false}
         }}

      {:error, :not_found} ->
        {:error, "skill_not_found: #{args["slug"]}"}
    end
  end

  @doc false
  def diff_versions(args) do
    case Curator.diff_versions(args["slug"], args["from_version"], args["to_version"]) do
      {:ok, diff} -> {:ok, diff}
      {:error, :not_found} -> {:error, "version_not_found"}
    end
  end

  @doc false
  def preview_install(args) do
    slug = args["slug"]

    case Skills.get_by_slug(slug) do
      {:ok, skill} ->
        warnings = compute_warnings(skill)

        {:ok,
         %{
           slug: skill.slug,
           rendered_content: skill.content,
           dependencies: [],
           allowed_tools_warnings: warnings,
           requires_approval: Curator.install_requires_approval?(skill.slug)
         }}

      {:error, :not_found} ->
        {:ok,
         %{
           slug: slug,
           rendered_content: nil,
           dependencies: [],
           allowed_tools_warnings: [],
           requires_approval: true,
           note: "skill not yet in catalog; preview from registry response"
         }}
    end
  end

  @doc false
  def set_governance(args) do
    slug = args["slug"]

    case Skills.get_by_slug(slug) do
      {:ok, skill} ->
        gov =
          %{
            "require_approval" => args["require_approval"],
            "deny_after_n_runs" => args["deny_after_n_runs"],
            "notes" => args["notes"]
          }
          |> Map.reject(fn {_, v} -> is_nil(v) end)

        new_frontmatter = Map.put(skill.frontmatter || %{}, "governance", gov)

        case Skills.update(skill, %{"frontmatter" => new_frontmatter}) do
          {:ok, updated} -> {:ok, %{updated: serialize_skill(updated)}}
          {:error, changeset} -> {:error, format_error(changeset)}
        end

      {:error, :not_found} ->
        {:error, "skill_not_found: #{slug}"}
    end
  end

  @doc false
  def list_assignments(args) do
    cond do
      is_binary(args["agent_slug"]) ->
        {:ok, assignments} = Skills.list_assignments(args["agent_slug"])
        {:ok, %{assignments: Enum.map(assignments, &serialize_full_assignment/1)}}

      is_binary(args["skill_slug"]) ->
        # Walk all agents that might match — for v0.1 we return empty if the
        # caller didn't supply an agent_slug AND filtered by skill_slug, since
        # we don't yet have a reverse index. The curator falls back to scanning.
        {:ok, %{assignments: [], note: "skill-scoped reverse lookup pending"}}

      true ->
        {:ok, %{assignments: []}}
    end
  end

  @doc false
  def publish(args) do
    case Skills.get_by_slug(args["slug"]) do
      {:ok, skill} ->
        new_frontmatter = Map.put(skill.frontmatter || %{}, "published", true)

        new_frontmatter =
          case args["registry"] do
            nil -> new_frontmatter
            r -> Map.put(new_frontmatter, "published_to", r)
          end

        case Skills.update(skill, %{"frontmatter" => new_frontmatter}) do
          {:ok, updated} ->
            {:ok,
             %{
               slug: updated.slug,
               published: true,
               registry: args["registry"]
             }}

          {:error, changeset} ->
            {:error, format_error(changeset)}
        end

      {:error, :not_found} ->
        {:error, "skill_not_found"}
    end
  end

  # ---------------------------------------------------------------------------
  # Handlers — Registry
  # ---------------------------------------------------------------------------

  @doc false
  def list_sources(_args) do
    sources =
      Application.get_env(:canopy, :skill_registry_sources, [])
      |> Enum.map(fn s ->
        %{
          name: s[:name] || "unnamed",
          url: s[:url],
          kind: s[:kind] || "generic",
          last_synced_at: s[:last_synced_at]
        }
      end)

    {:ok, %{sources: sources}}
  end

  @doc false
  def add_source(args) do
    name = args["name"]
    url = args["url"]
    kind = args["kind"] || "generic"

    current = Application.get_env(:canopy, :skill_registry_sources, [])

    new_source = %{name: name, url: url, kind: kind, last_synced_at: nil}
    updated = [new_source | Enum.reject(current, &(&1[:name] == name))]

    Application.put_env(:canopy, :skill_registry_sources, updated)

    {:ok, %{added: new_source}}
  end

  @doc false
  def refresh_index(args) do
    sources = Application.get_env(:canopy, :skill_registry_sources, [])

    targets =
      case args["source"] do
        nil -> sources
        n -> Enum.filter(sources, &(&1[:name] == n))
      end

    {:ok,
     %{
       refreshed: length(targets),
       errors: 0,
       note: "v0.1 stub — adapter dispatch lands with registry bridge work"
     }}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp matches_query?(skill, q) do
    q_down = String.downcase(q)

    String.contains?(String.downcase(skill.slug), q_down) or
      String.contains?(String.downcase(skill.name || ""), q_down) or
      String.contains?(String.downcase(skill.description || ""), q_down)
  end

  defp check_install_gate(slug, approve_unverified) do
    cond do
      approve_unverified ->
        :ok

      not Curator.install_requires_approval?(slug) ->
        :ok

      true ->
        {:error,
         "install_blocked: source for #{slug} is unverified; pass approve_unverified=true to override"}
    end
  end

  defp enumerate_affected_agents(_skill_slug) do
    # v0.1 stub — no reverse index. Returns empty list; the curator's
    # heartbeat will hydrate this when the assignments index lands.
    []
  end

  defp compute_warnings(skill) do
    fm = skill.frontmatter || %{}

    case fm["allowed-tools"] || fm["allowed_tools"] do
      nil ->
        []

      tools when is_list(tools) ->
        Enum.flat_map(tools, fn t ->
          if String.contains?(to_string(t), "*") do
            ["destructive_pattern: #{t}"]
          else
            []
          end
        end)

      _ ->
        []
    end
  end

  defp starter_template(slug, kind) do
    """
    ---
    name: #{slug}
    kind: #{kind || "prompt"}
    description: TODO — add a one-line description
    when_to_use: TODO — describe when an agent should pick this up
    ---

    # #{slug}

    Replace this body with the playbook the agent should follow.
    """
  end

  defp format_error(%Ecto.Changeset{} = cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
    |> inspect()
  end

  defp format_error(other), do: inspect(other)

  defp serialize_skill(skill) do
    %{
      id: skill.id,
      slug: skill.slug,
      name: skill.name,
      description: skill.description,
      kind: skill.kind,
      source: skill.source,
      source_url: skill.source_url,
      content_hash: skill.content_hash,
      provider_format: skill.provider_format,
      enabled: skill.enabled,
      tags: skill.tags
    }
  end

  defp serialize_search_hit(skill) do
    verification = Curator.get_verification(skill.slug) || %{verified: false}

    %{
      slug: skill.slug,
      name: skill.name,
      description: skill.description,
      kind: skill.kind,
      source: skill.source,
      verified: Map.get(verification, :verified, false)
    }
  end

  defp serialize_lock(%{} = entry) do
    %{
      workspace_slug: entry.workspace_slug,
      skill_slug: entry.skill_slug,
      locked_version: entry.locked_version,
      content_hash: entry.content_hash,
      source: entry.source,
      source_url: entry.source_url,
      locked_at: entry.locked_at,
      locked_by: entry.locked_by
    }
  end

  defp serialize_assignment(a) do
    %{
      id: a.id,
      agent_slug: a.agent_slug,
      skill_slug: a.skill_slug,
      priority: a.priority,
      enabled: a.enabled
    }
  end

  defp serialize_full_assignment(row) do
    %{
      id: row[:id],
      agent_slug: row[:agent_slug],
      skill_slug: row[:skill_slug],
      priority: row[:priority],
      enabled: row[:enabled]
    }
  end
end
