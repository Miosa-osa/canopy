defmodule Canopy.Runtimes.ClaudeLocal.ArgsTest do
  @moduledoc """
  Unit tests for ClaudeLocal.Args — argument construction and resume logic.
  All tests are pure (no DB, no processes), so async: true.
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.ClaudeLocal.Args

  @bundle_key String.duplicate("a", 64)

  # ---------------------------------------------------------------------------
  # build/2 — base args always present
  # ---------------------------------------------------------------------------

  describe "build/2 — required flags" do
    test "always includes --print, stdin sentinel, stream-json, verbose" do
      {:ok, args} = Args.build(%{}, @bundle_key)
      assert "--print" in args
      assert "-" in args
      assert "--output-format" in args
      assert "stream-json" in args
      assert "--verbose" in args
    end
  end

  # ---------------------------------------------------------------------------
  # build/2 — resume flag injection via stored external_session_id
  # ---------------------------------------------------------------------------

  describe "build/2 — resume flag from stored external_session_id" do
    test "injects --resume when external_session_id is present and cwd matches" do
      context = %{
        "external_session_id" => "ext-session-001",
        "stored_cwd" => "/tmp/project",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context, @bundle_key)
      assert "--resume" in args
      assert "ext-session-001" in args
    end

    test "does not inject --resume when external_session_id is absent" do
      context = %{"cwd" => "/tmp/project"}
      {:ok, args} = Args.build(context, @bundle_key)
      refute "--resume" in args
    end

    test "does not inject --resume when external_session_id is empty string" do
      context = %{"external_session_id" => "", "cwd" => "/tmp/project"}
      {:ok, args} = Args.build(context, @bundle_key)
      refute "--resume" in args
    end

    test "does not inject --resume when cwd differs from stored_cwd" do
      context = %{
        "external_session_id" => "ext-session-001",
        "stored_cwd" => "/tmp/other-project",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context, @bundle_key)
      refute "--resume" in args
    end

    test "injects --resume when stored_cwd is blank (blanket match)" do
      context = %{
        "external_session_id" => "ext-session-001",
        "stored_cwd" => "",
        "cwd" => "/tmp/project"
      }

      {:ok, args} = Args.build(context, @bundle_key)
      assert "--resume" in args
    end

    test "skips --append-system-prompt-file on resume" do
      context = %{
        "external_session_id" => "ext-session-001",
        "stored_cwd" => "/tmp/project",
        "cwd" => "/tmp/project",
        "instructions_file_path" => "/some/instructions.md"
      }

      {:ok, args} = Args.build(context, @bundle_key)
      refute "--append-system-prompt-file" in args
    end

    test "includes --append-system-prompt-file on fresh session" do
      context = %{
        "cwd" => "/tmp/project",
        "instructions_file_path" => "/some/instructions.md"
      }

      {:ok, args} = Args.build(context, @bundle_key)
      assert "--append-system-prompt-file" in args
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_resume_session_id/2 — triple-key logic
  # ---------------------------------------------------------------------------

  describe "resolve_resume_session_id/2 — triple-key" do
    test "returns external_session_id when all three keys match" do
      context = %{
        "external_session_id" => "ext-triple-match",
        "stored_cwd" => "/home/user/project",
        "stored_prompt_bundle_key" => @bundle_key,
        "cwd" => "/home/user/project"
      }

      assert Args.resolve_resume_session_id(context, @bundle_key) == "ext-triple-match"
    end

    test "returns nil when stored_prompt_bundle_key differs" do
      stored_key = String.duplicate("b", 64)

      context = %{
        "external_session_id" => "ext-key-mismatch",
        "stored_cwd" => "/home/user/project",
        "stored_prompt_bundle_key" => stored_key,
        "cwd" => "/home/user/project"
      }

      assert Args.resolve_resume_session_id(context, @bundle_key) == nil
    end

    test "returns id when stored_prompt_bundle_key is blank (key check skipped)" do
      context = %{
        "external_session_id" => "ext-no-key",
        "stored_cwd" => "/home/user/project",
        "stored_prompt_bundle_key" => "",
        "cwd" => "/home/user/project"
      }

      assert Args.resolve_resume_session_id(context, @bundle_key) == "ext-no-key"
    end

    test "returns nil when external_session_id is blank" do
      context = %{
        "external_session_id" => "",
        "stored_cwd" => "/home/user/project",
        "cwd" => "/home/user/project"
      }

      assert Args.resolve_resume_session_id(context, @bundle_key) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # maybe_append/3
  # ---------------------------------------------------------------------------

  describe "maybe_append/3" do
    test "appends when condition is true" do
      result = Args.maybe_append(["a"], true, ["b", "c"])
      assert result == ["a", "b", "c"]
    end

    test "returns args unchanged when condition is false" do
      result = Args.maybe_append(["a"], false, ["b"])
      assert result == ["a"]
    end
  end
end
