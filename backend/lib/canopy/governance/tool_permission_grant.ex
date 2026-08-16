defmodule Canopy.Governance.ToolPermissionGrant do
  @moduledoc """
  Ecto schema for a tool permission grant.

  Instead of a binary approve/reject, tool permissions carry one of five scopes
  that control how long and under what conditions a grant is valid:

    - "once"    — consumed on first use (`used` flips to true)
    - "session" — valid for a specific session_id; expires when session ends
    - "today"   — valid until end of current UTC day (`expires_at` auto-set)
    - "forever" — no expiry, no session restriction
    - "never"   — permanent deny; blocks the tool for this agent regardless of
                  other grants

  Priority when multiple grants exist for the same (agent_slug, tool_name):
    never > forever > today > session > once

  `granted_by` records who issued the grant — defaults to "human" for
  interactive approvals. Automated grants may set "system" or an agent slug.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @valid_scopes ~w(once session today forever never)

  @derive {Jason.Encoder,
           only: [
             :id,
             :agent_slug,
             :tool_name,
             :scope,
             :workspace_slug,
             :session_id,
             :granted_by,
             :expires_at,
             :used,
             :inserted_at,
             :updated_at
           ]}

  schema "tool_permission_grants" do
    field :agent_slug, :string
    field :tool_name, :string
    field :scope, :string
    field :workspace_slug, :string
    field :session_id, :binary_id
    field :granted_by, :string, default: "human"
    field :expires_at, :utc_datetime_usec
    field :used, :boolean, default: false

    timestamps()
  end

  @required ~w(agent_slug tool_name scope)a
  @optional ~w(workspace_slug session_id granted_by expires_at used)a

  @doc "Returns the list of valid scope values."
  @spec valid_scopes() :: [String.t()]
  def valid_scopes, do: @valid_scopes

  @doc "Changeset for creating a new tool permission grant."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(grant, attrs) do
    grant
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:agent_slug, min: 1, max: 255)
    |> validate_length(:tool_name, min: 1, max: 255)
    |> validate_inclusion(:scope, @valid_scopes)
  end
end
