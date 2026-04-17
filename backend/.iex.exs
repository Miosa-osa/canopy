# IEx convenience imports for development sessions.
# Loaded automatically when running `iex -S mix` or `iex -S mix phx.server`.

import Ecto.Query
alias Canopy.Repo

# Domain context modules
alias Canopy.Runtimes
alias Canopy.Sessions
alias Canopy.Agents
alias Canopy.Workspaces
alias Canopy.Miosa
alias Canopy.Vault
alias Canopy.Tools
alias Canopy.Governance
alias Canopy.Budgets
alias Canopy.Skills

IO.puts("""
Canopy IEx session loaded.
Available aliases: Repo, Runtimes, Sessions, Agents, Workspaces, Miosa, Vault, Tools, Governance, Budgets, Skills
""")
