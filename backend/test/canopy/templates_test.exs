defmodule Canopy.TemplatesTest do
  @moduledoc """
  Tests for the Canopy.Templates public API context.

  Covers template CRUD, parameter substitution / preview, instantiation
  recording, fork lineage, version snapshots, and edge cases.
  """

  use Canopy.DataCase, async: true

  alias Canopy.Templates
  alias Canopy.Templates.Instantiation
  alias Canopy.Templates.Template
  alias Canopy.Templates.Version

  # ---------------------------------------------------------------------------
  # create_template / list_templates
  # ---------------------------------------------------------------------------

  describe "create_template/1" do
    test "creates a minimal template" do
      assert {:ok, %Template{} = t} =
               Templates.create_template(%{
                 slug: "starter-1",
                 name: "Starter",
                 kind: "workspace"
               })

      assert t.slug == "starter-1"
      assert t.kind == "workspace"
      assert t.version == "0.1.0"
      assert t.verified == false
      assert t.published == false
    end

    test "rejects invalid kind" do
      assert {:error, changeset} =
               Templates.create_template(%{
                 slug: "bad-kind",
                 name: "X",
                 kind: "spaceship"
               })

      assert "is invalid" in errors_on(changeset).kind
    end

    test "rejects duplicate slug" do
      attrs = %{slug: "dup-template", name: "T", kind: "workspace"}
      assert {:ok, _} = Templates.create_template(attrs)
      assert {:error, changeset} = Templates.create_template(attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "stores body and parameters maps" do
      assert {:ok, t} =
               Templates.create_template(%{
                 slug: "with-body",
                 name: "Body",
                 kind: "persona",
                 body: %{"identity" => "You are {{role}}."},
                 parameters: %{
                   "role" => %{"type" => "string", "required" => true}
                 }
               })

      assert t.body == %{"identity" => "You are {{role}}."}
      assert t.parameters["role"]["required"] == true
    end
  end

  describe "list_templates/1" do
    setup do
      Templates.create_template(%{slug: "ws-1", name: "Workspace 1", kind: "workspace"})

      Templates.create_template(%{
        slug: "ws-2",
        name: "Workspace 2",
        kind: "workspace",
        verified: true
      })

      Templates.create_template(%{slug: "p-1", name: "Persona 1", kind: "persona"})
      :ok
    end

    test "returns all templates" do
      assert length(Templates.list_templates()) == 3
    end

    test "filters by kind" do
      assert length(Templates.list_templates(kind: "workspace")) == 2
      assert length(Templates.list_templates(kind: "persona")) == 1
    end

    test "filters by verified" do
      [t] = Templates.list_templates(verified: true)
      assert t.slug == "ws-2"
    end

    test "filters by search term" do
      [t] = Templates.list_templates(search: "Persona 1")
      assert t.slug == "p-1"
    end

    test "respects limit" do
      assert length(Templates.list_templates(limit: 1)) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # preview_template / parameter substitution
  # ---------------------------------------------------------------------------

  describe "preview_template/2" do
    test "renders body with provided parameters" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "preview-basic",
          name: "Preview",
          kind: "persona",
          body: %{"identity" => "You are {{role}} for {{client}}."},
          parameters: %{
            "role" => %{"type" => "string", "required" => true},
            "client" => %{"type" => "string", "required" => true}
          }
        })

      assert {:ok, %{body: body, resolved_params: resolved}} =
               Templates.preview_template(t, %{"role" => "analyst", "client" => "Acme"})

      assert body["identity"] == "You are analyst for Acme."
      assert resolved["role"] == "analyst"
      assert resolved["client"] == "Acme"
    end

    test "substitutes nested map and list values" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "preview-nested",
          name: "Nested",
          kind: "workspace",
          body: %{
            "files" => [
              %{"path" => "company.yaml", "content" => "name: {{workspace_name}}"},
              %{"path" => "README.md", "content" => "# {{workspace_name}}"}
            ]
          },
          parameters: %{
            "workspace_name" => %{"type" => "string", "required" => true}
          }
        })

      assert {:ok, %{body: body}} =
               Templates.preview_template(t, %{"workspace_name" => "canopy-fork"})

      [first, second] = body["files"]
      assert first["content"] == "name: canopy-fork"
      assert second["content"] == "# canopy-fork"
    end

    test "uses defaults for unsupplied optional params" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "preview-default",
          name: "Default",
          kind: "persona",
          body: %{"greeting" => "Hello {{name}}"},
          parameters: %{
            "name" => %{"type" => "string", "default" => "world", "required" => false}
          }
        })

      assert {:ok, %{body: body}} = Templates.preview_template(t, %{})
      assert body["greeting"] == "Hello world"
    end

    test "returns missing_parameters error when required is unset" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "preview-missing",
          name: "Missing",
          kind: "persona",
          body: %{"x" => "{{a}} {{b}}"},
          parameters: %{
            "a" => %{"type" => "string", "required" => true},
            "b" => %{"type" => "string", "required" => true}
          }
        })

      assert {:error, {:missing_parameters, missing}} =
               Templates.preview_template(t, %{"a" => "1"})

      assert missing == ["b"]
    end

    test "leaves unbound variables as literal in non-required case" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "preview-unbound",
          name: "Unbound",
          kind: "persona",
          body: %{"x" => "{{undeclared}}"},
          parameters: %{}
        })

      assert {:ok, %{body: body}} = Templates.preview_template(t, %{})
      assert body["x"] == "{{undeclared}}"
    end
  end

  # ---------------------------------------------------------------------------
  # record_instantiation / list_instantiations
  # ---------------------------------------------------------------------------

  describe "record_instantiation/1" do
    test "records a successful instantiation" do
      {:ok, _} =
        Templates.create_template(%{slug: "inst-tpl", name: "I", kind: "workspace"})

      assert {:ok, %Instantiation{} = inst} =
               Templates.record_instantiation(%{
                 template_slug: "inst-tpl",
                 template_version: "0.1.0",
                 target_workspace_slug: "my-ws",
                 status: "success",
                 files_written: 12,
                 agents_created: 3,
                 skills_installed: 5
               })

      assert inst.status == "success"
      assert inst.files_written == 12
    end

    test "rejects invalid status" do
      assert {:error, changeset} =
               Templates.record_instantiation(%{
                 template_slug: "x",
                 template_version: "0.1.0",
                 status: "exploded"
               })

      assert "is invalid" in errors_on(changeset).status
    end

    test "bumps popularity_count on the parent template" do
      {:ok, t} =
        Templates.create_template(%{slug: "pop-tpl", name: "P", kind: "workspace"})

      assert t.popularity_count == 0

      Templates.record_instantiation(%{
        template_slug: "pop-tpl",
        template_version: "0.1.0",
        status: "success"
      })

      reloaded = Templates.get_template!("pop-tpl")
      assert reloaded.popularity_count == 1
    end
  end

  describe "list_instantiations/1" do
    test "returns instantiations ordered by inserted_at desc and filters by status" do
      {:ok, _} = Templates.create_template(%{slug: "ll-1", name: "L", kind: "workspace"})

      Templates.record_instantiation(%{
        template_slug: "ll-1",
        template_version: "0.1.0",
        status: "success"
      })

      Templates.record_instantiation(%{
        template_slug: "ll-1",
        template_version: "0.1.0",
        status: "failed",
        error: "target_path_not_empty"
      })

      assert length(Templates.list_instantiations(template_slug: "ll-1")) == 2

      [failed] = Templates.list_instantiations(status: "failed")
      assert failed.error == "target_path_not_empty"
    end
  end

  # ---------------------------------------------------------------------------
  # fork_template
  # ---------------------------------------------------------------------------

  describe "fork_template/2" do
    test "creates a new template referencing the parent" do
      {:ok, parent} =
        Templates.create_template(%{
          slug: "parent-tpl",
          name: "Parent",
          kind: "workspace",
          body: %{"x" => 1},
          parameters: %{"y" => %{"type" => "string"}}
        })

      assert {:ok, forked} =
               Templates.fork_template(parent, %{slug: "child-tpl", name: "Child"})

      assert forked.parent_template_id == parent.id
      assert forked.forked_from_slug == "parent-tpl"
      assert forked.body == %{"x" => 1}
      assert forked.kind == "workspace"
      assert forked.verified == false
    end

    test "fork without slug fails validation" do
      {:ok, parent} =
        Templates.create_template(%{slug: "parent2", name: "P", kind: "workspace"})

      assert {:error, changeset} = Templates.fork_template(parent, %{name: "no slug"})
      refute Enum.empty?(errors_on(changeset).slug)
    end
  end

  # ---------------------------------------------------------------------------
  # publish_template / list_versions
  # ---------------------------------------------------------------------------

  describe "publish_template/2" do
    test "publishes a template + creates a version snapshot" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "pub-tpl",
          name: "Publish",
          kind: "persona",
          body: %{"identity" => "v1"}
        })

      assert {:ok, %{template: updated, version: %Version{} = v}} =
               Templates.publish_template(t, version: "1.0.0", changelog: "Initial")

      assert updated.published == true
      assert updated.version == "1.0.0"
      assert v.version == "1.0.0"
      assert v.changelog == "Initial"
      assert v.body_snapshot == %{"identity" => "v1"}
      assert byte_size(v.sha256) == 64
    end

    test "computes diff between sequential publishes" do
      {:ok, t} =
        Templates.create_template(%{
          slug: "diff-tpl",
          name: "Diff",
          kind: "persona",
          body: %{"a" => "1", "b" => "2"}
        })

      {:ok, %{template: t}} = Templates.publish_template(t, version: "1.0.0")

      {:ok, t} =
        Templates.update_template(t, %{body: %{"a" => "1", "b" => "changed", "c" => "3"}})

      {:ok, %{version: v2}} = Templates.publish_template(t, version: "1.1.0")

      changed = v2.diff["changed_keys"] || []
      assert "b" in changed
      assert "c" in changed
    end

    test "stores multiple versions per template" do
      {:ok, t} =
        Templates.create_template(%{slug: "ver-tpl", name: "V", kind: "persona"})

      {:ok, _} = Templates.publish_template(t, version: "1.0.0")
      t = Templates.get_template!("ver-tpl")
      {:ok, _} = Templates.publish_template(t, version: "1.1.0")

      versions = Templates.list_versions(t.id)
      assert length(versions) == 2
      assert Enum.map(versions, & &1.version) |> Enum.sort() == ["1.0.0", "1.1.0"]
    end
  end

  describe "get_template!/1" do
    test "raises on unknown slug" do
      assert_raise Ecto.NoResultsError, fn ->
        Templates.get_template!("does-not-exist")
      end
    end
  end
end
