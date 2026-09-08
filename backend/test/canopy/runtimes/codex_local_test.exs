defmodule Canopy.Runtimes.CodexLocalTest do
  @moduledoc """
  Integration and unit tests for `Canopy.Runtimes.CodexLocal`.

  Uses the fake_codex.sh fixture for end-to-end execution tests.
  Binary-resolution and environment-check tests rely on direct binary path
  injection via the context map (no Mox needed).

  These tests are NOT async because:
  - The execute/1 tests spawn real processes via Port
  - PubSub assertions depend on subscription order

  Parser unit tests live in their own async module (parser_test.exs).
  """

  # execute/1 builds its environment from Vault, which reads the Repo.
  # Own a sandbox connection instead of borrowing another test's shared owner.
  use Canopy.DataCase, async: false

  alias Canopy.Runtimes.CodexLocal
  alias Canopy.Runtimes.CodexLocal.Runner
  alias Canopy.Runtimes.TranscriptEntry

  @fake_codex Path.expand(Path.join([__DIR__, "..", "..", "support", "fake_codex.sh"]))

  # ---------------------------------------------------------------------------
  # Identity callbacks
  # ---------------------------------------------------------------------------

  describe "type/0" do
    test "returns codex-local" do
      assert CodexLocal.type() == "codex-local"
    end
  end

  describe "capabilities/0" do
    test "returns a MapSet" do
      assert %MapSet{} = CodexLocal.capabilities()
    end

    test "includes session_resume" do
      assert MapSet.member?(CodexLocal.capabilities(), :session_resume)
    end

    test "includes model_detection" do
      assert MapSet.member?(CodexLocal.capabilities(), :model_detection)
    end

    test "includes config_schema" do
      assert MapSet.member?(CodexLocal.capabilities(), :config_schema)
    end

    test "does NOT include skill_injection (Codex has no skill system)" do
      refute MapSet.member?(CodexLocal.capabilities(), :skill_injection)
    end
  end

  # ---------------------------------------------------------------------------
  # list_models/0
  # ---------------------------------------------------------------------------

  describe "list_models/0" do
    test "returns {:ok, models} with known models" do
      assert {:ok, models} = CodexLocal.list_models()
      assert Enum.count(models) >= 5
    end

    test "each model has id, label, context_window" do
      {:ok, models} = CodexLocal.list_models()

      for model <- models do
        assert is_binary(model.id)
        assert is_binary(model.label)
        assert is_integer(model.context_window)
      end
    end

    test "includes gpt-5.3-codex (default model)" do
      {:ok, models} = CodexLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "gpt-5.3-codex" in ids
    end

    test "includes o3" do
      {:ok, models} = CodexLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "o3" in ids
    end

    test "includes gpt-5.4 (fast mode capable)" do
      {:ok, models} = CodexLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "gpt-5.4" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # get_config_schema/0
  # ---------------------------------------------------------------------------

  describe "get_config_schema/0" do
    test "returns {:ok, fields}" do
      assert {:ok, fields} = CodexLocal.get_config_schema()
      assert is_list(fields)
      refute Enum.empty?(fields)
    end

    test "each field has key, label, type, required" do
      {:ok, fields} = CodexLocal.get_config_schema()

      for field <- fields do
        assert is_binary(field.key)
        assert is_binary(field.label)
        assert field.type in [:text, :select, :toggle, :number, :combobox]
        assert is_boolean(field.required)
      end
    end

    test "includes command field" do
      {:ok, fields} = CodexLocal.get_config_schema()
      keys = Enum.map(fields, & &1.key)
      assert "command" in keys
    end

    test "includes model field with options" do
      {:ok, fields} = CodexLocal.get_config_schema()
      model_field = Enum.find(fields, &(&1.key == "model"))
      assert model_field != nil
      assert model_field.type == :select
      assert is_list(model_field.options)
      assert length(model_field.options) >= 5
    end

    test "includes dangerously_bypass_approvals_and_sandbox toggle" do
      {:ok, fields} = CodexLocal.get_config_schema()
      bypass_field = Enum.find(fields, &(&1.key == "dangerously_bypass_approvals_and_sandbox"))
      assert bypass_field != nil
      assert bypass_field.type == :toggle
    end
  end

  # ---------------------------------------------------------------------------
  # get_quota_windows/0
  # ---------------------------------------------------------------------------

  describe "get_quota_windows/0" do
    test "returns {:error, :not_supported}" do
      assert CodexLocal.get_quota_windows() == {:error, :not_supported}
    end
  end

  # ---------------------------------------------------------------------------
  # list_skills/1 + sync_skills/2
  # ---------------------------------------------------------------------------

  describe "list_skills/1" do
    test "returns {:error, :not_implemented}" do
      assert CodexLocal.list_skills(%{}) == {:error, :not_implemented}
    end
  end

  describe "sync_skills/2" do
    test "returns {:error, :not_implemented}" do
      assert CodexLocal.sync_skills(%{}, []) == {:error, :not_implemented}
    end
  end

  # ---------------------------------------------------------------------------
  # test_environment/1 — path traversal guard
  # ---------------------------------------------------------------------------

  describe "test_environment/1 — path traversal" do
    test "rejects binary paths with .." do
      context = %{"command" => "/usr/local/../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = CodexLocal.test_environment(context)
    end

    test "rejects relative traversal" do
      context = %{"command" => "../../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = CodexLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — binary not found" do
    test "returns {:error, :not_installed} when binary does not exist" do
      context = %{"command" => "/nonexistent/binary/codex"}
      assert {:error, :not_installed} = CodexLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — valid binary" do
    test "returns {:ok, checks} for fake_codex" do
      assert {:ok, checks} = CodexLocal.test_environment(%{"command" => @fake_codex})
      assert is_list(checks)
      assert checks != []
    end

    test "checks are at info level for a working binary" do
      {:ok, checks} = CodexLocal.test_environment(%{"command" => @fake_codex})
      levels = Enum.map(checks, & &1.level)
      assert Enum.all?(levels, &(&1 in [:info, :warn]))
    end
  end

  # ---------------------------------------------------------------------------
  # detect_model/0
  # ---------------------------------------------------------------------------

  describe "detect_model/0" do
    test "returns {:error, :not_detected} when no codex config file" do
      tmp = System.tmp_dir!()
      old_codex_home = System.get_env("CODEX_HOME")
      System.put_env("CODEX_HOME", Path.join(tmp, "nonexistent_codex_#{System.unique_integer()}"))

      try do
        assert {:error, :not_detected} = CodexLocal.detect_model()
      after
        if old_codex_home do
          System.put_env("CODEX_HOME", old_codex_home)
        else
          System.delete_env("CODEX_HOME")
        end
      end
    end

    test "returns {:ok, model_info} when config.json exists with model key" do
      tmp = System.tmp_dir!()
      codex_dir = Path.join(tmp, "fake_codex_home_#{System.unique_integer()}")
      File.mkdir_p!(codex_dir)
      config_path = Path.join(codex_dir, "config.json")
      File.write!(config_path, Jason.encode!(%{"model" => "gpt-5.3-codex"}))

      old_codex_home = System.get_env("CODEX_HOME")
      System.put_env("CODEX_HOME", codex_dir)

      try do
        assert {:ok, info} = CodexLocal.detect_model()
        assert info.model == "gpt-5.3-codex"
        assert info.provider == "openai"
        assert is_binary(info.source)
      after
        File.rm_rf!(codex_dir)

        if old_codex_home do
          System.put_env("CODEX_HOME", old_codex_home)
        else
          System.delete_env("CODEX_HOME")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — end-to-end with fake_codex
  # ---------------------------------------------------------------------------

  describe "execute/1 — subprocess execution" do
    setup do
      session_id = "test-codex-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id, topic: topic}
    end

    test "returns {:ok, session_ref} with pid and session_id", %{session_id: session_id} do
      context = build_context(session_id)

      assert {:ok, session_ref} = CodexLocal.execute(context)
      assert is_pid(session_ref.pid)
      assert session_ref.session_id == session_id
      assert is_binary(session_ref.cwd)

      # No prompt_bundle_key — Codex doesn't use it
      refute Map.has_key?(session_ref, :prompt_bundle_key)

      wait_for_completion(session_id)
    end

    test "broadcasts TranscriptEntry messages via PubSub", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :init in kinds
      assert :assistant in kinds
    end

    test "emits a completed system entry on success", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      completed = Enum.find(system_entries, &(&1.content[:event] == "completed"))
      assert completed != nil
    end

    test "entries have monotonically increasing sequence numbers", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      sequences = Enum.map(entries, & &1.sequence) |> Enum.reject(&is_nil/1)

      assert sequences == Enum.sort(sequences)
      assert Enum.uniq(sequences) == sequences
    end

    test "emits :result kind with usage data", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      result_entry = Enum.find(entries, &(&1.kind == :result))

      assert result_entry != nil
      # Values from fake_codex.sh fixture
      assert result_entry.content.input_tokens == 55
      assert result_entry.content.output_tokens == 23
      assert result_entry.content.cache_read_tokens == 10
    end

    test "emits :init entry with fake thread_id", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      init_entry = Enum.find(entries, &(&1.kind == :init))

      assert init_entry != nil
      assert init_entry.content.session_id == "fake-thread-id-001"
    end

    test "emits :thinking entry from reasoning item", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      assert Enum.any?(entries, &(&1.kind == :thinking))
    end

    test "emits :tool_call and :tool_result entries", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = CodexLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :tool_call in kinds
      assert :tool_result in kinds
    end
  end

  describe "execute/1 — cancel" do
    setup do
      session_id = "test-codex-cancel-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id}
    end

    test "cancel/1 emits cancelled system entry", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, session_ref} = CodexLocal.execute(context)

      # Give the port a moment to start
      Process.sleep(50)

      Runner.cancel(session_ref.pid)

      entries = collect_entries(session_id, timeout: 2000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      assert Enum.any?(system_entries, fn e ->
               e.content[:event] in ["completed", "cancelled"]
             end)
    end
  end

  describe "execute/1 — resume path" do
    setup do
      session_id = "test-codex-resume-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id}
    end

    test "resumes with external_session_id when cwd matches", %{session_id: session_id} do
      context =
        build_context(session_id)
        |> Map.merge(%{
          "external_session_id" => "existing-thread-id-001",
          "stored_cwd" => System.tmp_dir!(),
          "cwd" => System.tmp_dir!()
        })

      {:ok, _ref} = CodexLocal.execute(context)
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
      "command" => @fake_codex,
      "cwd" => System.tmp_dir!(),
      "prompt" => "Hello fake Codex"
    }
  end

  # Collect all PubSub entries until we receive a :system completed/cancelled/error
  # entry OR until the timeout fires.
  defp collect_entries(session_id, opts) do
    timeout = Keyword.get(opts, :timeout, 2000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_collect(session_id, [], deadline)
  end

  defp do_collect(session_id, acc, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    receive do
      {:transcript_entry, %TranscriptEntry{} = entry} ->
        new_acc = acc ++ [entry]

        terminal =
          entry.kind == :system and
            entry.content[:event] in ["completed", "cancelled", "error", "session_expired"]

        if terminal do
          new_acc
        else
          do_collect(session_id, new_acc, deadline)
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
