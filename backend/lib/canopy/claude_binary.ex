defmodule Canopy.ClaudeBinary do
  @moduledoc """
  Locates the Claude CLI binary on the host system.

  Searches `PATH` first, then known install locations under `$HOME`.
  """

  @doc "Returns the absolute path to the `claude` CLI binary."
  @spec find() :: String.t()
  def find do
    case System.find_executable("claude") do
      nil ->
        home = System.get_env("HOME") || "/"

        known_paths = [
          Path.join([home, ".superset", "bin", "claude"]),
          Path.join([home, ".nvm", "versions", "node", "current", "bin", "claude"]),
          Path.join([home, ".local", "bin", "claude"]),
          "/usr/local/bin/claude",
          "/opt/homebrew/bin/claude"
        ]

        Enum.find(known_paths, "/usr/local/bin/claude", &File.exists?/1)

      path ->
        path
    end
  end
end
