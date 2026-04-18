defmodule Canopy.Runtimes.GeminiLocal.ArgsTest do
  @moduledoc """
  Unit tests for GeminiLocal.Args — argument construction and dual-key resume.
  All tests are pure (no DB, no processes), so async: true.
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.GeminiLocal.Args

  # ---------------------------------------------------------------------------
  # build/1 — base structure
  # ---------------------------------------------------------------------------

  describe "build/1 — required flags" do
    test "includes --output-format stream-json" do
      {:ok, args} = Args.build(%{})
      assert "--output-format" in args
      assert "stream-json" in args
    end

    test "includes --approval-mode yolo" do
      {:ok, args} = Args.build(%{})
      assert "--approval-mode" in args
      assert "yolo" in args
    end

    test "includes --sandbox=none by default" do
      {:ok, args} = Args.build(%{})
      assert "--sandbox=none" in args
    end

    test "includes --sandbox (no value) when sandbox is true" do
      {:ok, args} = Args.build(%{"sandbox" => true})
      assert "--sandbox" in args
      refute "--sandbox=none" in args
    end
  end

  # ---------------------------------------------------------------------------
  # build/1 — resume via stored external_session_id
  # ---------------------------------------------------------------------------

  describe "build/1 — --resume flag from stored external_session_id" do
    test "injects --resume when external_session_id is present and cwd matches" do
      context = %{
        "external_session_id" => "gemini-session-001",
        "stored_cwd" => "/tmp/workspace",
        "cwd" => "/tmp/workspace"
      }

      {:ok, args} = Args.build(context)
      assert "--resume" in args
      assert "gemini-session-001" in args
    end

    test "does not inject --resume when external_session_id is absent" do
      {:ok, args} = Args.build(%{"cwd" => "/tmp/workspace"})
      refute "--resume" in args
    end

    test "does not inject --resume when cwd differs" do
      context = %{
        "external_session_id" => "gemini-session-001",
        "stored_cwd" => "/tmp/other",
        "cwd" => "/tmp/workspace"
      }

      {:ok, args} = Args.build(context)
      refute "--resume" in args
    end

    test "injects --resume when stored_cwd is blank (blanket match)" do
      context = %{
        "external_session_id" => "gemini-session-001",
        "stored_cwd" => "",
        "cwd" => "/tmp/workspace"
      }

      {:ok, args} = Args.build(context)
      assert "--resume" in args
    end

    test "--prompt appears after --resume when both are present" do
      context = %{
        "external_session_id" => "gemini-session-001",
        "stored_cwd" => "/tmp/workspace",
        "cwd" => "/tmp/workspace",
        "prompt" => "Hello Gemini"
      }

      {:ok, args} = Args.build(context)
      idx_resume = Enum.find_index(args, &(&1 == "--resume"))
      idx_prompt = Enum.find_index(args, &(&1 == "--prompt"))
      assert idx_resume != nil
      assert idx_prompt != nil
      assert idx_resume < idx_prompt
    end
  end

  # ---------------------------------------------------------------------------
  # resolve_resume_session_id/1 — dual-key
  # ---------------------------------------------------------------------------

  describe "resolve_resume_session_id/1 — dual-key (cwd only)" do
    test "returns external_session_id when stored and current cwd match" do
      context = %{
        "external_session_id" => "gemini-match",
        "stored_cwd" => "/home/user",
        "cwd" => "/home/user"
      }

      assert Args.resolve_resume_session_id(context) == "gemini-match"
    end

    test "returns nil when external_session_id is missing" do
      context = %{"stored_cwd" => "/home/user", "cwd" => "/home/user"}
      assert Args.resolve_resume_session_id(context) == nil
    end

    test "returns nil when cwd mismatch" do
      context = %{
        "external_session_id" => "gemini-mismatch",
        "stored_cwd" => "/home/other",
        "cwd" => "/home/user"
      }

      assert Args.resolve_resume_session_id(context) == nil
    end

    test "normalizes cwd with Path.expand before comparison" do
      context = %{
        "external_session_id" => "gemini-expand",
        "stored_cwd" => "/home/user/./project",
        "cwd" => "/home/user/project"
      }

      assert Args.resolve_resume_session_id(context) == "gemini-expand"
    end
  end

  # ---------------------------------------------------------------------------
  # maybe_append/3
  # ---------------------------------------------------------------------------

  describe "maybe_append/3" do
    test "appends extra when condition is true" do
      result = Args.maybe_append(["a"], true, ["b"])
      assert result == ["a", "b"]
    end

    test "returns args unchanged when condition is false" do
      result = Args.maybe_append(["a"], false, ["b"])
      assert result == ["a"]
    end
  end
end
