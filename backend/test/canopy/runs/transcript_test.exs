defmodule Canopy.Runs.TranscriptTest do
  @moduledoc """
  Tests for Runs.transcript/1 — typed block assembly from hook events,
  tool calls, and NDJSON scrollback.
  """

  use Canopy.DataCase, async: true

  import Canopy.Factory

  alias Canopy.Repo
  alias Canopy.Runs
  alias Canopy.Hooks.HookEvent
  alias Canopy.Agents.ToolCall

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # HookEvent uses :utc_datetime_usec — must have microsecond precision
  defp insert_hook(run, event, opts \\ []) do
    now = Keyword.get(opts, :at, DateTime.utc_now())

    %HookEvent{}
    |> HookEvent.changeset(%{
      agent: "claude",
      event: event,
      run_id: run.id,
      payload: Keyword.get(opts, :payload, %{"msg" => event})
    })
    |> Ecto.Changeset.force_change(:inserted_at, now)
    |> Repo.insert!()
  end

  # ToolCall uses :utc_datetime — must be truncated to :second
  defp insert_tool_call(run, tool_name, opts \\ []) do
    now =
      opts
      |> Keyword.get(:at, DateTime.utc_now())
      |> DateTime.truncate(:second)

    %ToolCall{}
    |> ToolCall.changeset(%{
      session_id: Ecto.UUID.generate(),
      run_id: run.id,
      agent_id: Keyword.get(opts, :agent_id, "agent-1"),
      tool_name: tool_name,
      params: Keyword.get(opts, :params, %{}),
      result: Keyword.get(opts, :result, nil),
      error: Keyword.get(opts, :error, nil),
      status: Keyword.get(opts, :status, "ok")
    })
    |> Ecto.Changeset.force_change(:inserted_at, now)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # transcript/1
  # ---------------------------------------------------------------------------

  describe "transcript/1" do
    test "returns empty list for run with no events" do
      run = insert(:run)
      blocks = Runs.transcript(run)
      assert blocks == []
    end

    test "maps UserPromptSubmit hook to :user_prompt block" do
      run = insert(:run)
      insert_hook(run, "UserPromptSubmit", payload: %{"prompt" => "Do the thing"})

      blocks = Runs.transcript(run)
      assert length(blocks) == 1
      assert hd(blocks).kind == :user_prompt
      assert hd(blocks).payload["event"] == "UserPromptSubmit"
    end

    test "maps PermissionRequest hook to :permission_request block" do
      run = insert(:run)
      insert_hook(run, "PermissionRequest")

      [block] = Runs.transcript(run)
      assert block.kind == :permission_request
    end

    test "maps Stop hook to :exit block" do
      run = insert(:run)
      insert_hook(run, "Stop")

      [block] = Runs.transcript(run)
      assert block.kind == :exit
    end

    test "maps PostToolUse hook to :tool_result block" do
      run = insert(:run)
      insert_hook(run, "PostToolUse")

      [block] = Runs.transcript(run)
      assert block.kind == :tool_result
    end

    test "maps PostToolUseFailure hook to :tool_result block" do
      run = insert(:run)
      insert_hook(run, "PostToolUseFailure")

      [block] = Runs.transcript(run)
      assert block.kind == :tool_result
    end

    test "tool call with result emits :tool_call and :tool_result blocks" do
      run = insert(:run)

      insert_tool_call(run, "bash",
        params: %{"command" => "ls"},
        result: %{"output" => "file.txt"},
        status: "ok"
      )

      blocks = Runs.transcript(run)
      assert length(blocks) == 2

      call_block = Enum.find(blocks, &(&1.kind == :tool_call))
      result_block = Enum.find(blocks, &(&1.kind == :tool_result))

      assert call_block.payload["tool_name"] == "bash"
      assert call_block.payload["params"]["command"] == "ls"
      assert result_block.payload["result"]["output"] == "file.txt"
      assert result_block.payload["status"] == "ok"
    end

    test "tool call without result emits only :tool_call block" do
      run = insert(:run)
      insert_tool_call(run, "read_file", result: nil, error: nil)

      blocks = Runs.transcript(run)
      assert length(blocks) == 1
      assert hd(blocks).kind == :tool_call
    end

    test "tool call with error emits both blocks" do
      run = insert(:run)
      insert_tool_call(run, "write_file", error: "permission denied", status: "error")

      blocks = Runs.transcript(run)
      assert length(blocks) == 2
      error_block = Enum.find(blocks, &(&1.kind == :tool_result))
      assert error_block.payload["error"] == "permission denied"
    end

    test "scrollback NDJSON lines become blocks" do
      log_path = Path.join(System.tmp_dir!(), "transcript_test_#{System.unique_integer()}.ndjson")

      lines = [
        Jason.encode!(%{kind: "stdout", data: "hello", at: "2026-01-01T00:00:01Z"}),
        Jason.encode!(%{kind: "thinking", data: "hmm", at: "2026-01-01T00:00:02Z"})
      ]

      File.write!(log_path, Enum.join(lines, "\n"))

      run = insert(:run, log_ref: log_path)
      blocks = Runs.transcript(run)

      assert length(blocks) == 2
      assert Enum.any?(blocks, &(&1.kind == :stdout))
      assert Enum.any?(blocks, &(&1.kind == :thinking))

      File.rm(log_path)
    end

    test "scrollback falls back to :stdout for non-JSON lines" do
      log_path = Path.join(System.tmp_dir!(), "transcript_test_#{System.unique_integer()}.ndjson")
      File.write!(log_path, "plain text line\n")

      run = insert(:run, log_ref: log_path)
      [block] = Runs.transcript(run)

      assert block.kind == :stdout
      assert block.payload["data"] == "plain text line"

      File.rm(log_path)
    end

    test "blocks are sorted by :at timestamp across all sources" do
      run = insert(:run)

      base = DateTime.utc_now()
      # HookEvent needs usec precision; ToolCall needs second precision
      t1 = DateTime.add(base, -20, :second)
      t2 = DateTime.add(base, -10, :second) |> DateTime.truncate(:second)
      t3 = DateTime.add(base, 0, :second)

      insert_hook(run, "UserPromptSubmit", at: t1)
      insert_hook(run, "Stop", at: t3)
      insert_tool_call(run, "bash", at: t2)

      blocks = Runs.transcript(run)
      kinds = Enum.map(blocks, & &1.kind)

      # First block: user_prompt (t1 is earliest)
      assert hd(kinds) == :user_prompt
      # Last block: exit (t3 is latest)
      assert List.last(kinds) == :exit
    end

    test "accepts run_id string instead of Run struct" do
      run = insert(:run)
      insert_hook(run, "Stop")

      blocks = Runs.transcript(run.id)
      assert length(blocks) == 1
      assert hd(blocks).kind == :exit
    end

    test "returns empty list for unknown run_id" do
      blocks = Runs.transcript(Ecto.UUID.generate())
      assert blocks == []
    end

    test "each block has :kind, :payload, and :at keys" do
      run = insert(:run)
      insert_hook(run, "UserPromptSubmit")

      [block] = Runs.transcript(run)
      assert Map.has_key?(block, :kind)
      assert Map.has_key?(block, :payload)
      assert Map.has_key?(block, :at)
      assert is_binary(block.at)
    end
  end
end
