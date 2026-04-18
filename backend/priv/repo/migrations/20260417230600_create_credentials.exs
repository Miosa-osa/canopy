defmodule Canopy.Repo.Migrations.CreateCredentials do
  use Ecto.Migration

  def change do
    create table(:credentials, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :runtime_type, :string, null: false
      add :field_key, :string, null: false
      add :encrypted_value, :binary, null: false
      add :nonce, :binary, null: false

      timestamps(type: :utc_datetime_usec, updated_at: :updated_at)
    end

    create unique_index(:credentials, [:runtime_type, :field_key])
    create index(:credentials, [:runtime_type])
  end
end
