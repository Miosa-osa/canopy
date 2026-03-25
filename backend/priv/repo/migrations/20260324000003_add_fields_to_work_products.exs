defmodule Canopy.Repo.Migrations.AddFieldsToWorkProducts do
  use Ecto.Migration

  def change do
    alter table(:work_products) do
      add :type, :string
      add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
      add :content_preview, :text
      add :file_path, :string
      add :file_size_bytes, :integer
      add :status, :string, default: "draft"
      add :quality_score, :integer
    end

    create index(:work_products, [:project_id])
    create index(:work_products, [:type])
    create index(:work_products, [:status])
  end
end
