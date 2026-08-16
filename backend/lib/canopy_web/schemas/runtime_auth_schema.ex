defmodule CanopyWeb.Schemas.RuntimeAuthSchema do
  @moduledoc """
  OpenAPISpex schema definitions for the RuntimeAuth resource.

  Covers `/api/v1/runtimes/:type/auth` endpoints:
  device-code flow, credential storage, revocation, and test-probe responses.
  """

  alias OpenApiSpex.Schema

  defmodule DeviceFlowResponse do
    @moduledoc "Response from POST /auth/start for OAuth device-code flows."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeviceFlowResponse",
      type: :object,
      properties: %{
        flow_type: %Schema{type: :string, enum: ["device_code"], description: "Flow type"},
        device_code: %Schema{type: :string, description: "Opaque device code for polling"},
        user_code: %Schema{
          type: :string,
          description: "Human-readable code to enter at verification_url"
        },
        verification_url: %Schema{
          type: :string,
          description: "URL the user opens in their browser"
        },
        expires_in: %Schema{type: :integer, description: "Seconds until device_code expires"},
        interval: %Schema{type: :integer, description: "Minimum seconds between poll requests"}
      },
      required: [:flow_type, :device_code, :user_code, :verification_url, :expires_in, :interval]
    })
  end

  defmodule PollRequest do
    @moduledoc "Request body for POST /auth/poll."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PollRequest",
      type: :object,
      properties: %{
        device_code: %Schema{type: :string, description: "Device code from start_flow response"}
      },
      required: [:device_code]
    })
  end

  defmodule PollResponse do
    @moduledoc "Response from POST /auth/poll."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PollResponse",
      type: :object,
      properties: %{
        status: %Schema{
          type: :string,
          enum: ["pending", "active", "expired"],
          description: "Current state of the device-code flow"
        }
      },
      required: [:status]
    })
  end

  defmodule StoreCredentialRequest do
    @moduledoc "Request body for PUT /credentials (API key storage)."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "StoreCredentialRequest",
      type: :object,
      properties: %{
        api_key: %Schema{type: :string, description: "Plaintext API key to encrypt and store"}
      },
      required: [:api_key]
    })
  end

  defmodule CredentialStatusResponse do
    @moduledoc "Response after storing or updating a credential."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CredentialStatusResponse",
      type: :object,
      properties: %{
        runtime_type: %Schema{type: :string},
        auth_type: %Schema{type: :string, enum: ["oauth", "api_key"]},
        status: %Schema{
          type: :string,
          enum: ["pending", "active", "expired", "revoked"]
        }
      },
      required: [:runtime_type, :auth_type, :status]
    })
  end

  defmodule TestCredentialResponse do
    @moduledoc "Response from POST /test — result of probing the CLI binary."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "TestCredentialResponse",
      type: :object,
      properties: %{
        ok: %Schema{
          type: :boolean,
          description: "True when the credential is valid and the binary responds"
        },
        model: %Schema{
          type: :string,
          nullable: true,
          description: "Version or model string from binary"
        },
        latency_ms: %Schema{type: :integer, description: "Round-trip time to invoke the binary"},
        error: %Schema{
          type: :string,
          nullable: true,
          description: "Error message when ok is false"
        }
      },
      required: [:ok, :latency_ms]
    })
  end

  defmodule AuthStatusResponse do
    @moduledoc "Response from GET /auth/status — per-runtime detection result."

    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuthStatusResponse",
      type: :object,
      description: "Current auth detection state for a runtime",
      properties: %{
        type: %Schema{type: :string, description: "Runtime type identifier"},
        methods: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Ordered list of auth methods this runtime supports"
        },
        subscription_detected: %Schema{
          type: :boolean,
          nullable: true,
          description:
            "True if CLI subscription credentials file was found, null if not applicable"
        },
        cli_logged_in: %Schema{
          type: :boolean,
          nullable: true,
          description: "True if CLI auth status command succeeded, null if not applicable"
        },
        api_key_stored: %Schema{
          type: :boolean,
          nullable: true,
          description: "True if a Canopy-stored API key exists, null if not applicable"
        },
        active_method: %Schema{
          type: :string,
          nullable: true,
          description: "First successfully detected method, or null if none"
        },
        session_env: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Env var names that will be injected on session spawn for this method"
        }
      },
      required: [:type, :methods, :session_env]
    })
  end
end
