defmodule Canopy.Repo.Migrations.AddObanJobsTable do
  @moduledoc """
  Creates the Oban jobs table and supporting indexes.

  Oban requires this table before starting. Without it, queue producers fail
  on boot with 'relation oban_jobs does not exist'. This uses the official
  Oban.Migrations helper to ensure all columns and indexes are correct.
  """

  use Ecto.Migration

  def up, do: Oban.Migrations.up(version: 12)

  def down, do: Oban.Migrations.down(version: 1)
end
