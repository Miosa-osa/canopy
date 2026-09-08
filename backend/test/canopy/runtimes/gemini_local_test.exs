defmodule Canopy.Runtimes.GeminiLocalTest do
  @moduledoc """
  Integration and unit tests for `Canopy.Runtimes.GeminiLocal`.

  Uses the fake_gemini.sh fixture for end-to-end execution tests.
  Binary-resolution and environment-check tests control the binary path
  directly without needing Mox.

  These tests are NOT async because:
  - The execute/1 tests spawn real processes via Port
  - PubSub assertions depend on subscription order

  Parser unit tests live in their own async module (parser_test.exs).
  """

  # execute/1 builds its environment from Vault, which reads the Repo.
  # Own a sandbox connection instead of borrowing another test's shared owner.
  use Canopy.DataCase, async: false

  alias Canopy.Runtimes.GeminiLocal
  alias Canopy.Runtimes.GeminiLocal.Runner
  alias Canopy.Runtimes.TranscriptEntry

  @fake_gemini Path.expand(Path.join([__DIR__, "..", "..", "support", "fake_gemini.sh"]))

  # ---------------------------------------------------------------------------
  # Identity callbacks
  # ---------------------------------------------------------------------------

  describe "type/0" do
    test "returns gemini-local" do
      assert GeminiLocal.type() == "gemini-local"
    end
  end

  describe "capabilities/0" do
    test "returns a MapSet" do
      assert %MapSet{} = GeminiLocal.capabilities()
    end

    test "includes model_detection" do
      assert MapSet.member?(GeminiLocal.capabilities(), :model_detection)
    end

    test "includes config_schema" do
      assert MapSet.member?(GeminiLocal.capabilities(), :config_schema)
    end

    test "does not include skill_injection" do
      refute MapSet.member?(GeminiLocal.capabilities(), :skill_injection)
    end

    test "does not include session_resume (not yet wired)" do
      refute MapSet.member?(GeminiLocal.capabilities(), :session_resume)
    end
  end

  # ---------------------------------------------------------------------------
  # list_models/0
  # ---------------------------------------------------------------------------

  describe "list_models/0" do
    test "returns {:ok, models} with at least 5 models" do
      assert {:ok, models} = GeminiLocal.list_models()
      assert Enum.count(models) >= 5
    end

    test "each model has id, label, context_window" do
      {:ok, models} = GeminiLocal.list_models()

      for model <- models do
        assert is_binary(model.id)
        assert is_binary(model.label)
        # auto model has a context window too
        assert is_integer(model.context_window)
      end
    end

    test "includes auto model" do
      {:ok, models} = GeminiLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "auto" in ids
    end

    test "includes gemini-2.5-pro" do
      {:ok, models} = GeminiLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "gemini-2.5-pro" in ids
    end

    test "includes gemini-2.5-flash" do
      {:ok, models} = GeminiLocal.list_models()
      ids = Enum.map(models, & &1.id)
      assert "gemini-2.5-flash" in ids
    end
  end

  # ---------------------------------------------------------------------------
  # get_config_schema/0
  # ---------------------------------------------------------------------------

  describe "get_config_schema/0" do
    test "returns {:ok, fields}" do
      assert {:ok, fields} = GeminiLocal.get_config_schema()
      assert is_list(fields)
      refute Enum.empty?(fields)
    end

    test "each field has key, label, type, required" do
      {:ok, fields} = GeminiLocal.get_config_schema()

      for field <- fields do
        assert is_binary(field.key)
        assert is_binary(field.label)
        assert field.type in [:text, :select, :toggle, :number, :combobox]
        assert is_boolean(field.required)
      end
    end

    test "includes command field" do
      {:ok, fields} = GeminiLocal.get_config_schema()
      keys = Enum.map(fields, & &1.key)
      assert "command" in keys
    end

    test "includes model field with select type" do
      {:ok, fields} = GeminiLocal.get_config_schema()
      model_field = Enum.find(fields, &(&1.key == "model"))
      assert model_field != nil
      assert model_field.type == :select
      assert is_list(model_field.options)
      assert "auto" in model_field.options
    end

    test "includes api_key field" do
      {:ok, fields} = GeminiLocal.get_config_schema()
      keys = Enum.map(fields, & &1.key)
      assert "api_key" in keys
    end

    test "includes sandbox toggle" do
      {:ok, fields} = GeminiLocal.get_config_schema()
      sandbox = Enum.find(fields, &(&1.key == "sandbox"))
      assert sandbox != nil
      assert sandbox.type == :toggle
    end
  end

  # ---------------------------------------------------------------------------
  # get_quota_windows/0
  # ---------------------------------------------------------------------------

  describe "get_quota_windows/0" do
    test "returns {:error, :not_supported}" do
      assert GeminiLocal.get_quota_windows() == {:error, :not_supported}
    end
  end

  # ---------------------------------------------------------------------------
  # test_environment/1 — path traversal guard
  # ---------------------------------------------------------------------------

  describe "test_environment/1 — path traversal" do
    test "rejects binary paths with .." do
      context = %{"command" => "/usr/local/../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = GeminiLocal.test_environment(context)
    end

    test "rejects relative traversal" do
      context = %{"command" => "../../bin/evil"}
      assert {:error, {:binary_path_not_allowed, _path}} = GeminiLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — binary not found" do
    test "returns {:error, :not_installed} when binary does not exist" do
      context = %{"command" => "/nonexistent/binary/gemini"}
      assert {:error, :not_installed} = GeminiLocal.test_environment(context)
    end
  end

  describe "test_environment/1 — valid binary" do
    test "returns {:ok, checks} for fake_gemini" do
      assert {:ok, checks} = GeminiLocal.test_environment(%{"command" => @fake_gemini})
      assert is_list(checks)
      assert checks != []
    end

    test "checks are at info level for a working binary" do
      {:ok, checks} = GeminiLocal.test_environment(%{"command" => @fake_gemini})
      levels = Enum.map(checks, & &1.level)
      assert Enum.all?(levels, &(&1 in [:info, :warn]))
    end

    test "includes binary path in first check message" do
      {:ok, checks} = GeminiLocal.test_environment(%{"command" => @fake_gemini})
      first = List.first(checks)
      assert String.contains?(first.message, @fake_gemini)
    end
  end

  # ---------------------------------------------------------------------------
  # detect_model/0
  # ---------------------------------------------------------------------------

  describe "detect_model/0" do
    test "returns {:error, :not_detected} when no gemini settings file" do
      tmp = System.tmp_dir!()
      old_home = System.get_env("HOME")
      System.put_env("HOME", tmp)

      try do
        assert {:error, :not_detected} = GeminiLocal.detect_model()
      after
        if old_home, do: System.put_env("HOME", old_home)
      end
    end

    test "returns {:ok, model_info} when settings.json exists at XDG path" do
      tmp = System.tmp_dir!()
      unique = "gemini_test_#{System.unique_integer()}"
      fake_home = Path.join(tmp, unique)
      settings_dir = Path.join([fake_home, ".config", "gemini"])
      File.mkdir_p!(settings_dir)
      settings_path = Path.join(settings_dir, "settings.json")
      File.write!(settings_path, Jason.encode!(%{"model" => "gemini-2.5-flash"}))

      old_home = System.get_env("HOME")
      System.put_env("HOME", fake_home)

      try do
        assert {:ok, info} = GeminiLocal.detect_model()
        assert info.model == "gemini-2.5-flash"
        assert info.provider == "google"
        assert is_binary(info.source)
      after
        File.rm_rf!(fake_home)
        if old_home, do: System.put_env("HOME", old_home)
      end
    end

    test "returns {:ok, model_info} from legacy ~/.gemini/settings.json" do
      tmp = System.tmp_dir!()
      unique = "gemini_legacy_#{System.unique_integer()}"
      fake_home = Path.join(tmp, unique)
      settings_dir = Path.join(fake_home, ".gemini")
      File.mkdir_p!(settings_dir)
      settings_path = Path.join(settings_dir, "settings.json")
      File.write!(settings_path, Jason.encode!(%{"model" => "gemini-2.5-pro"}))

      old_home = System.get_env("HOME")
      System.put_env("HOME", fake_home)

      try do
        assert {:ok, info} = GeminiLocal.detect_model()
        assert info.model == "gemini-2.5-pro"
      after
        File.rm_rf!(fake_home)
        if old_home, do: System.put_env("HOME", old_home)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # list_skills/1 and sync_skills/2
  # ---------------------------------------------------------------------------

  describe "list_skills/1" do
    test "returns {:error, :not_implemented}" do
      assert GeminiLocal.list_skills(%{}) == {:error, :not_implemented}
    end
  end

  describe "sync_skills/2" do
    test "returns {:error, :not_implemented}" do
      assert GeminiLocal.sync_skills(%{}, []) == {:error, :not_implemented}
    end
  end

  # ---------------------------------------------------------------------------
  # execute/1 — end-to-end with fake_gemini
  # ---------------------------------------------------------------------------

  describe "execute/1 — subprocess execution" do
    setup do
      session_id = "test-gemini-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id, topic: topic}
    end

    test "returns {:ok, session_ref} with pid and session_id", %{session_id: session_id} do
      context = build_context(session_id)

      assert {:ok, session_ref} = GeminiLocal.execute(context)
      assert is_pid(session_ref.pid)
      assert session_ref.session_id == session_id
      assert is_binary(session_ref.cwd)

      wait_for_completion(session_id)
    end

    test "broadcasts TranscriptEntry messages via PubSub", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :assistant in kinds
    end

    test "emits a completed system entry on success", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      completed = Enum.find(system_entries, &(&1.content[:event] == "completed"))
      assert completed != nil
    end

    test "entries have monotonically increasing sequence numbers", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      sequences = Enum.map(entries, & &1.sequence) |> Enum.reject(&is_nil/1)

      assert sequences == Enum.sort(sequences)
      assert Enum.uniq(sequences) == sequences
    end

    test "emits :result kind with token data", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      result_entry = Enum.find(entries, &(&1.kind == :result))

      assert result_entry != nil
      assert result_entry.content.input_tokens == 55
      assert result_entry.content.output_tokens == 23
      assert_in_delta result_entry.content.cost_usd, 0.000189, 0.0000001
    end

    test "emits :thinking kind from stream", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :thinking in kinds
    end

    test "emits :tool_call and :tool_result kinds", %{session_id: session_id} do
      context = build_context(session_id)
      {:ok, _ref} = GeminiLocal.execute(context)

      entries = collect_entries(session_id, timeout: 3000)
      kinds = Enum.map(entries, & &1.kind)

      assert :tool_call in kinds
      assert :tool_result in kinds
    end
  end

  describe "execute/1 — cancel" do
    setup do
      session_id = "test-gemini-cancel-#{System.unique_integer([:positive])}"
      topic = "session:#{session_id}"
      :ok = Phoenix.PubSub.subscribe(Canopy.PubSub, topic)
      {:ok, session_id: session_id}
    end

    test "cancel/1 is accepted without crashing", %{session_id: session_id} do
      # Exercise the actual credential lookup on the subprocess path.
      assert {:ok, _} = Canopy.Vault.put("gemini-local", "api_key", "fake-test-credential")
      context = build_context(session_id)
      {:ok, session_ref} = GeminiLocal.execute(context)

      Process.sleep(50)
      Runner.cancel(session_ref.pid)

      entries = collect_entries(session_id, timeout: 2000)
      system_entries = Enum.filter(entries, &(&1.kind == :system))

      assert Enum.any?(system_entries, fn e ->
               e.content[:event] in ["completed", "cancelled"]
             end)
    end
  end

  describe "execute/1 — path traversal guard" do
    test "returns {:error, {:binary_path_not_allowed, _}} for traversal path" do
      context = %{
        "session_id" => "test-traversal",
        "command" => "/usr/local/../bin/gemini",
        "cwd" => System.tmp_dir!(),
        "prompt" => "hello"
      }

      assert {:error, {:binary_path_not_allowed, _path}} = GeminiLocal.execute(context)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp build_context(session_id) do
    %{
      "session_id" => session_id,
      "command" => @fake_gemini,
      "cwd" => System.tmp_dir!(),
      "prompt" => "Hello fake Gemini"
    }
  end

  defp collect_entries(_session_id, opts) do
    timeout = Keyword.get(opts, :timeout, 2000)
    deadline = System.monotonic_time(:millisecond) + timeout
    do_collect([], deadline)
  end

  defp do_collect(acc, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    receive do
      {:transcript_entry, %TranscriptEntry{} = entry} ->
        new_acc = acc ++ [entry]

        terminal =
          entry.kind == :system and entry.content[:event] in ["completed", "cancelled", "error"]

        if terminal, do: new_acc, else: do_collect(new_acc, deadline)
    after
      max(0, remaining) -> acc
    end
  end

  defp wait_for_completion(session_id) do
    collect_entries(session_id, timeout: 3000)
    :ok
  end
end
