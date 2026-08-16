defmodule Mix.Tasks.Canopy.Seed.Drive do
  @shortdoc "Seed Drive starter content (Personal-scope folders, prompts, workflows, rules)"

  @moduledoc """
  Seeds the Drive super-module with first-boot starter content.

  Idempotent — safe to run repeatedly. Existing entries (matched by slug
  within their parent folder) are skipped, so user edits to a starter entry's
  body are preserved on re-run.

  Usage:

      mix canopy.seed.drive

  This task is also invoked at the end of `mix run priv/repo/seeds.exs`. Run
  it standalone when you want to refresh starter content without rerunning
  the full database seeder.

  ## What gets seeded

  All entries are Personal-scope. Team scope stays empty by design.

      Personal/
      ├── Starter prompts/    (5 prompts with template variables)
      ├── Starter workflows/  (3 workflow placeholders, linked to routines if they exist)
      ├── Starter rules/      (3 rules with `applies_to` selectors)
      ├── MCP Servers/        (empty folder, placeholder for Phase B)
      └── Getting started     (welcome prompt)

  See `Canopy.Drive.Starter` for the full module documentation.
  """

  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Seeding Drive starter content...")

    {inserted, skipped, errored} = Canopy.Drive.Starter.seed!()

    Mix.shell().info("""

    Done.
      inserted: #{inserted}
      skipped:  #{skipped}
      errored:  #{errored}
    """)

    if errored > 0 do
      Mix.shell().error("#{errored} entries failed to insert — check the application log.")
    end

    :ok
  end
end
