defmodule Canopy.Runtimes.CodexLocal.ArgsTest do
  @moduledoc """
  Unit tests for CodexLocal.Args — argument construction and resume logic.
  All tests are pure (no DB, no processes), so async: true.
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.CodexLocal.Args

  # ---------------------------------------------------------------------------
  # build/1 — base structure
  # ---------------------------------------------------------------------------

  describe "build/1 — required structure" do
    test "starts with exec and --json" do
      {:ok, args} = Args.build(%{})
      assert List.first(args) == "exec"
      assert "--json" in args
    end

    test "ends with - (stdin sentinel)" do
      {:ok, args} = Args.build(%{})
      assert List.last(args) == "-"
    end
  end

  # ---------------------------------------------------------------------------
  # build/1 — resume via stored external_session_id
  # ---------------------------------------------------------------------------

  describe "build/1 — positional resume from stored external_session_id" do
    test "injects resume <id> before - when external_session_id matches cwd" do
      context = %{
        "external_session_id" => "codex-session-001",
        "stored_cwd" => "/tmp/project",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context)
      idx_resume = Enum.find_index(args, &(&1 == "resume"))
      idx_sentinel = Enum.find_index(args, &(&1 == "-"))

      assert idx_resume != nil, "expected 'resume' in args"
      assert Enum.at(args, idx_resume + 1) == "codex-session-001"
      assert idx_resume < idx_sentinel
    end

    test "does not inject resume when external_session_id is absent" do
      {:ok, args} = Args.build(%{"cwd" => "/tmp/project"})
      refute "resume" in args
    end

    test "does not inject resume when cwd differs" do
      context = %{
        "external_session_id" => "codex-session-001",
        "stored_cwd" => "/tmp/other",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context)
      refute "resume" in args
    end

    test "injects resume when stored_cwd is blank (blanket match)" do
      context = %{
        "external_session_id" => "codex-session-001",
        "stored_cwd" => "",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context)
      assert "resume" in args
    end
  end

  # ---------------------------------------------------------------------------
  # build/1 — optional flags
  # ---------------------------------------------------------------------------

  describe "build/1 — optional flags" do
    test "appends --model when present" do
      {:ok, args} = Args.build(%{"model" => "gpt-5.4"})
      assert "--model" in args
      assert "gpt-5.4" in args
    end

    test "appends bypass flag when dangerously_bypass_approvals_and_sandbox is true" do
      {:ok, args} = Args.build(%{"dangerously_bypass_approvals_and_sandbox" => true})
      assert "--dangerously-bypass-approvals-and-sandbox" in args
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_resume_session_id/1
  # ---------------------------------------------------------------------------

  describe "resolve_resume_session_id/1 — dual-key (no bundle key)" do
    test "returns external_session_id when cwd matches" do
      context = %{
        "external_session_id" => "codex-match",
        "stored_cwd" => "/home/user",
        "cwd" => "/home/user"
      }

      assert Args.resolve_resume_session_id(context) == "codex-match"
    end

    test "returns nil when external_session_id is empty" do
      context = %{"external_session_id" => "", "cwd" => "/home/user"}
      assert Args.resolve_resume_session_id(context) == nil
    end

    test "returns nil when cwd differs" do
      context = %{
        "external_session_id" => "codex-mismatch",
        "stored_cwd" => "/home/other",
        "cwd" => "/home/user"
      }

      assert Args.resolve_resume_session_id(context) == nil
    end
  end
end
