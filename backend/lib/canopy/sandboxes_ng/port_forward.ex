defmodule Canopy.SandboxesNg.PortForward do
  @moduledoc """
  A port-forwarding rule that exposes a sandbox's internal port to outside
  callers.

  ## Visibility tiers

  - `"private"` — only the originating session can reach the URL.
  - `"token"` — accessible with an `x-canopy-traffic-token` header. Token
    is generated server-side and stored in `access_token`.
  - `"public"` — anyone with the URL can connect. Requires explicit human
    confirmation per the Sandbox Operator agent's port-forward-safety rule.

  ## Closure

  Active forwards have `closed_at IS NULL`. Closing sets the timestamp and
  releases the (sandbox_id, internal_port) pair so a new forward can claim
  it. The unique-active index prevents two open forwards for the same
  pair.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @protocols ~w(http https tcp)
  @visibilities ~w(private token public)

  @derive {Jason.Encoder,
           only: [
             :id,
             :sandbox_id,
             :internal_port,
             :protocol,
             :visibility,
             :external_url,
             :tcp_endpoint,
             :label,
             :process_name,
             :opened_by_agent_id,
             :workspace_slug,
             :access_token,
             :closed_at,
             :inserted_at,
             :updated_at
           ]}

  schema "sandbox_port_forwards" do
    field :sandbox_id, :string
    field :internal_port, :integer
    field :protocol, :string, default: "http"
    field :visibility, :string, default: "private"
    field :external_url, :string
    field :tcp_endpoint, :string
    field :label, :string
    field :process_name, :string
    field :opened_by_agent_id, :binary_id
    field :workspace_slug, :string
    field :access_token, :string
    field :closed_at, :utc_datetime_usec

    timestamps()
  end

  @required ~w(sandbox_id internal_port)a
  @optional ~w(protocol visibility external_url tcp_endpoint label process_name opened_by_agent_id workspace_slug access_token closed_at)a

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:sandbox_id, max: 128)
    |> validate_number(:internal_port, greater_than: 0, less_than: 65_536)
    |> validate_inclusion(:protocol, @protocols)
    |> validate_inclusion(:visibility, @visibilities)
    |> unique_constraint([:sandbox_id, :internal_port],
      name: :sandbox_port_forwards_active_uidx,
      message: "already has an open forward for this port"
    )
  end

  def protocols, do: @protocols
  def visibilities, do: @visibilities
end
