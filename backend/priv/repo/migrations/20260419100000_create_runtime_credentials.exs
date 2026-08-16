defmodule Canopy.Repo.Migrations.CreateRuntimeCredentials do
  use Ecto.Migration

  def change do
    create table(:runtime_credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :runtime_type, :string, null: false
      add :auth_type, :string, null: false
      add :status, :string, null: false, default: "pending"

      # Encrypted credential fields (AES-256-GCM ciphertext stored as bytea)
      add :access_token, :binary
      add :access_token_nonce, :binary
      add :refresh_token, :binary
      add :refresh_token_nonce, :binary
      add :api_key_enc, :binary
      add :api_key_nonce, :binary

      # OAuth metadata
      add :expires_at, :utc_datetime
      add :scopes, {:array, :string}, default: []
      add :last_used_at, :utc_datetime

      # Device-code polling state + any provider-specific metadata
      add :meta, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # One active credential per runtime type — unique on runtime_type alone for v1.
    # Partial unique index: only one non-revoked credential per runtime_type.
    create unique_index(:runtime_credentials, [:runtime_type])

    create index(:runtime_credentials, [:status])
  end
end
