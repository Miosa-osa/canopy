defmodule Canopy.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workspace_slug, :string
      add :kind, :string, null: false, default: "artifact"
      add :artifact_type, :string
      add :artifact_id, :string
      add :artifact_preview, :text
      add :tool_name, :string
      add :tool_args, :map
      add :session_id, :binary_id
      add :agent_id, :string
      add :reviewer_id, :string
      add :status, :string, null: false, default: "pending"
      add :feedback, :text
      add :requested_at, :utc_datetime, null: false
      add :decided_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:workspace_slug])
    create index(:reviews, [:status])
    create index(:reviews, [:session_id])
    create index(:reviews, [:agent_id])
    create index(:reviews, [:kind, :status])
  end
end
