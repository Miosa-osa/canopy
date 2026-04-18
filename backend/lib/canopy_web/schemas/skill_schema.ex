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
        provider_format: %Schema{
          type: :string,
          enum: ["claude", "agents_md", "generic"],
          description: "Which persona file the skill is injected into"
        },
        content: %Schema{type: :string, description: "Markdown body of the skill"},
        content_hash: %Schema{
          type: :string,
          description: "SHA256 of content — used as Paperclip prompt_bundle_key"
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
end
