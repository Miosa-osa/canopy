defmodule Canopy.Hooks.HookEvent do
  @moduledoc """
  Ecto schema for a hook event received from an AI agent's lifecycle hook.

  Events are written by the notify script injected into agent global configs.
  The `session_id` is nullable: events from Claude sessions started outside
  Canopy arrive with whatever session_id the agent provides, which may be absent.

  Fields:
    - agent      — "claude" | "cursor" | "gemini" | "codex" | "opencode"
    - event      — "PostToolUse" | "Stop" | "UserPromptSubmit" | "PermissionRequest"
    - session_id — agent's session identifier (nil for outside-Canopy sessions)
    - payload    — full JSON body as received from the notify script
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_agents ~w(claude cursor gemini codex opencode)
  @valid_events ~w(PostToolUse Stop UserPromptSubmit PermissionRequest PostToolUseFailure)

  @derive {Jason.Encoder,
           only: [
             :id,
             :agent,
             :event,
             :session_id,
             :run_id,
             :canopy_session_id,
             :payload,
             :inserted_at
           ]}

  schema "hook_events" do
    field :agent, :string
    field :event, :string
    # The agent's own session identifier string (from notify script)
    field :session_id, :string
    field :payload, :map, default: %{}

    # Canopy-internal linkage — both nullable
    field :run_id, :binary_id
    field :canopy_session_id, :binary_id

    timestamps(updated_at: false)
  end

  @doc "Changeset for inserting a new hook event."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:agent, :event, :session_id, :run_id, :canopy_session_id, :payload])
    |> validate_required([:agent, :event, :payload])
    |> validate_inclusion(:agent, @valid_agents)
    |> validate_inclusion(:event, @valid_events)
  end

  @doc "Returns the list of valid agent identifiers."
  @spec valid_agents() :: [String.t()]
  def valid_agents, do: @valid_agents

  @doc "Returns the list of valid event names."
  @spec valid_events() :: [String.t()]
  def valid_events, do: @valid_events
end
