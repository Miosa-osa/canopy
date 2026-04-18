defmodule CanopyWeb.Schemas.SandboxSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the MIOSA Sandbox resource.

  These are API contract schemas for `/api/v1/sandboxes`.  Distinct from Ecto
  schemas — they define what the HTTP API exposes, not the DB shape.

  A sandbox is an ephemeral MIOSA-provisioned VM attached to a Canopy session.
  Sandbox data is derived from the sessions table (`miosa_sandbox_*` columns);
  there is no separate sandboxes table.
  """

  alias OpenApiSpex.Schema

  defmodule Sandbox do
    @moduledoc "A MIOSA-provisioned compute sandbox attached to a Canopy session."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Sandbox",
      type: :object,
      properties: %{
        sandbox_id: %Schema{type: :string, description: "MIOSA-assigned sandbox ID"},
        session_id: %Schema{type: :string, format: :uuid, description: "Owning session ID"},
        url: %Schema{
          type: :string,
          nullable: true,
          description: "Sandbox access URL injected as CANOPY_MIOSA_SANDBOX_URL"
        },
        status: %Schema{
          type: :string,
          enum: ["pending", "provisioning", "ready", "destroyed", "skipped", "failed"],
          description: "Sandbox lifecycle status"
        }
      },
      required: [:sandbox_id, :session_id, :status]
    })
  end

  defmodule SandboxList do
    @moduledoc "A list of active MIOSA sandboxes."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SandboxList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: Sandbox}
      },
      required: [:data]
    })
  end
end
