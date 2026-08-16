defmodule Canopy.SandboxesNg.LifecycleEvent do
  @moduledoc """
  Append-only lifecycle event for the Sandboxes super-module.

  Captures every state transition of a MIOSA-provisioned sandbox: provision,
  pause, resume, snapshot, fork, archive, recover, destroy. The event log is
  the audit trail for the Sandbox Operator agent and the source of truth for
  the lifecycle status grid in `/sandboxes-ng`.

  ## State vocabulary (8 user-facing states)

  Mapped down from MIOSA's internal status strings via the lifecycle-state
  mapper skill — see `docs/10-sandboxes-deepening.md §3` for the convergence
  rationale.

  - `"provisioning"` — VM being created
  - `"running"` — active, accepting connections
  - `"paused"` — memory + filesystem preserved, no compute billing
  - `"snapshotting"` — transient: a snapshot is being captured
  - `"archived"` — cold storage, restoreable on demand
  - `"resizing"` — transient: vCPU/RAM being changed
  - `"error"` — VM crashed or unreachable; recover with explicit verb
  - `"destroyed"` — terminal; row remains for audit
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @states ~w(provisioning running paused snapshotting archived resizing error destroyed)

  @derive {Jason.Encoder,
           only: [
             :id,
             :sandbox_id,
             :run_id,
             :session_id,
             :workspace_slug,
             :owner_agent_id,
             :state,
             :prior_state,
             :reason,
             :ts,
             :payload,
             :inserted_at
           ]}

  schema "sandbox_lifecycle_events" do
    field :sandbox_id, :string
    field :run_id, :binary_id
    field :session_id, :binary_id
    field :workspace_slug, :string
    field :owner_agent_id, :binary_id
    field :state, :string
    field :prior_state, :string
    field :reason, :string
    field :ts, :utc_datetime_usec
    field :payload, :map, default: %{}

    timestamps(updated_at: false)
  end

  @required ~w(sandbox_id state ts)a
  @optional ~w(run_id session_id workspace_slug owner_agent_id prior_state reason payload)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:sandbox_id, max: 128)
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:prior_state, [nil | @states])
  end

  def states, do: @states
end
