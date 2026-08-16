defmodule Canopy.Repo.Migrations.CreateSandboxPortForwards do
  use Ecto.Migration

  def change do
    create table(:sandbox_port_forwards, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false
      add :sandbox_id, :string, null: false, size: 128
      add :internal_port, :integer, null: false
      add :protocol, :string, null: false, default: "http", size: 8
      add :visibility, :string, null: false, default: "private", size: 16
      add :external_url, :string, size: 1024
      add :tcp_endpoint, :string, size: 256
      add :label, :string, size: 128
      add :process_name, :string, size: 256
      add :opened_by_agent_id, :binary_id
      add :workspace_slug, :string, size: 128
      add :access_token, :string, size: 128
      add :closed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sandbox_port_forwards, [:sandbox_id, :internal_port],
             where: "closed_at IS NULL",
             name: :sandbox_port_forwards_active_uidx
           )

    create index(:sandbox_port_forwards, [:sandbox_id])
    create index(:sandbox_port_forwards, [:visibility])
    create index(:sandbox_port_forwards, [:opened_by_agent_id])
    create index(:sandbox_port_forwards, [:workspace_slug])
  end
end
