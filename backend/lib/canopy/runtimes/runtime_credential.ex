defmodule Canopy.Runtimes.RuntimeCredential do
  @moduledoc """
  Ecto schema for a runtime's authentication credential.

  One row per runtime type (enforced by unique index). Encrypted columns
  (access_token, refresh_token, api_key_enc) are stored as raw AES-256-GCM
  ciphertext using the existing `Canopy.Vault.Crypto` key. Each encrypted column
  has a paired `*_nonce` binary column for decryption.

  Callers must use `Canopy.Runtimes.Auth` for all credential operations —
  this module is persistence-only.

  ## auth_type
  - `:oauth`   — token-based (device code flow or browser redirect)
  - `:api_key` — API key pasted by the user

  ## status
  - `:pending`  — device flow started, token not yet acquired
  - `:active`   — credential is valid and can be used
  - `:expired`  — access token has passed `expires_at`
  - `:revoked`  — explicitly revoked by the user or provider
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  @auth_types ~w(oauth api_key)
  @statuses ~w(pending active expired revoked)

  schema "runtime_credentials" do
    field :runtime_type, :string
    field :auth_type, :string
    field :status, :string, default: "pending"

    field :access_token, :binary
    field :access_token_nonce, :binary
    field :refresh_token, :binary
    field :refresh_token_nonce, :binary
    field :api_key_enc, :binary
    field :api_key_nonce, :binary

    field :expires_at, :utc_datetime
    field :scopes, {:array, :string}, default: []
    field :last_used_at, :utc_datetime
    field :meta, :map, default: %{}

    timestamps()
  end

  @required ~w(runtime_type auth_type)a
  @optional ~w(status access_token access_token_nonce refresh_token refresh_token_nonce
              api_key_enc api_key_nonce expires_at scopes last_used_at meta)a

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(cred, attrs) do
    cred
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:auth_type, @auth_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:runtime_type, min: 1, max: 64)
    |> unique_constraint(:runtime_type, name: :runtime_credentials_runtime_type_index)
  end
end
