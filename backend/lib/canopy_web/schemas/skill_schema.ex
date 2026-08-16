defmodule CanopyWeb.Schemas.SkillSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the Skill resource.

  API contract schemas for `/api/v1/skills`. Distinct from the Ecto schema.
  """

  alias OpenApiSpex.Schema

  defmodule Skill do
    @moduledoc "A Canopy skill — markdown bundle injected into agent execution environments."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Skill",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string, description: "Stable URL-safe identifier"},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        kind: %Schema{
          type: :string,
          enum: ["prompt", "workflow", "reference"],
          description: "Skill kind — determines how it is presented and organized"
        },
        frontmatter: %Schema{
          type: :object,
          nullable: true,
          description: "Optional parsed YAML frontmatter, e.g. {\"when\": \"code-review\"}"
        },
        provider_format: %Schema{
          type: :string,
          enum: ["claude", "agents_md", "generic"],
          description: "Which persona file the skill is injected into"
        },
        content: %Schema{type: :string, description: "Markdown body of the skill"},
        content_hash: %Schema{
          type: :string,
          description: "SHA256 of content — used as the prompt bundle key"
        },
        source: %Schema{
          type: :string,
          enum: ["local", "clawhub", "skills_sh", "user"],
          description: "Origin registry or source"
        },
        source_url: %Schema{type: :string, nullable: true},
        imported_at: %Schema{type: :string, format: :"date-time", nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        enabled: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :provider_format, :content, :content_hash, :source, :enabled]
    })
  end

  defmodule SkillList do
    @moduledoc "A paginated list of skills."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SkillList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Skill}
      },
      required: [:data]
    })
  end

  defmodule UpdateSkillRequest do
    @moduledoc "Request body for PUT /api/v1/skills/:slug."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "UpdateSkillRequest",
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        kind: %Schema{type: :string, enum: ["prompt", "workflow", "reference"]},
        frontmatter: %Schema{type: :object, nullable: true},
        content: %Schema{type: :string},
        provider_format: %Schema{type: :string, enum: ["claude", "agents_md", "generic"]},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        enabled: %Schema{type: :boolean}
      }
    })
  end

  defmodule ImportRequest do
    @moduledoc "Request body for importing skills from an external registry."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ImportRequest",
      type: :object,
      properties: %{
        source: %Schema{
          type: :string,
          enum: ["clawhub", "skills_sh"],
          description: "Registry to import from"
        }
      },
      required: [:source]
    })
  end

  defmodule ImportResponse do
    @moduledoc "Response after a bulk skills import."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ImportResponse",
      type: :object,
      properties: %{
        imported: %Schema{type: :integer, description: "Number of skills upserted"},
        errors: %Schema{
          type: :integer,
          description: "Number of skills that failed validation"
        }
      },
      required: [:imported, :errors]
    })
  end

  defmodule AssignSkillRequest do
    @moduledoc "Request body for POST /api/v1/agents/:slug/skills."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AssignSkillRequest",
      type: :object,
      properties: %{
        skill_slug: %Schema{type: :string, description: "Slug of the skill to assign"},
        priority: %Schema{
          type: :integer,
          description: "Injection priority — lower value = injected first (default 0)"
        }
      },
      required: [:skill_slug]
    })
  end

  defmodule AgentSkillAssignment do
    @moduledoc "A skill assignment with joined skill data."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AgentSkillAssignment",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        agent_slug: %Schema{type: :string},
        skill_slug: %Schema{type: :string},
        priority: %Schema{type: :integer},
        enabled: %Schema{type: :boolean},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        skill: Skill
      },
      required: [:id, :agent_slug, :skill_slug, :priority, :enabled]
    })
  end

  defmodule AgentSkillAssignmentList do
    @moduledoc "List of skill assignments for an agent."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AgentSkillAssignmentList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: AgentSkillAssignment}
      },
      required: [:data]
    })
  end
end
