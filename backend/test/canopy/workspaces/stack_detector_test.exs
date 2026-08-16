defmodule Canopy.Workspaces.StackDetectorTest do
  @moduledoc """
  Tests for StackDetector and RulesScanner.
  """

  use ExUnit.Case, async: true

  alias Canopy.Workspaces.RulesScanner
  alias Canopy.Workspaces.StackDetector

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_dir do
    dir =
      System.tmp_dir!()
      |> Path.join("canopy-detect-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp write(dir, rel, content) do
    path = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  # ---------------------------------------------------------------------------
  # StackDetector — invalid input
  # ---------------------------------------------------------------------------

  describe "detect/1 — invalid paths" do
    test "returns error for nil" do
      assert {:error, :invalid_path} = StackDetector.detect(nil)
    end

    test "returns error for non-existent directory" do
      assert {:error, :invalid_path} = StackDetector.detect("/tmp/does-not-exist-canopy-xyz")
    end

    test "returns empty list for empty directory" do
      dir = tmp_dir()
      assert {:ok, []} = StackDetector.detect(dir)
    end
  end

  # ---------------------------------------------------------------------------
  # StackDetector — Elixir / Phoenix
  # ---------------------------------------------------------------------------

  describe "detect/1 — Elixir" do
    test "detects elixir from mix.exs" do
      dir = tmp_dir()
      write(dir, "mix.exs", "defmodule MyApp.MixProject do\n  use Mix.Project\nend\n")

      {:ok, stacks} = StackDetector.detect(dir)
      assert length(stacks) == 1
      [stack] = stacks
      assert stack.language == "elixir"
      assert stack.package_manager == "mix"
      assert "mix.exs" in stack.markers_found
    end

    test "detects phoenix framework from mix.exs deps" do
      dir = tmp_dir()

      write(dir, "mix.exs", """
      defmodule MyApp.MixProject do
        use Mix.Project
        def deps do
          [{:phoenix, "~> 1.7"}, {:ecto_sql, "~> 3.0"}]
        end
      end
      """)

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert stack.language == "elixir"
      assert stack.framework == "phoenix"
    end

    test "framework is nil when no phoenix dep" do
      dir = tmp_dir()
      write(dir, "mix.exs", "defmodule App.MixProject do\n  use Mix.Project\nend\n")

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert is_nil(stack.framework)
    end
  end

  # ---------------------------------------------------------------------------
  # StackDetector — Node / TypeScript / SvelteKit
  # ---------------------------------------------------------------------------

  describe "detect/1 — Node / TypeScript" do
    test "detects sveltekit from package.json" do
      dir = tmp_dir()

      write(dir, "package.json", ~s({"name":"app","devDependencies":{"@sveltejs/kit":"^2.0"}}))
      write(dir, "pnpm-lock.yaml", "lockfileVersion: '6.0'")

      {:ok, stacks} = StackDetector.detect(dir)
      assert length(stacks) == 1
      [stack] = stacks
      assert stack.language == "typescript"
      assert stack.framework == "sveltekit"
      assert stack.package_manager == "pnpm"
    end

    test "detects nextjs from package.json" do
      dir = tmp_dir()
      write(dir, "package.json", ~s({"dependencies":{"next":"14.0.0","react":"18.0.0"}}))
      write(dir, "package-lock.json", "{}")

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert stack.framework == "nextjs"
      assert stack.package_manager == "npm"
    end

    test "detects react without nextjs" do
      dir = tmp_dir()
      write(dir, "package.json", ~s({"dependencies":{"react":"18.0.0","react-dom":"18.0.0"}}))

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert stack.framework == "react"
    end
  end

  # ---------------------------------------------------------------------------
  # StackDetector — Rust, Go
  # ---------------------------------------------------------------------------

  describe "detect/1 — Rust" do
    test "detects rust from Cargo.toml" do
      dir = tmp_dir()
      write(dir, "Cargo.toml", "[package]\nname = \"myapp\"\nversion = \"0.1.0\"\n")

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert stack.language == "rust"
      assert stack.package_manager == "cargo"
    end
  end

  describe "detect/1 — Go" do
    test "detects go from go.mod" do
      dir = tmp_dir()
      write(dir, "go.mod", "module github.com/example/myapp\n\ngo 1.21\n")

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      assert stack.language == "go"
      assert stack.package_manager == "go"
    end
  end

  # ---------------------------------------------------------------------------
  # StackDetector — monorepo detection
  # ---------------------------------------------------------------------------

  describe "detect/1 — monorepo" do
    test "sets monorepo flag when turbo.json present" do
      dir = tmp_dir()
      write(dir, "turbo.json", ~s({"pipeline":{}}))
      write(dir, "package.json", ~s({"workspaces":["apps/*"]}))
      write(dir, "pnpm-workspace.yaml", "packages:\n  - 'apps/*'\n")

      {:ok, stacks} = StackDetector.detect(dir)
      assert Enum.all?(stacks, & &1.monorepo)
    end

    test "monorepo flag is false without monorepo markers" do
      dir = tmp_dir()
      write(dir, "mix.exs", "defmodule App.MixProject do\n  use Mix.Project\nend\n")

      {:ok, stacks} = StackDetector.detect(dir)
      [stack] = stacks
      refute stack.monorepo
    end
  end

  # ---------------------------------------------------------------------------
  # StackDetector — multiple stacks (monorepo)
  # ---------------------------------------------------------------------------

  describe "detect/1 — multiple stacks" do
    test "returns multiple stacks for mixed-language repo" do
      dir = tmp_dir()
      write(dir, "mix.exs", "defmodule App.MixProject do\n  use Mix.Project\nend\n")
      write(dir, "package.json", ~s({"name":"app","devDependencies":{"@sveltejs/kit":"^2.0"}}))
      write(dir, "Cargo.toml", "[package]\nname = \"native\"\n")

      {:ok, stacks} = StackDetector.detect(dir)
      languages = Enum.map(stacks, & &1.language)
      assert "elixir" in languages
      assert "typescript" in languages
      assert "rust" in languages
    end
  end

  # ---------------------------------------------------------------------------
  # RulesScanner — invalid input
  # ---------------------------------------------------------------------------

  describe "RulesScanner.scan/1 — invalid paths" do
    test "returns error for nil" do
      assert {:error, :invalid_path} = RulesScanner.scan(nil)
    end

    test "returns error for non-existent directory" do
      assert {:error, :invalid_path} = RulesScanner.scan("/tmp/does-not-exist-canopy-abc")
    end

    test "returns empty list when no rule files present" do
      dir = tmp_dir()
      assert {:ok, []} = RulesScanner.scan(dir)
    end
  end

  # ---------------------------------------------------------------------------
  # RulesScanner — file detection
  # ---------------------------------------------------------------------------

  describe "RulesScanner.scan/1 — detection" do
    test "finds CLAUDE.md at root" do
      dir = tmp_dir()
      write(dir, "CLAUDE.md", "# My Rules\n\nDo not do X.\n")

      {:ok, results} = RulesScanner.scan(dir)
      assert length(results) == 1
      [entry] = results
      assert entry.file == "CLAUDE.md"
      assert String.contains?(entry.content, "My Rules")
    end

    test "finds nested .claude/CLAUDE.md" do
      dir = tmp_dir()
      write(dir, ".claude/CLAUDE.md", "# Nested rules\n")

      {:ok, results} = RulesScanner.scan(dir)
      files = Enum.map(results, & &1.file)
      assert ".claude/CLAUDE.md" in files
    end

    test "finds .cursorrules" do
      dir = tmp_dir()
      write(dir, ".cursorrules", "always use TypeScript strict mode")

      {:ok, results} = RulesScanner.scan(dir)
      files = Enum.map(results, & &1.file)
      assert ".cursorrules" in files
    end

    test "finds multiple rule files" do
      dir = tmp_dir()
      write(dir, "CLAUDE.md", "# Claude rules\n")
      write(dir, "AGENTS.md", "# Agent manifest\n")
      write(dir, ".cursorrules", "use strict mode")
      write(dir, ".github/copilot-instructions.md", "# Copilot\n")

      {:ok, results} = RulesScanner.scan(dir)
      files = Enum.map(results, & &1.file)
      assert "CLAUDE.md" in files
      assert "AGENTS.md" in files
      assert ".cursorrules" in files
      assert ".github/copilot-instructions.md" in files
    end

    test "returns content for each found file" do
      dir = tmp_dir()
      write(dir, "CONVENTIONS.md", "Use 2-space indentation everywhere.\n")

      {:ok, results} = RulesScanner.scan(dir)
      [entry] = results
      assert entry.content == "Use 2-space indentation everywhere.\n"
    end
  end
end
