defmodule Canopy.Runtimes.RuntimeTest do
  @moduledoc """
  Changeset + schema tests for Canopy.Runtimes.Runtime.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Runtimes.Runtime

  describe "changeset/2 — valid attrs" do
    test "creates a valid changeset with required fields" do
      attrs = %{type: "claude-local", kind: "cli", name: "Claude Code"}
      cs = Runtime.changeset(%Runtime{}, attrs)
      assert cs.valid?
    end

    test "defaults enabled to true and installed to false" do
      attrs = %{type: "codex-local", kind: "api", name: "Codex"}
      cs = Runtime.changeset(%Runtime{}, attrs)
      changeset_data = Ecto.Changeset.apply_changes(cs)
      assert changeset_data.enabled == true
      assert changeset_data.installed == false
    end

    test "accepts optional fields" do
      attrs = %{
        type: "gemini-local",
        kind: "cli",
        name: "Gemini CLI",
        version: "1.2.3",
        binary_path: "/usr/local/bin/gemini",
        capabilities: ["session_resume", "quota_windows"]
      }

      cs = Runtime.changeset(%Runtime{}, attrs)
      assert cs.valid?
    end
  end

  describe "changeset/2 — validation errors" do
    test "requires type" do
      cs = Runtime.changeset(%Runtime{}, %{kind: "cli", name: "X"})
      assert %{type: ["can't be blank"]} = errors_on(cs)
    end

    test "requires kind" do
      cs = Runtime.changeset(%Runtime{}, %{type: "x", name: "X"})
      assert %{kind: ["can't be blank"]} = errors_on(cs)
    end

    test "requires name" do
      cs = Runtime.changeset(%Runtime{}, %{type: "x", kind: "cli"})
      assert %{name: ["can't be blank"]} = errors_on(cs)
    end

    test "rejects invalid kind" do
      cs = Runtime.changeset(%Runtime{}, %{type: "x", kind: "invalid", name: "X"})
      assert %{kind: [_msg]} = errors_on(cs)
    end
  end

  describe "database constraints" do
    test "enforces unique type constraint" do
      attrs = %{type: "claude-local", kind: "cli", name: "Claude Code"}
      {:ok, _first} = Canopy.Repo.insert(Runtime.changeset(%Runtime{}, attrs))

      {:error, cs} = Canopy.Repo.insert(Runtime.changeset(%Runtime{}, attrs))
      assert %{type: ["has already been taken"]} = errors_on(cs)
    end

    test "inserts and retrieves a runtime" do
      attrs = %{type: "aider-local", kind: "cli", name: "Aider"}
      {:ok, runtime} = Canopy.Repo.insert(Runtime.changeset(%Runtime{}, attrs))
      assert runtime.id != nil
      assert runtime.type == "aider-local"
    end
  end
end
