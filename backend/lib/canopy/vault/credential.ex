defmodule Canopy.Vault.Credential do
  @moduledoc """
  Ecto schema for an encrypted credential stored in the vault.

  Each row holds one field (e.g. `api_key`) for one runtime type (e.g.
  `claude-local`). The plaintext value is never written to this table —
  only the AES-256-GCM ciphertext and the nonce used during encryption.

  The `(runtime_type, field_key)` pair is unique. Updating a credential
  replaces the existing row via an upsert.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @timestamps_opts [type: :utc_datetime_usec]

  schema "credentials" do
    field :runtime_type, :string
    field :field_key, :string
    field :encrypted_value, :binary
    field :nonce, :binary

    timestamps()
  end

  @required ~w(runtime_type field_key encrypted_value nonce)a

  @doc "Changeset for inserting or updating a credential."
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(credential, attrs) do
    credential
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_length(:runtime_type, min: 1, max: 128)
    |> validate_length(:field_key, min: 1, max: 128)
    |> unique_constraint([:runtime_type, :field_key],
      name: :credentials_runtime_type_field_key_index,
      message: "has already been taken"
    )
  end
end
