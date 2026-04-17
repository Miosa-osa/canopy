# Seed data for canopy_dev.
#
# Idempotent — safe to run repeatedly. Uses `upsert_by: :type` so reruns update
# metadata without creating duplicates.
#
# Invoke:    mix run priv/repo/seeds.exs
# Or alias:  mix ecto.setup (runs migrate + seeds together)

alias Canopy.Repo
alias Canopy.Runtimes.Runtime

IO.puts("Seeding runtime catalog...")

# The 9 runtimes Canopy v2 ships in v0.1.
# `installed`, `version`, `binary_path` stay nil until Tauri's runtime_detect
# command reports real data from the user's $PATH.
runtimes = [
  %{
    type: "claude-local",
    kind: "cli",
    name: "Claude Code",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "thinking", "resume", "skills_injection"]
  },
  %{
    type: "codex-local",
    kind: "cli",
    name: "OpenAI Codex",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "resume"]
  },
  %{
    type: "gemini-local",
    kind: "cli",
    name: "Google Gemini",
    enabled: true,
    capabilities: ["streaming", "tool_calls", "thinking"]
  },
  %{
    type: "cursor-local",
    kind: "cli",
    name: "Cursor Agent",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "opencode-local",
    kind: "cli",
    name: "OpenCode",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "aider-local",
    kind: "cli",
    name: "Aider",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "windsurf-local",
    kind: "cli",
    name: "Windsurf",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  },
  %{
    type: "pi-local",
    kind: "cli",
    name: "Pi",
    enabled: true,
    capabilities: ["streaming"]
  },
  %{
    type: "hermes-local",
    kind: "cli",
    name: "Hermes",
    enabled: true,
    capabilities: ["streaming", "tool_calls"]
  }
]

for attrs <- runtimes do
  case Repo.get_by(Runtime, type: attrs.type) do
    nil ->
      %Runtime{}
      |> Runtime.changeset(attrs)
      |> Repo.insert!()

      IO.puts("  inserted: #{attrs.type}")

    existing ->
      existing
      |> Runtime.changeset(Map.take(attrs, [:name, :kind, :enabled, :capabilities]))
      |> Repo.update!()

      IO.puts("  updated:  #{attrs.type}")
  end
end

IO.puts("Done. #{length(runtimes)} runtimes seeded.")
