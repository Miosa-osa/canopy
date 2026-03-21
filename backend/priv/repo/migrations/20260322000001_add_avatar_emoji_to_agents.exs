defmodule Canopy.Repo.Migrations.AddAvatarEmojiToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :avatar_emoji, :string, default: "🤖"
    end
  end
end
