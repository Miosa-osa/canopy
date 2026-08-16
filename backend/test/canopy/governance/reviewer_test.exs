defmodule Canopy.Governance.ReviewerTest do
  @moduledoc """
  Tests for Canopy.Governance.Reviewer.

  Must run async: false because Reviewer reads from the global ETS table owned
  by the RuleCache GenServer. Shared sandbox mode (implicit with async: false)
  lets the GenServer re-read the DB after invalidate() calls.
  """

  use Canopy.DataCase, async: false

  alias Canopy.Governance
  alias Canopy.Governance.{Rule, RuleCache, Reviewer}
  alias Canopy.Reviews

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp flush_cache do
    RuleCache.invalidate()
    Process.sleep(60)
  end

  defp insert_rule!(conditions, overrides \\ %{}) do
    base = %{
      "name" => "reviewer-test-#{System.unique_integer([:positive])}",
      "action" => "require_review",
      "enabled" => true,
      "priority" => 10,
      "conditions" => conditions
    }

    {:ok, rule} = Governance.create_rule(Map.merge(base, overrides))
    flush_cache()
    rule
  end

  defp artifact_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        workspace_slug: "default",
        artifact_type: "doc",
        artifact_id: Ecto.UUID.generate(),
        artifact_preview: "My doc title",
        agent_id: "backend-engineer-engineering",
        session_id: nil
      },
      overrides
    )
  end

  defp tool_call_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        session_id: Ecto.UUID.generate(),
        agent_id: "backend-engineer-engineering",
        tool_name: "exec_shell",
        tool_args: %{"command" => "ls"},
        workspace_slug: "default"
      },
      overrides
    )
  end

  setup do
    # Start each test with a clean ETS state.
    flush_cache()
    :ok
  end

  # ---------------------------------------------------------------------------
  # :artifact — no matching rule
  # ---------------------------------------------------------------------------

  describe "maybe_request_review(:artifact, _) — no matching rule" do
    test "returns :no_review_required when no rules in cache" do
      assert :no_review_required = Reviewer.maybe_request_review(:artifact, artifact_attrs())
    end

    test "returns :no_review_required when rule artifact_types does not include this type" do
      insert_rule!(%{"match" => "artifact", "artifact_types" => ["task"]})

      assert :no_review_required =
               Reviewer.maybe_request_review(:artifact, artifact_attrs(%{artifact_type: "doc"}))
    end

    test "returns :no_review_required when rule match is tool_call" do
      insert_rule!(%{"match" => "tool_call", "tool_names" => ["exec_shell"]})

      assert :no_review_required = Reviewer.maybe_request_review(:artifact, artifact_attrs())
    end

    test "disabled rule is ignored" do
      # Insert disabled — won't appear in ETS even after flush.
      {:ok, _} =
        Governance.create_rule(%{
          "name" => "disabled-reviewer-#{System.unique_integer([:positive])}",
          "action" => "require_review",
          "enabled" => false,
          "conditions" => %{"match" => "artifact", "artifact_types" => ["doc"]}
        })

      flush_cache()

      assert :no_review_required = Reviewer.maybe_request_review(:artifact, artifact_attrs())
    end
  end

  # ---------------------------------------------------------------------------
  # :artifact — matching rule
  # ---------------------------------------------------------------------------

  describe "maybe_request_review(:artifact, _) — matching rule" do
    test "returns {:review_pending, review_id} and creates a DB review" do
      insert_rule!(%{"match" => "artifact", "artifact_types" => ["doc"]})
      attrs = artifact_attrs()

      assert {:review_pending, review_id} = Reviewer.maybe_request_review(:artifact, attrs)

      assert {:ok, review} = Reviews.get(review_id)
      assert review.kind == "artifact"
      assert review.artifact_type == "doc"
      assert review.status == "pending"
      assert review.artifact_id == attrs.artifact_id
      assert review.agent_id == attrs.agent_id
    end

    test "nil artifact_types matches any artifact_type" do
      insert_rule!(%{"match" => "artifact"})

      assert {:review_pending, _} =
               Reviewer.maybe_request_review(:artifact, artifact_attrs(%{artifact_type: "task"}))
    end

    test "agent_ids whitelist — non-matching agent is skipped" do
      insert_rule!(%{
        "match" => "artifact",
        "artifact_types" => ["doc"],
        "agent_ids" => ["special-agent"]
      })

      assert :no_review_required =
               Reviewer.maybe_request_review(
                 :artifact,
                 artifact_attrs(%{agent_id: "other-agent"})
               )
    end

    test "agent_ids whitelist — matching agent triggers review" do
      insert_rule!(%{
        "match" => "artifact",
        "artifact_types" => ["doc"],
        "agent_ids" => ["special-agent"]
      })

      assert {:review_pending, _} =
               Reviewer.maybe_request_review(
                 :artifact,
                 artifact_attrs(%{agent_id: "special-agent"})
               )
    end

    test "workspace_slugs whitelist filters correctly" do
      insert_rule!(%{
        "match" => "artifact",
        "artifact_types" => ["doc"],
        "workspace_slugs" => ["prod"]
      })

      assert :no_review_required =
               Reviewer.maybe_request_review(
                 :artifact,
                 artifact_attrs(%{workspace_slug: "staging"})
               )

      assert {:review_pending, _} =
               Reviewer.maybe_request_review(:artifact, artifact_attrs(%{workspace_slug: "prod"}))
    end
  end

  # ---------------------------------------------------------------------------
  # :tool_call
  # ---------------------------------------------------------------------------

  describe "maybe_request_review(:tool_call, _)" do
    test "returns :no_review_required when no matching rule" do
      assert :no_review_required = Reviewer.maybe_request_review(:tool_call, tool_call_attrs())
    end

    test "returns {:review_pending, id} when tool_call rule matches" do
      insert_rule!(%{"match" => "tool_call", "tool_names" => ["exec_shell"]})
      attrs = tool_call_attrs()

      assert {:review_pending, review_id} = Reviewer.maybe_request_review(:tool_call, attrs)

      assert {:ok, review} = Reviews.get(review_id)
      assert review.kind == "tool_call"
      assert review.tool_name == "exec_shell"
      assert review.status == "pending"
    end

    test "tool_names nil matches any tool" do
      insert_rule!(%{"match" => "tool_call"})

      assert {:review_pending, _} =
               Reviewer.maybe_request_review(
                 :tool_call,
                 tool_call_attrs(%{tool_name: "send_email"})
               )
    end

    test "tool_names whitelist does not match unlisted tool" do
      insert_rule!(%{"match" => "tool_call", "tool_names" => ["exec_shell"]})

      assert :no_review_required =
               Reviewer.maybe_request_review(
                 :tool_call,
                 tool_call_attrs(%{tool_name: "read_file"})
               )
    end
  end

  # ---------------------------------------------------------------------------
  # Integration: Docs.create/1
  # ---------------------------------------------------------------------------

  describe "Docs.create/1 with governance" do
    test "agent-authored doc with matching rule gets review_id stamped" do
      insert_rule!(%{"match" => "artifact", "artifact_types" => ["doc"]})

      {:ok, doc} =
        Canopy.Docs.create(%{
          slug: "agent-doc-#{System.unique_integer([:positive])}",
          workspace_slug: "default",
          title: "Agent-authored document",
          author_type: "agent",
          author_id: "backend-engineer-engineering",
          last_editor_type: "agent",
          last_editor_id: "backend-engineer-engineering"
        })

      assert doc.review_id != nil
      assert {:ok, review} = Reviews.get(doc.review_id)
      assert review.status == "pending"
      assert review.artifact_type == "doc"
    end

    test "user-authored doc is NOT queued even with active rule" do
      insert_rule!(%{"match" => "artifact", "artifact_types" => ["doc"]})

      {:ok, doc} =
        Canopy.Docs.create(%{
          slug: "user-doc-#{System.unique_integer([:positive])}",
          workspace_slug: "default",
          title: "Human-authored document",
          author_type: "user",
          author_id: "roberto",
          last_editor_type: "user",
          last_editor_id: "roberto"
        })

      assert doc.review_id == nil
    end

    test "agent doc with no rule has no review_id" do
      {:ok, doc} =
        Canopy.Docs.create(%{
          slug: "no-rule-doc-#{System.unique_integer([:positive])}",
          workspace_slug: "default",
          title: "Doc with no review rule",
          author_type: "agent",
          author_id: "some-agent",
          last_editor_type: "agent",
          last_editor_id: "some-agent"
        })

      assert doc.review_id == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Rule schema: require_review is a valid action
  # ---------------------------------------------------------------------------

  describe "GovernanceRule.changeset/2 with require_review action" do
    test "accepts require_review as a valid action" do
      cs =
        Rule.changeset(%Rule{}, %{
          name: "test-rr-action",
          action: "require_review",
          conditions: %{"match" => "artifact"}
        })

      assert cs.valid?
    end
  end
end
