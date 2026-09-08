defmodule CanopyWeb.Schemas.TemplatesSchema do
  @moduledoc "OpenAPI schemas for the Templates super-module."

  alias OpenApiSpex.Schema

  defmodule Template do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        kind: %Schema{type: :string},
        body: %Schema{type: :object, additionalProperties: true},
        parameters: %Schema{type: :object, additionalProperties: true},
        version: %Schema{type: :string},
        parent_template_id: %Schema{type: :string, format: :uuid, nullable: true},
        forked_from_slug: %Schema{type: :string, nullable: true},
        verified: %Schema{type: :boolean},
        verified_by: %Schema{type: :string, nullable: true},
        verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
        published: %Schema{type: :boolean},
        source: %Schema{type: :string},
        source_url: %Schema{type: :string, nullable: true},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        icon: %Schema{type: :string, nullable: true},
        popularity_count: %Schema{type: :integer},
        created_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:id, :slug, :name, :kind, :version]
    })
  end

  defmodule TemplateList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Template}
      }
    })
  end

  defmodule TemplateCreate do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        kind: %Schema{type: :string, enum: ["workspace", "persona", "workflow"]},
        description: %Schema{type: :string},
        body: %Schema{type: :object, additionalProperties: true},
        parameters: %Schema{type: :object, additionalProperties: true},
        version: %Schema{type: :string},
        tags: %Schema{type: :array, items: %Schema{type: :string}},
        icon: %Schema{type: :string},
        source: %Schema{type: :string},
        source_url: %Schema{type: :string}
      },
      required: [:slug, :name, :kind]
    })
  end

  defmodule PreviewRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        params: %Schema{type: :object, additionalProperties: true}
      }
    })
  end

  defmodule PreviewResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        kind: %Schema{type: :string},
        version: %Schema{type: :string},
        body: %Schema{type: :object, additionalProperties: true},
        resolved_params: %Schema{type: :object, additionalProperties: true},
        parameter_schema: %Schema{type: :object, additionalProperties: true}
      }
    })
  end

  defmodule InstantiateRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        target_workspace_slug: %Schema{type: :string},
        target_path: %Schema{type: :string},
        params: %Schema{type: :object, additionalProperties: true},
        instantiated_by: %Schema{type: :string},
        instantiated_by_agent_id: %Schema{type: :string, format: :uuid}
      }
    })
  end

  defmodule Instantiation do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        template_id: %Schema{type: :string, format: :uuid, nullable: true},
        template_slug: %Schema{type: :string},
        template_version: %Schema{type: :string},
        target_workspace_slug: %Schema{type: :string, nullable: true},
        target_path: %Schema{type: :string, nullable: true},
        params: %Schema{type: :object, additionalProperties: true},
        files_written: %Schema{type: :integer},
        agents_created: %Schema{type: :integer},
        skills_installed: %Schema{type: :integer},
        status: %Schema{type: :string},
        error: %Schema{type: :string, nullable: true},
        instantiated_by_agent_id: %Schema{type: :string, format: :uuid, nullable: true},
        instantiated_by: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule InstantiationList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Instantiation}
      }
    })
  end

  defmodule PublishRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        version: %Schema{type: :string},
        changelog: %Schema{type: :string},
        authored_by: %Schema{type: :string}
      }
    })
  end

  defmodule TemplateVersion do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        template_id: %Schema{type: :string, format: :uuid},
        version: %Schema{type: :string},
        diff: %Schema{type: :object, additionalProperties: true},
        body_snapshot: %Schema{type: :object, additionalProperties: true},
        parameters_snapshot: %Schema{type: :object, additionalProperties: true},
        changelog: %Schema{type: :string, nullable: true},
        sha256: %Schema{type: :string, nullable: true},
        authored_by: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule PublishResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        template: Template,
        version: TemplateVersion
      }
    })
  end

  defmodule VersionList do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: TemplateVersion}
      }
    })
  end

  defmodule ForkRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        new_slug: %Schema{type: :string},
        new_name: %Schema{type: :string}
      },
      required: [:new_slug, :new_name]
    })
  end
end
