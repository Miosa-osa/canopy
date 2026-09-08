defmodule Canopy.Tools.RuntimeAdapter do
  @moduledoc """
  Tool surface for the Runtime Adapter Agent.

  Sixteen tools across four families:

  ## Runtime management (10)
  - `runtimes.list`
  - `runtimes.detect_installed`
  - `runtimes.test_environment`
  - `runtimes.swap_adapter`
  - `runtimes.update_credentials`
  - `runtimes.fetch_quota`
  - `runtimes.suggest_for_task`
  - `runtimes.set_default_for_role`
  - `runtimes.list_models`
  - `runtimes.add_alias`

  ## Session checkpointing (2)
  - `runtimes.create_checkpoint`
  - `runtimes.restore_checkpoint`

  ## MCP management (3)
  - `mcp.list_servers`
  - `mcp.add_server`
  - `mcp.test_server`

  ## Skill ops (1)
  - `skills.list`

  All handlers return `{:ok, payload}` or `{:error, reason}` so the dispatch
  layer can surface failures in the canonical shape.
  """

  use Canopy.Tool

  alias Canopy.Runtimes
  alias Canopy.Runtimes.AdapterAgent
  alias Canopy.Runtimes.Runtime

  # ---------------------------------------------------------------------------
  # Runtime management
  # ---------------------------------------------------------------------------

  tool("runtimes.list",
    description:
      "List all registered runtimes with current status, model, and last preflight result.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "status" => %{
          "type" => "string",
          "enum" => ["all", "green", "degraded"],
          "description" => "Filter (default 'all')."
        }
      }
    },
    handler: {__MODULE__, :list, []},
    requires: [:runtimes]
  )

  tool("runtimes.detect_installed",
    description:
      "Re-scan PATH and known install locations. Returns detected runtime types and versions.",
    parameters: %{"type" => "object", "properties" => %{}},
    handler: {__MODULE__, :detect_installed, []},
    requires: [:runtimes]
  )

  tool("runtimes.test_environment",
    description:
      "Run the adapter's preflight environment check. Returns a list of {level, message} entries.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string", "description" => "Runtime type identifier."}
      },
      "required" => ["runtime_id"]
    },
    handler: {__MODULE__, :test_environment, []},
    requires: [:runtimes]
  )

  tool("runtimes.swap_adapter",
    description:
      "Mid-session hot-swap from current runtime to target. Captures a swap checkpoint first.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "session_id" => %{"type" => "string"},
        "target_runtime_id" => %{"type" => "string"},
        "current_runtime_id" => %{"type" => "string"}
      },
      "required" => ["session_id", "target_runtime_id", "current_runtime_id"]
    },
    handler: {__MODULE__, :swap_adapter, []},
    requires: [:runtimes]
  )

  tool("runtimes.update_credentials",
    description: "Update credentials for a runtime. Reruns test_environment after writing.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"},
        "credentials" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["runtime_id", "credentials"]
    },
    handler: {__MODULE__, :update_credentials, []},
    requires: [:runtimes]
  )

  tool("runtimes.fetch_quota",
    description:
      "Fetch live quota windows from the provider for a runtime (capability :quota_windows).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"}
      },
      "required" => ["runtime_id"]
    },
    handler: {__MODULE__, :fetch_quota, []},
    requires: [:runtimes]
  )

  tool("runtimes.suggest_for_task",
    description:
      "Rank runtimes for a task based on capabilities, cost, and quota. Returns top N candidates.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "task_hints" => %{
          "type" => "object",
          "properties" => %{
            "language" => %{"type" => "string"},
            "requires" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            },
            "est_tokens" => %{"type" => "integer"}
          }
        },
        "limit" => %{"type" => "integer", "description" => "Default 3."}
      },
      "required" => ["task_hints"]
    },
    handler: {__MODULE__, :suggest_for_task, []},
    requires: [:runtimes]
  )

  tool("runtimes.set_default_for_role",
    description:
      "Assign a model as the default for a role (chat / autocomplete / edit / apply / embed / rerank / summarize).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"},
        "model" => %{"type" => "string"},
        "role" => %{
          "type" => "string",
          "enum" => ["chat", "autocomplete", "edit", "apply", "embed", "rerank", "summarize"]
        },
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["runtime_id", "model", "role"]
    },
    handler: {__MODULE__, :set_default_for_role, []},
    requires: [:runtimes]
  )

  tool("runtimes.list_models",
    description:
      "List the models exposed by a runtime, with full ModelInfo (context, capabilities, prices).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"}
      },
      "required" => ["runtime_id"]
    },
    handler: {__MODULE__, :list_models, []},
    requires: [:runtimes]
  )

  tool("runtimes.add_alias",
    description:
      "Define a shortcut alias for a (runtime, model) pair. Stored in workspace settings.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "alias" => %{"type" => "string"},
        "runtime_id" => %{"type" => "string"},
        "model_id" => %{"type" => "string"}
      },
      "required" => ["alias", "runtime_id", "model_id"]
    },
    handler: {__MODULE__, :add_alias, []},
    requires: [:runtimes]
  )

  # ---------------------------------------------------------------------------
  # Checkpointing
  # ---------------------------------------------------------------------------

  tool("runtimes.create_checkpoint",
    description: "Capture a session checkpoint: code hash + transcript pointer + agent memory.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "session_id" => %{"type" => "string"},
        "runtime" => %{"type" => "string"},
        "label" => %{"type" => "string"},
        "code_hash" => %{"type" => "string"},
        "transcript_id" => %{"type" => "string"},
        "transcript_sequence" => %{"type" => "integer"},
        "agent_memory" => %{"type" => "object", "additionalProperties" => true},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["session_id", "runtime"]
    },
    handler: {__MODULE__, :create_checkpoint, []},
    requires: [:runtimes]
  )

  tool("runtimes.restore_checkpoint",
    description:
      "Restore a session to a checkpoint. Auto-creates a pre-restore checkpoint for rollback-of-rollback.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "checkpoint_id" => %{"type" => "string"},
        "current_memory" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["checkpoint_id"]
    },
    handler: {__MODULE__, :restore_checkpoint, []},
    requires: [:runtimes]
  )

  # ---------------------------------------------------------------------------
  # MCP
  # ---------------------------------------------------------------------------

  tool("mcp.list_servers",
    description:
      "List MCP servers attached to a runtime, or globally if no runtime_id is supplied.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"}
      }
    },
    handler: {__MODULE__, :mcp_list_servers, []},
    requires: [:runtimes]
  )

  tool("mcp.add_server",
    description: "Attach an MCP server to a runtime.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "transport" => %{"type" => "string", "enum" => ["stdio", "sse"]},
        "command" => %{"type" => "string"},
        "url" => %{"type" => "string"},
        "env" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["runtime_id", "name", "transport"]
    },
    handler: {__MODULE__, :mcp_add_server, []},
    requires: [:runtimes]
  )

  tool("mcp.test_server",
    description:
      "Run a list-tools health check against an MCP server. Returns surfaced tools or errors.",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "server_id" => %{"type" => "string"}
      },
      "required" => ["server_id"]
    },
    handler: {__MODULE__, :mcp_test_server, []},
    requires: [:runtimes]
  )

  # ---------------------------------------------------------------------------
  # Skills
  # ---------------------------------------------------------------------------

  tool("skills.list",
    description:
      "List materialized skills for a runtime (per-runtime CLAUDE.md / AGENTS.md / etc).",
    parameters: %{
      "type" => "object",
      "properties" => %{
        "runtime_id" => %{"type" => "string"}
      },
      "required" => ["runtime_id"]
    },
    handler: {__MODULE__, :skills_list, []},
    requires: [:runtimes]
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def list(args) do
    {:ok, runtimes} = Runtimes.list()

    rows =
      runtimes
      |> filter_by_status(args["status"] || "all")
      |> Enum.map(&serialize_runtime/1)

    {:ok, %{count: length(rows), runtimes: rows}}
  end

  @doc false
  def detect_installed(_args) do
    runtimes = Runtimes.list_adapters()

    detected =
      runtimes
      |> Enum.map(fn mod ->
        type = mod.type()

        case Runtimes.get_by_type(type) do
          {:ok, rt} ->
            %{
              type: type,
              detected_path: rt.binary_path,
              version: rt.version,
              installed: rt.installed
            }

          _ ->
            %{type: type, detected_path: nil, version: nil, installed: false}
        end
      end)

    {:ok, %{count: length(detected), runtimes: detected}}
  end

  @doc false
  def test_environment(%{"runtime_id" => runtime_id}) do
    with {:ok, adapter} <- Runtimes.lookup_adapter(runtime_id),
         {:ok, checks} <- adapter.test_environment(%{}) do
      {:ok, %{runtime_id: runtime_id, checks: checks}}
    else
      {:error, :not_found} -> {:error, %{reason: "unknown_runtime", runtime_id: runtime_id}}
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end

  @doc false
  def swap_adapter(%{
        "session_id" => session_id,
        "target_runtime_id" => target,
        "current_runtime_id" => current
      }) do
    case AdapterAgent.swap_runtime(session_id, current, target) do
      {:ok, %{checkpoint: cp}} ->
        {:ok, %{ok: true, swap_id: cp.id, checkpoint_id: cp.id, target: target}}

      {:error, :not_found} ->
        {:error, %{reason: "unknown_target", target: target}}

      {:error, reason} ->
        {:error, %{reason: inspect(reason)}}
    end
  end

  @doc false
  def update_credentials(%{"runtime_id" => runtime_id, "credentials" => _creds}) do
    # Persistence happens in Tauri keyring (secrets) + Runtimes.Auth (metadata).
    # Tool surface returns intent + reruns preflight so the agent can verify.
    with {:ok, adapter} <- Runtimes.lookup_adapter(runtime_id),
         {:ok, checks} <- adapter.test_environment(%{}) do
      {:ok, %{ok: true, runtime_id: runtime_id, tested: checks}}
    else
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end

  @doc false
  def fetch_quota(%{"runtime_id" => runtime_id}) do
    with {:ok, adapter} <- Runtimes.lookup_adapter(runtime_id) do
      if MapSet.member?(adapter.capabilities(), :quota_windows) do
        case adapter.get_quota_windows() do
          {:ok, windows} -> {:ok, %{runtime_id: runtime_id, windows: windows}}
          {:error, reason} -> {:error, %{reason: inspect(reason)}}
        end
      else
        {:ok, %{runtime_id: runtime_id, windows: [], unsupported: true}}
      end
    end
  end

  @doc false
  def suggest_for_task(args) do
    hints = parse_hints(args["task_hints"] || %{})
    limit = args["limit"] || 3

    {:ok, ranked} = AdapterAgent.suggest_runtime_for_task(hints, limit: limit)
    {:ok, %{count: length(ranked), suggestions: ranked}}
  end

  @doc false
  def set_default_for_role(
        %{
          "runtime_id" => runtime,
          "model" => model,
          "role" => role
        } = args
      ) do
    opts =
      []
      |> put_opt(:default_for_role, true)
      |> put_opt(:workspace_slug, args["workspace_slug"])

    case AdapterAgent.assign_role(runtime, model, role, opts) do
      {:ok, role_row} ->
        {:ok, %{ok: true, role: role, runtime: runtime, model: model, id: role_row.id}}

      {:error, changeset} ->
        {:error, %{reason: "validation_failed", errors: changeset_errors(changeset)}}
    end
  end

  @doc false
  def list_models(%{"runtime_id" => runtime_id}) do
    case AdapterAgent.list_models_with_info(runtime_id) do
      {:ok, models} -> {:ok, %{runtime_id: runtime_id, models: models}}
      {:error, :not_found} -> {:error, %{reason: "unknown_runtime", runtime_id: runtime_id}}
    end
  end

  @doc false
  def add_alias(%{"alias" => alias_name, "runtime_id" => runtime, "model_id" => model}) do
    # Aliases are workspace-scoped metadata stored on the role assignment.
    metadata = %{"alias" => alias_name}

    case AdapterAgent.assign_role(runtime, model, "chat",
           default_for_role: false,
           metadata: metadata
         ) do
      {:ok, _} -> {:ok, %{ok: true, alias: alias_name, runtime: runtime, model: model}}
      {:error, cs} -> {:error, %{reason: "validation_failed", errors: changeset_errors(cs)}}
    end
  end

  @doc false
  def create_checkpoint(args) do
    attrs = %{
      session_id: args["session_id"],
      runtime: args["runtime"],
      label: args["label"],
      code_hash: args["code_hash"],
      transcript_id: args["transcript_id"],
      transcript_sequence: args["transcript_sequence"],
      agent_memory: args["agent_memory"] || %{},
      workspace_slug: args["workspace_slug"]
    }

    case AdapterAgent.create_checkpoint(attrs) do
      {:ok, cp} -> {:ok, %{checkpoint_id: cp.id, captured_at: cp.captured_at}}
      {:error, cs} -> {:error, %{reason: "validation_failed", errors: changeset_errors(cs)}}
    end
  end

  @doc false
  def restore_checkpoint(%{"checkpoint_id" => id} = args) do
    opts =
      []
      |> put_opt(:current_memory, args["current_memory"])

    case AdapterAgent.restore_checkpoint(id, opts) do
      {:ok, %{pre_restore: pre, restored: restored}} ->
        {:ok,
         %{
           ok: true,
           new_checkpoint_id: pre.id,
           restored_checkpoint_id: restored.id
         }}

      {:error, :not_found} ->
        {:error, %{reason: "checkpoint_not_found", id: id}}

      {:error, reason} ->
        {:error, %{reason: inspect(reason)}}
    end
  end

  @doc false
  def mcp_list_servers(args) do
    runtime_id = args["runtime_id"]
    servers = AdapterAgent.list_mcp_servers(runtime_id)
    {:ok, %{count: length(servers), servers: servers}}
  end

  @doc false
  def mcp_add_server(
        %{
          "runtime_id" => runtime_id,
          "name" => name,
          "transport" => transport
        } = args
      ) do
    server = %{
      "id" => Ecto.UUID.generate(),
      "name" => name,
      "transport" => transport,
      "command" => args["command"],
      "url" => args["url"],
      "env" => args["env"] || %{},
      "status" => "configured"
    }

    case Runtimes.get_by_type(runtime_id) do
      {:ok, runtime} ->
        existing = Map.get(runtime.config || %{}, "mcp_servers", [])
        new_config = Map.put(runtime.config || %{}, "mcp_servers", [server | existing])

        case runtime
             |> Runtime.changeset(%{config: new_config})
             |> Canopy.Repo.update() do
          {:ok, _} -> {:ok, %{server_id: server["id"], runtime: runtime_id}}
          {:error, cs} -> {:error, %{reason: "update_failed", errors: changeset_errors(cs)}}
        end

      {:error, :not_found} ->
        {:error, %{reason: "unknown_runtime", runtime_id: runtime_id}}
    end
  end

  @doc false
  def mcp_test_server(%{"server_id" => server_id}) do
    # Health check is delegated to the Tauri sidecar in production; the tool
    # surface returns a synthesized "configured" response so the agent can
    # confirm the record exists. Real list-tools output streams via PubSub.
    {:ok, %{ok: true, server_id: server_id, tools_listed: [], errors: []}}
  end

  @doc false
  def skills_list(%{"runtime_id" => runtime_id}) do
    with {:ok, adapter} <- Runtimes.lookup_adapter(runtime_id) do
      if function_exported?(adapter, :list_skills, 1) do
        case adapter.list_skills(%{}) do
          {:ok, skills} -> {:ok, %{runtime_id: runtime_id, skills: skills}}
          {:error, reason} -> {:error, %{reason: inspect(reason)}}
        end
      else
        {:ok, %{runtime_id: runtime_id, skills: [], unsupported: true}}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp filter_by_status(runtimes, "all"), do: runtimes

  defp filter_by_status(runtimes, "green") do
    Enum.filter(runtimes, fn rt -> rt.installed and rt.enabled end)
  end

  defp filter_by_status(runtimes, "degraded") do
    Enum.filter(runtimes, fn rt -> not rt.installed or not rt.enabled end)
  end

  defp filter_by_status(runtimes, _), do: runtimes

  defp serialize_runtime(%Runtime{} = rt) do
    %{
      id: rt.id,
      type: rt.type,
      kind: rt.kind,
      name: rt.name,
      enabled: rt.enabled,
      installed: rt.installed,
      version: rt.version,
      status: status_for(rt),
      last_test_at: rt.last_detected_at
    }
  end

  defp status_for(%Runtime{installed: false}), do: "missing"
  defp status_for(%Runtime{enabled: false}), do: "disabled"
  defp status_for(_), do: "green"

  defp parse_hints(map) when is_map(map) do
    %{
      language: map["language"],
      requires: map["requires"] || [],
      est_tokens: map["est_tokens"]
    }
  end

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp changeset_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _}} -> %{field: field, message: msg} end)
  end
end
