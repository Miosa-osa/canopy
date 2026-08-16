defmodule CanopyWeb.Schemas.SkillCuratorSchema do
  @moduledoc "OpenAPI schemas for the Skill Curator super-module."

  alias OpenApiSpex.Schema

  defmodule LockfileEntry do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        workspace_slug: %Schema{type: :string},
        skill_slug: %Schema{type: :string},
        locked_version: %Schema{type: :string},
        content_hash: %Schema{type: :string},
        source: %Schema{type: :string, nullable: true},
        source_url: %Schema{type: :string, nullable: true},
        locked_at: %Schema{type: :string, format: :"date-time", nullable: true},
        locked_by: %Schema{type: :string, nullable: true},
        notes: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      },
      required: [:workspace_slug, :skill_slug, :locked_version, :content_hash]
    })
  end

  defmodule LockfileList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: LockfileEntry}
      }
    })
  end

  defmodule LockfileCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        workspace_slug: %Schema{type: :string},
        skill_slug: %Schema{type: :string},
        locked_version: %Schema{type: :string},
        content_hash: %Schema{type: :string},
        source: %Schema{type: :string},
        source_url: %Schema{type: :string},
        notes: %Schema{type: :string}
      },
      required: [:skill_slug, :locked_version, :content_hash]
    })
  end

  defmodule SkillVersion do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        skill_id: %Schema{type: :string, format: :uuid},
        skill_slug: %Schema{type: :string},
        version: %Schema{type: :string},
        content_hash: %Schema{type: :string},
        changelog: %Schema{type: :string, nullable: true},
        published_at: %Schema{type: :string, format: :"date-time"},
        published_by: %Schema{type: :string, nullable: true},
        source: %Schema{type: :string, nullable: true}
      }
    })
  end

  defmodule VersionList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        skill_slug: %Schema{type: :string},
        data: %Schema{type: :array, items: SkillVersion}
      }
    })
  end

  defmodule VersionDiff do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        skill_slug: %Schema{type: :string},
        from: SkillVersion,
        to: SkillVersion,
        hash_changed: %Schema{type: :boolean}
      }
    })
  end

  defmodule Verification do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        slug: %Schema{type: :string},
        verified: %Schema{type: :boolean},
        verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
        verified_by: %Schema{type: :string, nullable: true}
      }
    })
  end

  defmodule VerifyRequest do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        verified_by: %Schema{type: :string}
      },
      required: [:verified_by]
    })
  end

  defmodule UnverifiedList do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        count: %Schema{type: :integer},
        data: %Schema{type: :array, items: %Schema{type: :string}}
      }
    })
  end

  defmodule RegistrySource do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        url: %Schema{type: :string, nullable: true},
        kind: %Schema{type: :string},
        last_synced_at: %Schema{type: :string, format: :"date-time", nullable: true}
      }
    })
  end

  defmodule RegistrySources do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        sources: %Schema{type: :array, items: RegistrySource}
      }
    })
  end

  defmodule RegistrySourceCreate do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        name: %Schema{type: :string},
        url: %Schema{type: :string},
        kind: %Schema{type: :string}
      },
      required: [:name, :url]
    })
  end

  defmodule RefreshResult do
    @moduledoc false
    require OpenApiSpex
    OpenApiSpex.schema(%{
      type: :object,
      properties: %{
        refreshed: %Schema{type: :integer},
        errors: %Schema{type: :integer},
        note: %Schema{type: :string, nullable: true}
      }
    })
  end
end
