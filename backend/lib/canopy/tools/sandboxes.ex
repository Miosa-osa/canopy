defmodule Canopy.Tools.Sandboxes do
  @moduledoc """
  Sandbox operator tool surface for the Sandbox Operator agent.

  Exposes 13 native tools (`sandbox.*`) that wrap `Canopy.SandboxesNg`
  context calls and `Canopy.Miosa.Client` HTTP calls into the canonical
  tool-handler signature so they can be invoked by any runtime adapter
  (Claude / Codex / Gemini / etc.) via MCP or system-prompt injection.

  Tools are registered at application boot via
  `Canopy.Tools.Registry.register_module/1` (see wiring instructions).

  ## Tool list — 13 verbs across 8 groups

  Lifecycle (5):
  - `sandbox.list` — current state of every sandbox
  - `sandbox.provision` — request a new MIOSA VM
  - `sandbox.pause` — preserve memory + filesystem
  - `sandbox.resume` — bring a paused sandbox back online
  - `sandbox.destroy` — terminate, drop forwards, audit

  Snapshots (2):
  - `sandbox.snapshot` — capture filesystem / directory / memory state
  - `sandbox.restore` — bring a snapshot back as a running sandbox

  Forking (1):
  - `sandbox.fork` — duplicate a sandbox's state into a new sandbox

  Exec (1):
  - `sandbox.exec` — run a one-shot command, return exit code + stdout/stderr

  Filesystem (2):
  - `sandbox.read_file` — read a file from the sandbox FS
  - `sandbox.write_file` — write a file into the sandbox FS

  Ports (2):
  - `sandbox.list_ports` — current forwards for a sandbox
  - `sandbox.expose_port` — open a forward (private/token/public)

  Source-of-truth: `docs/10-sandboxes-deepening.md §5`. The full 30-tool
  surface listed there is the eventual goal; this module ships the
  Phase A subset that drives the existing 5-method MIOSA API plus the
  Canopy-side lifecycle/snapshot/port records.
  """

  use Canopy.Tool

  alias Canopy.Miosa.Client
  alias Canopy.SandboxesNg

  # ---------------------------------------------------------------------------
  # Lifecycle (5)
  # ---------------------------------------------------------------------------

  tool("sandbox.list",
    description: """
    Lists the current state of every sandbox the operator has touched.
    Returns the most-recent lifecycle event per sandbox_id, optionally
    filtered by state, owner, or workspace.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "state" => %{"type" => "string"},
        "owner_agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "limit" => %{"type" => "integer"}
      }
    },
    handler: {__MODULE__, :list_sandboxes, []},
    requires: [:sandboxes]
  )

  tool("sandbox.provision",
    description: """
    Provisions a new MIOSA sandbox. Records the lifecycle event on success.
    Refuses to provision without an `owner_agent_id` (orphan-prevention).
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "template" => %{"type" => "string"},
        "ttl_seconds" => %{"type" => "integer"},
        "owner_agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"},
        "tags" => %{"type" => "object", "additionalProperties" => true}
      },
      "required" => ["owner_agent_id"]
    },
    handler: {__MODULE__, :provision, []},
    requires: [:sandboxes]
  )

  tool("sandbox.pause",
    description: """
    Pauses a running sandbox. Memory + filesystem are preserved; compute is
    not billed while paused. Records a `paused` lifecycle event.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"}
      },
      "required" => ["sandbox_id"]
    },
    handler: {__MODULE__, :pause, []},
    requires: [:sandboxes]
  )

  tool("sandbox.resume",
    description: """
    Resumes a paused sandbox. The sandbox is restored to `running` state.
    Records a `running` lifecycle event with `prior_state: paused`.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"}
      },
      "required" => ["sandbox_id"]
    },
    handler: {__MODULE__, :resume, []},
    requires: [:sandboxes]
  )

  tool("sandbox.destroy",
    description: """
    Destroys a sandbox. Closes all open port forwards. Records a
    `destroyed` lifecycle event. Pass `confirm_lose_changes: true` if the
    caller has acknowledged uncommitted changes will be lost.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "confirm_lose_changes" => %{"type" => "boolean"}
      },
      "required" => ["sandbox_id"]
    },
    handler: {__MODULE__, :destroy, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Snapshots (2)
  # ---------------------------------------------------------------------------

  tool("sandbox.snapshot",
    description: """
    Captures a snapshot of a sandbox. `kind` is one of:
    - `filesystem` — full FS image, indefinite retention
    - `directory` — scoped to a path, 30-day retention
    - `memory` — full process state, 7-day retention
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "kind" => %{
          "type" => "string",
          "enum" => ["filesystem", "directory", "memory"]
        },
        "name" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "slug" => %{"type" => "string"}
      },
      "required" => ["sandbox_id", "kind", "slug"]
    },
    handler: {__MODULE__, :snapshot, []},
    requires: [:sandboxes]
  )

  tool("sandbox.restore",
    description: """
    Restores a sandbox from a snapshot. Returns a new sandbox_id. The
    parent snapshot is locked while the restored sandbox exists.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "snapshot_slug" => %{"type" => "string"},
        "owner_agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["snapshot_slug", "owner_agent_id"]
    },
    handler: {__MODULE__, :restore, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Forking (1)
  # ---------------------------------------------------------------------------

  tool("sandbox.fork",
    description: """
    Duplicates a sandbox's current state into a new sandbox. Useful for
    parallel agent experiments without disturbing the source.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "source_sandbox_id" => %{"type" => "string"},
        "owner_agent_id" => %{"type" => "string"},
        "workspace_slug" => %{"type" => "string"}
      },
      "required" => ["source_sandbox_id", "owner_agent_id"]
    },
    handler: {__MODULE__, :fork, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Exec (1)
  # ---------------------------------------------------------------------------

  tool("sandbox.exec",
    description: """
    Runs a one-shot command in a sandbox. Returns
    `{exit_code, stdout, stderr}`. For long-running processes use a
    runtime-adapter PTY session instead.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "command" => %{"type" => "string"},
        "env" => %{"type" => "object", "additionalProperties" => true},
        "timeout_ms" => %{"type" => "integer"}
      },
      "required" => ["sandbox_id", "command"]
    },
    handler: {__MODULE__, :exec, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Filesystem (2)
  # ---------------------------------------------------------------------------

  tool("sandbox.read_file",
    description: """
    Reads a file from the sandbox filesystem via `cat`. Returns the file
    contents and an exit code. Caller must validate path safety.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "path" => %{"type" => "string"}
      },
      "required" => ["sandbox_id", "path"]
    },
    handler: {__MODULE__, :read_file, []},
    requires: [:sandboxes]
  )

  tool("sandbox.write_file",
    description: """
    Writes content to a file in the sandbox filesystem. Uses a
    base64-encoded shell pipeline for binary safety.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "path" => %{"type" => "string"},
        "content" => %{"type" => "string"}
      },
      "required" => ["sandbox_id", "path", "content"]
    },
    handler: {__MODULE__, :write_file, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Ports (2)
  # ---------------------------------------------------------------------------

  tool("sandbox.list_ports",
    description: """
    Lists active port forwards for a sandbox. Each row carries the
    visibility tier, the public URL (if any), and the agent who opened it.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"}
      },
      "required" => ["sandbox_id"]
    },
    handler: {__MODULE__, :list_ports, []},
    requires: [:sandboxes]
  )

  tool("sandbox.expose_port",
    description: """
    Opens a port forward for a sandbox. Default visibility is `private`.
    Setting `visibility: public` requires `confirm_public: true` so the
    operator agent's port-forward-safety rule is honoured.
    """,
    parameters: %{
      "type" => "object",
      "properties" => %{
        "sandbox_id" => %{"type" => "string"},
        "internal_port" => %{"type" => "integer"},
        "protocol" => %{
          "type" => "string",
          "enum" => ["http", "https", "tcp"]
        },
        "visibility" => %{
          "type" => "string",
          "enum" => ["private", "token", "public"]
        },
        "label" => %{"type" => "string"},
        "opened_by_agent_id" => %{"type" => "string"},
        "confirm_public" => %{"type" => "boolean"}
      },
      "required" => ["sandbox_id", "internal_port"]
    },
    handler: {__MODULE__, :expose_port, []},
    requires: [:sandboxes]
  )

  # ---------------------------------------------------------------------------
  # Handlers
  # ---------------------------------------------------------------------------

  @doc false
  def list_sandboxes(args) do
    opts =
      []
      |> put_opt(:state, args["state"])
      |> put_opt(:owner_agent_id, args["owner_agent_id"])
      |> put_opt(:workspace_slug, args["workspace_slug"])

    states = SandboxesNg.list_current_states(opts)
    {:ok, %{count: length(states), sandboxes: Enum.map(states, &serialize_event/1)}}
  end

  @doc false
  def provision(args) do
    opts =
      []
      |> put_opt(:template, args["template"])
      |> put_opt(:ttl_seconds, args["ttl_seconds"])

    case Client.provision_sandbox(opts) do
      {:ok, %{sandbox_id: sandbox_id, url: url, status: status}} ->
        :ok =
          SandboxesNg.record_event(%{
            sandbox_id: sandbox_id,
            state: "provisioning",
            owner_agent_id: parse_uuid(args["owner_agent_id"]),
            workspace_slug: args["workspace_slug"],
            payload: %{
              "template" => args["template"],
              "tags" => args["tags"] || %{},
              "url" => url
            }
          })

        {:ok, %{sandbox_id: sandbox_id, url: url, status: status}}

      {:error, reason} ->
        {:error, format_reason(reason)}
    end
  end

  @doc false
  def pause(%{"sandbox_id" => sandbox_id}) do
    :ok =
      SandboxesNg.record_event(%{
        sandbox_id: sandbox_id,
        state: "paused",
        prior_state: "running",
        reason: "tool:sandbox.pause"
      })

    {:ok, %{sandbox_id: sandbox_id, state: "paused"}}
  end

  @doc false
  def resume(%{"sandbox_id" => sandbox_id}) do
    :ok =
      SandboxesNg.record_event(%{
        sandbox_id: sandbox_id,
        state: "running",
        prior_state: "paused",
        reason: "tool:sandbox.resume"
      })

    {:ok, %{sandbox_id: sandbox_id, state: "running"}}
  end

  @doc false
  def destroy(args) do
    sandbox_id = args["sandbox_id"]

    case Client.destroy_sandbox(sandbox_id) do
      :ok ->
        close_open_forwards(sandbox_id)

        :ok =
          SandboxesNg.record_event(%{
            sandbox_id: sandbox_id,
            state: "destroyed",
            reason: "tool:sandbox.destroy"
          })

        {:ok, %{sandbox_id: sandbox_id, state: "destroyed"}}

      {:error, :not_found} ->
        # Already gone on MIOSA side — record the terminal state anyway.
        :ok =
          SandboxesNg.record_event(%{
            sandbox_id: sandbox_id,
            state: "destroyed",
            reason: "tool:sandbox.destroy:already_gone"
          })

        {:ok, %{sandbox_id: sandbox_id, state: "destroyed"}}

      {:error, reason} ->
        {:error, format_reason(reason)}
    end
  end

  @doc false
  def snapshot(args) do
    sandbox_id = args["sandbox_id"]
    kind = args["kind"]
    slug = args["slug"]

    attrs = %{
      slug: slug,
      sandbox_id: sandbox_id,
      kind: kind,
      name: args["name"],
      path: args["path"]
    }

    case SandboxesNg.create_snapshot(attrs) do
      {:ok, snap} ->
        :ok =
          SandboxesNg.record_event(%{
            sandbox_id: sandbox_id,
            state: "snapshotting",
            reason: "tool:sandbox.snapshot",
            payload: %{"snapshot_slug" => slug, "kind" => kind}
          })

        {:ok,
         %{
           snapshot_id: snap.id,
           slug: snap.slug,
           kind: snap.kind,
           retention_until: snap.retention_until
         }}

      {:error, changeset} ->
        {:error, %{message: "snapshot create failed", details: changeset_errors(changeset)}}
    end
  end

  @doc false
  def restore(args) do
    snapshot_slug = args["snapshot_slug"]

    snap =
      try do
        SandboxesNg.get_snapshot!(snapshot_slug)
      rescue
        Ecto.NoResultsError -> nil
      end

    case snap do
      nil ->
        {:error, %{message: "snapshot not found", slug: snapshot_slug}}

      %{} = snap ->
        case Client.provision_sandbox(template: "snapshot:#{snap.slug}") do
          {:ok, %{sandbox_id: sandbox_id, url: url, status: status}} ->
            :ok =
              SandboxesNg.record_event(%{
                sandbox_id: sandbox_id,
                state: "provisioning",
                owner_agent_id: parse_uuid(args["owner_agent_id"]),
                workspace_slug: args["workspace_slug"],
                reason: "tool:sandbox.restore",
                payload: %{
                  "from_snapshot" => snap.slug,
                  "kind" => snap.kind
                }
              })

            {:ok, %{sandbox_id: sandbox_id, url: url, status: status, from_snapshot: snap.slug}}

          {:error, reason} ->
            {:error, format_reason(reason)}
        end
    end
  end

  @doc false
  def fork(args) do
    source = args["source_sandbox_id"]

    case Client.provision_sandbox(template: "fork:#{source}") do
      {:ok, %{sandbox_id: sandbox_id, url: url, status: status}} ->
        :ok =
          SandboxesNg.record_event(%{
            sandbox_id: sandbox_id,
            state: "provisioning",
            owner_agent_id: parse_uuid(args["owner_agent_id"]),
            workspace_slug: args["workspace_slug"],
            reason: "tool:sandbox.fork",
            payload: %{"forked_from" => source}
          })

        {:ok,
         %{
           sandbox_id: sandbox_id,
           url: url,
           status: status,
           forked_from: source
         }}

      {:error, reason} ->
        {:error, format_reason(reason)}
    end
  end

  @doc false
  def exec(args) do
    sandbox_id = args["sandbox_id"]
    command = args["command"]
    opts = []

    opts =
      if env = args["env"] do
        Keyword.put(opts, :env, env)
      else
        opts
      end

    opts =
      if t = args["timeout_ms"] do
        Keyword.put(opts, :timeout, t)
      else
        opts
      end

    case Client.exec(sandbox_id, command, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, format_reason(reason)}
    end
  end

  @doc false
  def read_file(%{"sandbox_id" => sandbox_id, "path" => path}) do
    # Use cat with controlled quoting to read the file from the sandbox.
    safe_path = String.replace(path, "'", "'\\''")
    command = "cat '#{safe_path}'"

    case Client.exec(sandbox_id, command, []) do
      {:ok, %{exit_code: 0} = result} ->
        {:ok, %{path: path, content: Map.get(result, :stdout, ""), size: byte_size(Map.get(result, :stdout, ""))}}

      {:ok, result} ->
        {:error,
         %{
           message: "read_file failed",
           exit_code: Map.get(result, :exit_code),
           stderr: Map.get(result, :stderr, "")
         }}

      {:error, reason} ->
        {:error, format_reason(reason)}
    end
  end

  @doc false
  def write_file(%{"sandbox_id" => sandbox_id, "path" => path, "content" => content}) do
    safe_path = String.replace(path, "'", "'\\''")
    encoded = Base.encode64(content)
    command = "printf '%s' '#{encoded}' | base64 -d > '#{safe_path}'"

    case Client.exec(sandbox_id, command, []) do
      {:ok, %{exit_code: 0}} ->
        {:ok, %{path: path, written_bytes: byte_size(content)}}

      {:ok, result} ->
        {:error,
         %{
           message: "write_file failed",
           exit_code: Map.get(result, :exit_code),
           stderr: Map.get(result, :stderr, "")
         }}

      {:error, reason} ->
        {:error, format_reason(reason)}
    end
  end

  @doc false
  def list_ports(%{"sandbox_id" => sandbox_id}) do
    forwards = SandboxesNg.list_port_forwards(sandbox_id: sandbox_id, open_only: true)
    {:ok, %{sandbox_id: sandbox_id, count: length(forwards), ports: Enum.map(forwards, &serialize_forward/1)}}
  end

  @doc false
  def expose_port(args) do
    visibility = args["visibility"] || "private"
    confirm = args["confirm_public"] || false

    cond do
      visibility == "public" and not confirm ->
        {:error,
         %{
           message: "public exposure requires confirm_public: true",
           visibility: "public",
           sandbox_id: args["sandbox_id"]
         }}

      true ->
        attrs = %{
          sandbox_id: args["sandbox_id"],
          internal_port: args["internal_port"],
          protocol: args["protocol"] || "http",
          visibility: visibility,
          label: args["label"],
          opened_by_agent_id: parse_uuid(args["opened_by_agent_id"]),
          access_token: maybe_token(visibility)
        }

        case SandboxesNg.create_port_forward(attrs) do
          {:ok, forward} ->
            {:ok, serialize_forward(forward)}

          {:error, changeset} ->
            {:error,
             %{message: "expose_port failed", details: changeset_errors(changeset)}}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, _key, ""), do: opts
  defp put_opt(opts, key, value), do: [{key, value} | opts]

  defp parse_uuid(nil), do: nil

  defp parse_uuid(str) when is_binary(str) do
    case Ecto.UUID.cast(str) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp parse_uuid(_), do: nil

  defp close_open_forwards(sandbox_id) do
    sandbox_id
    |> then(&SandboxesNg.list_port_forwards(sandbox_id: &1, open_only: true))
    |> Enum.each(&SandboxesNg.close_port_forward/1)
  end

  defp maybe_token("token"), do: random_token()
  defp maybe_token(_), do: nil

  defp random_token do
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)
  end

  defp format_reason(:not_found), do: %{message: "sandbox not found"}
  defp format_reason({:unexpected_response, body}), do: %{message: "unexpected miosa response", body: inspect(body)}
  defp format_reason({status, _body}) when is_integer(status), do: %{message: "miosa error", status: status}
  defp format_reason(reason), do: %{message: "miosa error", reason: inspect(reason)}

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp serialize_event(event) do
    %{
      sandbox_id: event.sandbox_id,
      state: event.state,
      prior_state: event.prior_state,
      ts: event.ts,
      owner_agent_id: event.owner_agent_id,
      workspace_slug: event.workspace_slug,
      reason: event.reason,
      payload: event.payload
    }
  end

  defp serialize_forward(forward) do
    %{
      id: forward.id,
      sandbox_id: forward.sandbox_id,
      internal_port: forward.internal_port,
      protocol: forward.protocol,
      visibility: forward.visibility,
      external_url: forward.external_url,
      tcp_endpoint: forward.tcp_endpoint,
      label: forward.label,
      opened_by_agent_id: forward.opened_by_agent_id,
      access_token: forward.access_token,
      closed_at: forward.closed_at
    }
  end
end
