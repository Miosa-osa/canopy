defmodule Canopy.Skills.SkillTest do
  @moduledoc """
  Tests for the Skill Ecto schema and changeset validations.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Skills.Skill

  # ---------------------------------------------------------------------------
  # Valid changeset
  # ---------------------------------------------------------------------------

  describe "changeset/2 — valid attrs" do
    test "accepts minimum required fields" do
      attrs = %{
        slug: "my-skill",
        name: "My Skill",
        content: "# Hello",
        content_hash: hash("# Hello"),
        source: "local",
        provider_format: "generic"
      }

      cs = Skill.changeset(%Skill{}, attrs)
      assert cs.valid?
    end

    test "accepts all optional fields" do
      attrs = %{
        slug: "full-skill",
        name: "Full Skill",
        description: "A complete skill",
        content: "# Content",
        content_hash: hash("# Content"),
        source: "clawhub",
        source_url: "https://clawhub.ai/skills/full-skill",
        provider_format: "claude",
        tags: ["elixir", "backend"],
        enabled: false,
        imported_at: DateTime.utc_now()
      }

      cs = Skill.changeset(%Skill{}, attrs)
      assert cs.valid?
    end

    test "single-character slug is valid" do
      attrs = minimal_attrs(slug: "a")
      cs = Skill.changeset(%Skill{}, attrs)
      assert cs.valid?
    end

    test "accepts all valid provider_formats" do
      for fmt <- Skill.provider_formats() do
        attrs = minimal_attrs(provider_format: fmt)
        cs = Skill.changeset(%Skill{}, attrs)
        assert cs.valid?, "expected valid for provider_format: #{fmt}"
      end
    end

    test "accepts all valid sources" do
      for src <- Skill.sources() do
        attrs = minimal_attrs(source: src)
        cs = Skill.changeset(%Skill{}, attrs)
        assert cs.valid?, "expected valid for source: #{src}"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Required field validations
  # ---------------------------------------------------------------------------

  describe "changeset/2 — required field errors" do
    test "slug is required" do
      cs = Skill.changeset(%Skill{}, Map.delete(minimal_attrs(), :slug))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).slug
    end

    test "name is required" do
      cs = Skill.changeset(%Skill{}, Map.delete(minimal_attrs(), :name))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
    end

    test "content is required" do
      cs = Skill.changeset(%Skill{}, Map.delete(minimal_attrs(), :content))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).content
    end

    test "content_hash is required" do
      cs = Skill.changeset(%Skill{}, Map.delete(minimal_attrs(), :content_hash))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).content_hash
    end

    test "source cannot be nil (explicit nil cast)" do
      # source has a struct default of "local", so omitting it keeps the default.
      # Explicitly nil-ing it out via cast does trigger required validation.
      cs = Skill.changeset(%Skill{source: nil}, Map.delete(minimal_attrs(), :source))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).source
    end

    test "provider_format cannot be nil (explicit nil cast)" do
      cs =
        Skill.changeset(
          %Skill{provider_format: nil},
          Map.delete(minimal_attrs(), :provider_format)
        )

      refute cs.valid?
      assert "can't be blank" in errors_on(cs).provider_format
    end
  end

  # ---------------------------------------------------------------------------
  # Format validations
  # ---------------------------------------------------------------------------

  describe "changeset/2 — format validations" do
    test "slug must be lowercase alphanumeric with hyphens" do
      for invalid <- ["My-Skill", "my skill", "_skill", "skill-", "-skill", "skill!"] do
        cs = Skill.changeset(%Skill{}, minimal_attrs(slug: invalid))
        refute cs.valid?, "expected invalid for slug: #{invalid}"
        assert errors_on(cs)[:slug] != []
      end
    end

    test "slug rejects uppercase" do
      cs = Skill.changeset(%Skill{}, minimal_attrs(slug: "MySkill"))
      refute cs.valid?
    end

    test "slug max 128 chars" do
      long = String.duplicate("a", 129)
      cs = Skill.changeset(%Skill{}, minimal_attrs(slug: long))
      refute cs.valid?
      assert "should be at most 128 character(s)" in errors_on(cs).slug
    end

    test "name max 256 chars" do
      long = String.duplicate("a", 257)
      cs = Skill.changeset(%Skill{}, minimal_attrs(name: long))
      refute cs.valid?
      assert "should be at most 256 character(s)" in errors_on(cs).name
    end

    test "provider_format must be one of the valid values" do
      cs = Skill.changeset(%Skill{}, minimal_attrs(provider_format: "unknown"))
      refute cs.valid?
      assert "is invalid" in errors_on(cs).provider_format
    end

    test "source must be one of the valid values" do
      cs = Skill.changeset(%Skill{}, minimal_attrs(source: "github"))
      refute cs.valid?
      assert "is invalid" in errors_on(cs).source
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp minimal_attrs(overrides \\ []) do
    base = %{
      slug: "test-skill",
      name: "Test Skill",
      content: "# Test",
      content_hash: hash("# Test"),
      source: "local",
      provider_format: "generic"
    }

    Map.merge(base, Map.new(overrides))
  end

  defp hash(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
