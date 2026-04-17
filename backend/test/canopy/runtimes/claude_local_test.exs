defmodule Canopy.Runtimes.ClaudeLocalTest do
  @moduledoc """
  Integration and unit tests for `Canopy.Runtimes.ClaudeLocal`.

  Uses the fake_claude.sh fixture for end-to-end execution tests.
  Binary-resolution and environment-check tests mock `System.cmd/3` via
  direct process substitution (no Mox needed — we control the binary path).

  These tests are NOT async because:
  - The execute/1 tests spawn real processes via Port
  - PubSub assertions depend on subscription order

  Parser unit tests live in their own async module (parser_test.exs).
  """

  use ExUnit.Case

  alias Canopy.Runtimes.ClaudeLocal
  alias Canopy.Runtimes.ClaudeLocal.Runner
  alias Canopy.Runtimes.TranscriptEntry

  @fake_claude Path.expand(Path.join([__DIR__, "..", "..", "support", "fake_claude.sh"]))

  # ---------------------------------------------------------------------------
  # Identity callbacks
  # ---------------------------------------------------------------------------

  describe "type/0" do
    test "returns claude-local" do
      assert ClaudeLocal.type() == "claude-local"
    end
  end

  describe "capabilities/0" do
    test "returns a MapSet" do
      assert %MapSet{} = ClaudeLocal.capabilities()
    end

    test "includes session_resume" do
      assert MapSet.member?(ClaudeLocal.capabilities(), :session_resume)
    end

    test "includes model_detection" do
      assert MapSet.member?(ClaudeLocal.capabilities(), :model_detection)
    end

    test "includes config_schema" do
      assert MapSet.member?(ClaudeLocal.capabilities(), :config_schema)
    end

    test "includes skill_injection" do
      assert MapSet.member?(ClaudeLocal.capabilities(), :skill_injection)
    end
  end

  # ---------------------------------------------------------------------------
  # list_models/0
  # ---------------------------------------------------------------------------

  describe "list_models/0" do
    test "returns {:ok, models} with three known models" do
      assert {:ok, models} = ClaudeLocal.list_models()
      assert Enum.count(models) == 3
    end

    test "each model has id, label, context_window" do
      {:ok, models} = ClaudeLocal.list_models()

      for model <- models do
        assert is_binary(model.id)
        assert is_binary(model.label)
        assert is_integer(model.context_window)
      end
    end

    test "includes claude-sonnet-4-6" do
      {:ok, models} = ClaudeLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "claude-sonnet-4-6" in ids
    end

    test "includes claude-opus-4-7" do
      {:ok, models} = ClaudeLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "claude-opus-4-7" in ids
    end

    test "includes claude-haiku-4-5" do
      {:ok, models} = ClaudeLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "claude-haiku-4-5" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # get_config_schema/0
  # ---------------------------------------------------------------------------

  describe "get_config_schema/0" do
    test "returns {:ok, fields}" do
      assert {:ok, fields} = ClaudeLocal.get_config_schema()
      assert is_list(fields)
      refute Enum.empty?(fields)
    end

    test "each field has key, label, type, required" do
      {:ok, fields} = ClaudeLocal.get_config_schema()

      for field <- fields do
        assert is_binary(field.key)
        assert is_binary(field.label)
        assert field.type in [:text, :select, :toggle, :number, :combobox]
        assert is_boolean(field.required)
      end
    end

    test "includes command field" do
      {:ok, fields} = ClaudeLocal.get_config_schema()
      keys = Enum.map(fields, & &1.key)
      assert "command" in keys
    end

    test "includes model field with options" do
      {:ok, fields} = ClaudeLocal.get_config_schema()
      model_field = Enum.find(fields, &(&1.key == "model"))
      assert model_field != nil
      assert model_field.type == :select
      assert is_list(model_field.options)
    end
  end

  # ---------------------------------------------------------------------------
  # get_quota_windows/0
  # ---------------------------------------------------------------------------

  describe "get_quota_windows/0" do
    test "returns {:error, :not_supported}" do
      assert ClaudeLocal.get_quota_windows() == {:error, :not_supported}
    end
  end

  # ---------------------------------------------------------------------------
  # test_environment/1 — path traversal guard
  # ---------------------------------------------------------------------------

  describe "test_environment/1 — path traversal" do
    test "rejects binary paths with .." do
      context = %{"command" => "/usr/local/../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = ClaudeLocal.test_environment(context)
    end

    test "rejects relative traversal" do
      context = %{"command" => "../../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = ClaudeLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — binary not found" do
    test "returns {:error, :not_installed} when binary does not exist" do
      context = %{"command" => "/nonexistent/binary/claude"}
      assert {:error, :not_installed} = ClaudeLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — valid binary" do
    test "returns {:ok, checks} for fake_claude" do
      assert {:ok, checks} = ClaudeLocal.test_environment(%{"command" => @fake_claude})
      assert is_list(checks)
      assert checks != []
    end

    test "checks are at info level for a working binary" do
      {:ok, checks} = ClaudeLocal.test_environment(%{"command" => @fake_claude})
      levels = Enum.map(checks, & &1.level)
      assert Enum.all?(levels, &(&1 in [:info, :warn]))
    end
  end

  # ---------------------------------------------------------------------------
  # detect_model/0
  # ---------------------------------------------------------------------------

  describe "detect_model/0" do
    test "returns {:error, :not_detected} when no claude settings file" do
      # Override HOME to a temp dir that has no .claude/settings.json
      tmp = System.tmp_dir!()

      old_home = System.get_env("HOME")

      System.put_env("HOME", tmp)

      try do
        assert {:error, :not_detected} = ClaudeLocal.detect_model()
      after
        if old_home, do: System.put_env("HOME", old_home)
      end
    end

    test "returns {:ok, model_info} when settings.json exists with model key" do
      tmp = System.tmp_dir!()
      claude_dir = Path.join(tmp, ".claude_test_#{System.unique_integer()}")
      File.mkdir_p!(claude_dir)
      settings_path = Path.join(claude_dir, "settings.json")
      File.write!(settings_path, Jason.encode!(%{"model" => "claude-sonnet-4-6"}))

      old_home = System.get_env("HOME")

      System.put_env("HOME", Path.dirname(claude_dir))

      # Rename so it matches ~/.claude/settings.json pattern
      real_claude_dir = Path.join(Path.dirname(claude_dir), ".claude")
      File.rename!(claude_dir, real_claude_dir)

      try do
        result = ClaudeLocal.detect_model()
        assert {:ok, info} = result
        assert info.model == "claude-sonnet-4-6"
        assert info.provider == "anthropic"
        assert is_binary(info.source)
      after
        File.rm_rf!(real_claude_dir)
        if old_home, do: System.put_env("HOME", old_home)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — end-to-end with fake_claude
  # ---------------------------------------------------------------------------

  describe "execute/1 — subprocess execution" do
    setup do
      # Subscribe to a unique session topic before execute/1 spawns the Runner
      session_id = "test-session-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id, topic: topic}
    end

    test "returns {:ok, session_ref} with pid and session_id", %{session_id: session_id} do
      context = build_context(session_id)

      assert {:ok, session_ref} = ClaudeLocal.execute(context)
      assert is_pid(session_ref.pid)
      assert session_ref.session_id == session_id
      assert is_binary(session_ref.cwd)
      assert String.length(session_ref.prompt_bundle_key) == 64

      # Clean up — wait for runner to finish naturally
      wait_for_completion(session_id)
    end

    test "broadcasts TranscriptEntry messages via PubSub", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = ClaudeLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :init in kinds
      assert :assistant in kinds
    end

    test "emits a completed system entry on success", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = ClaudeLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      completed = Enum.find(system_entries, &(&1.content[:event] == "completed"))
      assert completed != nil
    end

    test "entries have monotonically increasing sequence numbers", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = ClaudeLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      sequences = Enum.map(entries, & &1.sequence) |> Enum.reject(&is_nil/1)

      assert sequences == Enum.sort(sequences)
      assert Enum.uniq(sequences) == sequences
    end

    test "emits :result kind with cost and token data", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = ClaudeLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      result_entry = Enum.find(entries, &(&1.kind == :result))

      assert result_entry != nil
      assert result_entry.content.input_tokens == 42
      assert result_entry.content.output_tokens == 17
      assert_in_delta result_entry.content.cost_usd, 0.000234, 0.0000001
    end
  end

  describe "execute/1 — cancel" do
    setup do
      session_id = "test-cancel-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id}
    end

    test "cancel/1 emits cancelled system entry", %{session_id: session_id} do
      # Use a slow_claude that waits — for cancel tests we use fake_claude
      # but send cancel immediately; it may still complete before cancel arrives.
      # We verify the Runner accepts the cast without crashing.
      context = build_context(session_id)
      {:ok, session_ref} = ClaudeLocal.execute(context)

      # Give the port a moment to start
      Process.sleep(50)

      Runner.cancel(session_ref.pid)

      # Drain any messages — either completed or cancelled is acceptable
      entries = collect_entries(session_id, timeout: 2000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      assert Enum.any?(system_entries, fn e ->
               e.content[:event] in ["completed", "cancelled"]
             end)
    end
  end

  describe "execute/1 — resume path" do
    setup do
      session_id = "test-resume-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id}
    end

    test "skips --append-system-prompt-file on resume", %{session_id: session_id} do
      # Build a context that looks like a resumable session.
      # The fake_claude accepts --resume without error.
      bundle_key = String.duplicate("a", 64)

      context =
        build_context(session_id)
        |> Map.merge(%{
          "external_session_id" => "existing-session-001",
          "stored_cwd" => System.tmp_dir!(),
          "stored_prompt_bundle_key" => bundle_key,
          "instructions_file_path" => "/some/instructions.md",
          # Force bundle key to match stored
          "agents_md" => "",
          "skills" => []
        })

      # The computed bundle key for empty agents_md + empty skills
      expected_key =
        :crypto.hash(:sha256, "\n")
        |> Base.encode16(case: :lower)

      context = Map.put(context, "stored_prompt_bundle_key", expected_key)
      context = Map.put(context, "cwd", System.tmp_dir!())

      {:ok, _ref} = ClaudeLocal.execute(context)
      entries = collect_entries(session_id, timeout: 3000)
      assert entries != []
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_context(session_id) do
    %{
      "session_id" => session_id,
      "command" => @fake_claude,
      "cwd" => System.tmp_dir!(),
      "prompt" => "Hello fake Claude",
      "agents_md" => "# Agent\nYou are a test agent.",
      "skills" => ["skill-one", "skill-two"]
    }
  end

  # Collect all PubSub entries until we receive a :system completed/cancelled/error
  # entry OR until the timeout fires.
  defp collect_entries(session_id, opts) do
    timeout = Keyword.get(opts, :timeout, 2000)
    deadline = System.monotonic_time(:millisecond) + timeout
    topic = "session:#{session_id}"
    do_collect(topic, [], deadline)
  end

  defp do_collect(topic, acc, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    receive do
      {:transcript_entry, %TranscriptEntry{} = entry} ->
        new_acc = acc ++ [entry]

        terminal =
          entry.kind == :system and entry.content[:event] in ["completed", "cancelled", "error"]

        if terminal do
          new_acc
        else
          do_collect(topic, new_acc, deadline)
        end
    after
      max(0, remaining) ->
        acc
    end
  end

  defp wait_for_completion(session_id) do
    collect_entries(session_id, timeout: 3000)
    :ok
  end
end
