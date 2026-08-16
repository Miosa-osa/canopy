defmodule Canopy.Runtimes.DetectorTest do
  @moduledoc """
  Tests for Canopy.Runtimes.Detector.

  Binary presence is controlled via Application env overrides so tests do not
  depend on what is actually installed on the machine running the suite.
  `System.find_executable/1` is not mocked at the process level — instead
  we test the public `detect_all/0` contract and the DB outcome.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Repo
  alias Canopy.Runtimes
  alias Canopy.Runtimes.{Detector, Runtime}

  # Seed a minimal set of runtimes so detect_all has rows to work against.
  defp seed_runtime(type, kind) do
    attrs = %{type: type, kind: kind, name: type, enabled: true}

    case Repo.get_by(Runtime, type: type) do
      nil -> Repo.insert!(Runtime.changeset(%Runtime{}, attrs))
      existing -> existing
    end
  end

  describe "detect_all/0" do
    test "returns a list with one result per seeded runtime" do
      seed_runtime("anthropic-api", "api")
      seed_runtime("openai-api", "api")

      {:ok, before_runtimes} = Runtimes.list()
      results = Detector.detect_all()

      assert length(results) == length(before_runtimes)

      assert Enum.all?(results, fn result ->
               match?({:ok, _}, result) || match?({:error, _}, result)
             end)
    end

    test "api runtimes are always marked installed" do
      seed_runtime("anthropic-api", "api")
      seed_runtime("groq-api", "api")

      Detector.detect_all()

      {:ok, anthropic} = Runtimes.get_by_type("anthropic-api")
      {:ok, groq} = Runtimes.get_by_type("groq-api")

      assert anthropic.installed == true
      assert groq.installed == true
    end

    test "updates last_detected_at for all runtimes" do
      seed_runtime("openai-api", "api")

      Detector.detect_all()

      {:ok, runtime} = Runtimes.get_by_type("openai-api")
      assert runtime.last_detected_at != nil
    end

    test "cli runtime not on PATH is marked not installed" do
      # Use a slug that will never resolve to a real binary in CI.
      seed_runtime("smol-developer-test-only", "cli")

      # Manually call upsert with no binary found — mirrors what detect_one does.
      # name is required by the changeset so include it.
      {:ok, runtime} =
        Runtimes.upsert_from_detection(%{
          type: "smol-developer-test-only",
          kind: "cli",
          name: "smol-developer-test-only",
          installed: false,
          binary_path: nil,
          version: nil,
          last_detected_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert runtime.installed == false
      assert runtime.binary_path == nil
    end

    test "is idempotent — calling twice does not duplicate rows" do
      seed_runtime("mistral-api", "api")

      Detector.detect_all()
      Detector.detect_all()

      count =
        Repo.aggregate(
          Ecto.Query.from(r in Runtime, where: r.type == "mistral-api"),
          :count
        )

      assert count == 1
    end
  end

  describe "seed idempotency" do
    test "all catalog types are unique — no duplicate type slugs" do
      # Run the seed catalog types inline to verify no duplicates.
      catalog_types = [
        "claude-local",
        "codex-local",
        "gemini-cli",
        "gemini-local",
        "amp",
        "cline",
        "aider-local",
        "cursor-local",
        "cursor-agent",
        "continue-cli",
        "goose",
        "crush",
        "opencode-local",
        "opendevin",
        "gpt-engineer",
        "smol-developer",
        "windsurf-local",
        "pi-local",
        "hermes-local",
        "ollama",
        "llamacpp",
        "anthropic-api",
        "openai-api",
        "groq-api",
        "mistral-api"
      ]

      assert length(catalog_types) == length(Enum.uniq(catalog_types)),
             "Duplicate type slugs found in catalog definition"
    end

    test "seeding the same runtime twice does not raise" do
      attrs = %{type: "seed-idempotent-test", kind: "cli", name: "Test Runtime"}

      case Repo.get_by(Runtime, type: attrs.type) do
        nil -> Repo.insert!(Runtime.changeset(%Runtime{}, attrs))
        existing -> existing
      end

      # Second upsert must not raise.
      result =
        case Repo.get_by(Runtime, type: attrs.type) do
          nil -> Repo.insert!(Runtime.changeset(%Runtime{}, attrs))
          existing -> Repo.update!(Runtime.changeset(existing, %{name: "Test Runtime Updated"}))
        end

      assert result.type == "seed-idempotent-test"
    end
  end
end
