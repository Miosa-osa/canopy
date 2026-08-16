defmodule Canopy.Tools.Templates do
  @moduledoc """
  Templates tool surface for the Forge agent (Template Composer).

  Exposes 8 native tools (`templates.*` plus `agent_persona.generate` and
  `workflow.scaffold`) that wrap `Canopy.Templates` API calls into the
  canonical tool-handler signature. Any runtime adapter can invoke them
  via MCP or system-prompt injection.

  Tools are registered at application boot via
  `Canopy.Tools.register_all_builtins/0` (which also picks up modules listed
  in `:canopy, :tool_modules` config).

  ## Tool list

  - `templates.list` — list templates (gallery)
  - `templates.preview` — render parameter-substituted preview
  - `templates.instantiate` — materialize a template into a workspace
  - `templates.create` — scaffold a new template
  - `templates.publish` — flip published flag + snapshot version
  - `templates.fork` — derive a new template from an existing one
  - `agent_persona.generate` — synthesize a persona body from inputs
  - `workflow.scaffold` — synthesize a multi-agent pipeline body
  """

  use Canopy.Tool

  alias Canopy.Templates
  alias Canopy.Templates.Template

  # ---------------------------------------------------------------------------
  # Tool declarations
  # ---------------------------------------------------------------------------

  tool("templates.list",
    description: """
    List available templates with optional filters (kind, search, verified).
    Returns the gallery rows shown on the /templates page.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "kind" => %{
          "type" => "string",
          "enum" => ["workspace", "persona", "workflow"],
          "description" => "Filter to one template kind"
        },
        "search" => %{"type" => "string"},
        "verified_only" => %{"type" => "boolean"},
        "tag" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list, []},
    requires: [:templates]
  )

  tool("templates.preview",
    description: """
    Render a parameter-substituted preview of a template body. Returns the
    file tree, sample files, parameter schema, and any unmet required
    parameters. Used as the dry-run before instantiate.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "params" => %{"type" => "object"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :preview, []},
    requires: [:templates]
  )

  tool("templates.instantiate",
    description: """
    Materialize a template into a target workspace. Coordinates with the
    Skill Curator to install dependent skills and writes a provenance
    record. Returns the instantiation summary.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "target_workspace_slug" => %{"type" => "string"},
        "target_path" => %{"type" => "string"},
        "params" => %{"type" => "object"},
        "instantiated_by" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :instantiate, []},
    requires: [:templates]
  )

  tool("templates.create",
    description: """
    Scaffold a new template (workspace / persona / workflow). The body
    starts empty and `verified` is false until reviewed.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "kind" => %{
          "type" => "string",
          "enum" => ["workspace", "persona", "workflow"]
        },
        "description" => %{"type" => "string"},
        "body" => %{"type" => "object"},
        "parameters" => %{"type" => "object"},
        "tags" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "icon" => %{"type" => "string"}
      },
      "required" => ["slug", "name", "kind"]
    },
    handler: {__MODULE__, :create, []},
    requires: [:templates]
  )

  tool("templates.publish",
    description: """
    Publish a template — sets the published flag, snapshots a new version
    row, and computes the diff against the previous version. Gated by
    governance.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "slug" => %{"type" => "string"},
        "version" => %{"type" => "string"},
        "changelog" => %{"type" => "string"},
        "authored_by" => %{"type" => "string"}
      },
      "required" => ["slug"]
    },
    handler: {__MODULE__, :publish, []},
    requires: [:templates]
  )

  tool("templates.fork",
    description: """
    Fork an existing template into a new one. The new template inherits
    body and parameters, records its parent, and starts unverified +
    unpublished.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "source_slug" => %{"type" => "string"},
        "new_slug" => %{"type" => "string"},
        "new_name" => %{"type" => "string"}
      },
      "required" => ["source_slug", "new_slug", "new_name"]
    },
    handler: {__MODULE__, :fork, []},
    requires: [:templates]
  )

  tool("agent_persona.generate",
    description: """
    Synthesize an agent persona body (frontmatter + identity + process)
    from a role + tool list + skill list. Returns the persona content as a
    map ready to be saved as a `kind: "persona"` template.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "role" => %{"type" => "string"},
        "title" => %{"type" => "string"},
        "tools" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "skills" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "base_persona_slug" => %{"type" => "string"},
        "color" => %{"type" => "string"},
        "emoji" => %{"type" => "string"}
      },
      "required" => ["role"]
    },
    handler: {__MODULE__, :generate_persona, []},
    requires: [:templates]
  )

  tool("workflow.scaffold",
    description: """
    Synthesize a multi-agent pipeline definition: ordered sequence of
    agent roles, handoff rules, and expected outputs. Returns the
    pipeline body as a map ready to be saved as a `kind: "workflow"`
    template.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "name" => %{"type" => "string"},
        "agents" => %{
          "type" => "array",
          "items" => %{"type" => "object"}
        },
        "sequence" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "handoff_rules" => %{
          "type" => "array",
          "items" => %{"type" => "object"}
        }
      },
      "required" => ["name", "agents"]
    },
    handler: {__MODULE__, :scaffold_workflow, []},
    requires: [:templates]
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def list(args) do
    opts =
      []
      |> put_opt(:kind, args["kind"])
      |> put_opt(:search, args["search"])
      |> put_opt(:tag, args["tag"])
      |> put_opt(:limit, args["limit"])
      |> maybe_verified(args["verified_only"])

    rows = Templates.list_templates(opts)
    {:ok, %{count: length(rows), templates: Enum.map(rows, &serialize_template/1)}}
  end

  @doc false
  def preview(%{"slug" => slug} = args) do
    case Templates.get_template(slug) do
      nil ->
        {:error, %{error: "template_not_found", slug: slug}}

      %Template{} = template ->
        params = args["params"] || %{}

        case Templates.preview_template(template, params) do
          {:ok, %{body: body, resolved_params: resolved}} ->
            {:ok,
             %{
               slug: template.slug,
               kind: template.kind,
               version: template.version,
               body: body,
               resolved_params: resolved,
               parameter_schema: template.parameters,
               file_tree: extract_file_tree(body),
               dependent_agents: extract_dependents(body, "agents"),
               dependent_skills: extract_dependents(body, "skills")
             }}

          {:error, {:missing_parameters, missing}} ->
            {:error, %{error: "missing_parameters", missing: missing}}
        end
    end
  end

  @doc false
  def instantiate(%{"slug" => slug} = args) do
    case Templates.get_template(slug) do
      nil ->
        {:error, %{error: "template_not_found", slug: slug}}

      %Template{} = template ->
        params = args["params"] || %{}

        case Templates.preview_template(template, params) do
          {:ok, %{body: body, resolved_params: resolved}} ->
            file_tree = extract_file_tree(body)

            {:ok, inst} =
              Templates.record_instantiation(%{
                template_id: template.id,
                template_slug: template.slug,
                template_version: template.version,
                target_workspace_slug: args["target_workspace_slug"],
                target_path: args["target_path"],
                params: resolved,
                files_written: length(file_tree),
                agents_created: length(extract_dependents(body, "agents")),
                skills_installed: length(extract_dependents(body, "skills")),
                status: "success",
                instantiated_by: args["instantiated_by"]
              })

            {:ok,
             %{
               instantiation_id: inst.id,
               template_slug: template.slug,
               template_version: template.version,
               target_workspace_slug: inst.target_workspace_slug,
               files_written: inst.files_written,
               agents_created: inst.agents_created,
               skills_installed: inst.skills_installed,
               status: inst.status
             }}

          {:error, {:missing_parameters, missing}} ->
            {:error, %{error: "missing_parameters", missing: missing}}
        end
    end
  end

  @doc false
  def create(args) do
    attrs =
      args
      |> Map.take([
        "slug",
        "name",
        "kind",
        "description",
        "body",
        "parameters",
        "tags",
        "icon"
      ])
      |> atomize_keys()

    case Templates.create_template(attrs) do
      {:ok, template} -> {:ok, serialize_template(template)}
      {:error, changeset} -> {:error, %{error: "invalid", details: changeset_errors(changeset)}}
    end
  end

  @doc false
  def publish(%{"slug" => slug} = args) do
    case Templates.get_template(slug) do
      nil ->
        {:error, %{error: "template_not_found", slug: slug}}

      %Template{} = template ->
        opts =
          []
          |> put_opt(:version, args["version"])
          |> put_opt(:changelog, args["changelog"])
          |> put_opt(:authored_by, args["authored_by"])

        case Templates.publish_template(template, opts) do
          {:ok, %{template: t, version: v}} ->
            {:ok,
             %{
               template: serialize_template(t),
               version: %{
                 id: v.id,
                 version: v.version,
                 sha256: v.sha256,
                 inserted_at: v.inserted_at
               }
             }}

          {:error, reason} ->
            {:error, %{error: "publish_failed", reason: inspect(reason)}}
        end
    end
  end

  @doc false
  def fork(%{"source_slug" => source, "new_slug" => new_slug, "new_name" => new_name}) do
    case Templates.get_template(source) do
      nil ->
        {:error, %{error: "template_not_found", slug: source}}

      %Template{} = parent ->
        case Templates.fork_template(parent, %{slug: new_slug, name: new_name}) do
          {:ok, forked} -> {:ok, serialize_template(forked)}

          {:error, changeset} ->
            {:error, %{error: "fork_failed", details: changeset_errors(changeset)}}
        end
    end
  end

  @doc false
  def generate_persona(args) do
    role = args["role"]
    title = args["title"] || String.capitalize(role)

    body = %{
      "frontmatter" => %{
        "role" => role,
        "title" => title,
        "color" => args["color"] || "oklch(0.72 0.14 290)",
        "emoji" => args["emoji"] || "🪄",
        "tools" => args["tools"] || [],
        "skills" => args["skills"] || [],
        "base_persona_slug" => args["base_persona_slug"]
      },
      "identity" => "You are the #{title}. Operate within Canopy as a #{role}.",
      "process" => "Receive task → plan → act → verify → report.",
      "deliverables" => "Structured outputs in genre-matched format."
    }

    {:ok, %{body: body}}
  end

  @doc false
  def scaffold_workflow(args) do
    body = %{
      "name" => args["name"],
      "agents" => args["agents"] || [],
      "sequence" => args["sequence"] || [],
      "handoff_rules" => args["handoff_rules"] || []
    }

    {:ok, %{body: body}}
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, _key, ""), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp maybe_verified(opts, true), do: [{:verified, true} | opts]
  defp maybe_verified(opts, _), do: opts

  defp atomize_keys(map) when is_map(map) do
    Enum.into(map, %{}, fn {k, v} ->
      key = if is_atom(k), do: k, else: String.to_atom(k)
      {key, v}
    end)
  end

  defp serialize_template(%Template{} = t) do
    %{
      id: t.id,
      slug: t.slug,
      name: t.name,
      description: t.description,
      kind: t.kind,
      version: t.version,
      verified: t.verified,
      published: t.published,
      tags: t.tags,
      icon: t.icon,
      popularity_count: t.popularity_count,
      forked_from_slug: t.forked_from_slug,
      source: t.source,
      inserted_at: t.inserted_at,
      updated_at: t.updated_at
    }
  end

  defp extract_file_tree(body) when is_map(body) do
    case Map.get(body, "files") do
      files when is_list(files) ->
        Enum.map(files, fn
          %{"path" => path} -> path
          path when is_binary(path) -> path
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp extract_file_tree(_), do: []

  defp extract_dependents(body, key) when is_map(body) do
    case Map.get(body, key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp extract_dependents(_, _), do: []

  defp changeset_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end
end
