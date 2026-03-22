defmodule Canopy.Repo.Migrations.AddCheckedOutAtToIssues do
  use Ecto.Migration

  def change do
    alter table(:issues) do
      add :checked_out_at, :utc_datetime
    end
  end
end
