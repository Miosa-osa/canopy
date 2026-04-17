defmodule Canopy.Runtimes.CodexLocal.ParserTest do
  @moduledoc """
  Unit tests for `Canopy.Runtimes.CodexLocal.Parser`.

  Each event type that Codex's JSONL stream can produce is tested against
  the expected `TranscriptEntry` shape. Malformed JSON and blank-line
  handling are also verified.

  Tests are async because the Parser module is pure (no process state).
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.CodexLocal.Parser

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp json(map), do: Jason.encode!(map)

  # ---------------------------------------------------------------------------
  # Blank / empty lines
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — blank input" do
    test "empty string returns []" do
      assert Parser.parse_line("") == []
    end

    test "whitespace-only returns []" do
      assert Parser.parse_line("   \t  ") == []
    end

    test "bare newline returns []" do
      assert Parser.parse_line("\n") == []
    end
  end

  # ---------------------------------------------------------------------------
  # Malformed JSON
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — malformed JSON" do
    test "returns [] without crashing on invalid JSON" do
      assert Parser.parse_line("{not valid json}") == []
    end

    test "returns [] on truncated JSON" do
      assert Parser.parse_line(~s|{"type":"thread.started"|) == []
    end

    test "returns [] on plain text" do
      assert Parser.parse_line("some random log line") == []
    end
  end

  # ---------------------------------------------------------------------------
  # thread.started → :init
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — thread.started" do
    test "produces a single :init entry" do
      line = json(%{"type" => "thread.started", "thread_id" => "thread_abc123"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :init
      assert entry.content.session_id == "thread_abc123"
    end

    test "init entry has emitted_at set" do
      line = json(%{"type" => "thread.started", "thread_id" => "t1"})
      [entry] = Parser.parse_line(line)
      assert %DateTime{} = entry.emitted_at
    end

    test "model is nil (Codex does not emit model in thread.started)" do
      line = json(%{"type" => "thread.started", "thread_id" => "t2"})
      [entry] = Parser.parse_line(line)
      assert entry.content.model == nil
    end
  end

  # ---------------------------------------------------------------------------
  # item.completed — agent_message → :assistant
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — item.completed agent_message" do
    test "produces :assistant entry" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "agent_message", "text" => "Hello from Codex."}
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Hello from Codex."
    end

    test "empty agent_message returns []" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "agent_message", "text" => ""}
        })

      assert Parser.parse_line(line) == []
    end

    test "missing text returns []" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "agent_message"}
        })

      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # item.completed — reasoning → :thinking
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — item.completed reasoning" do
    test "produces :thinking entry" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "reasoning", "text" => "I am thinking deeply."}
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :thinking
      assert entry.content.text == "I am thinking deeply."
    end

    test "empty reasoning returns []" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "reasoning", "text" => ""}
        })

      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # item.completed — function_call → :tool_call
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — item.completed function_call" do
    test "produces :tool_call entry with decoded JSON arguments" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{
            "type" => "function_call",
            "call_id" => "call-001",
            "name" => "bash",
            "arguments" => Jason.encode!(%{"command" => "ls -la"})
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_call
      assert entry.content.name == "bash"
      assert entry.content.input == %{"command" => "ls -la"}
      assert entry.tool_call_id == "call-001"
    end

    test "tool_call with map input (not string)" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{
            "type" => "function_call",
            "call_id" => "call-002",
            "name" => "read_file",
            "input" => %{"path" => "/tmp/foo.txt"}
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_call
      assert entry.content.input == %{"path" => "/tmp/foo.txt"}
    end

    test "tool_call_id propagated from call_id" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{
            "type" => "function_call",
            "call_id" => "my-call-id",
            "name" => "write",
            "arguments" => "{}"
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.tool_call_id == "my-call-id"
    end
  end

  # ---------------------------------------------------------------------------
  # item.completed — function_call_output → :tool_result
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — item.completed function_call_output" do
    test "produces :tool_result entry" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{
            "type" => "function_call_output",
            "call_id" => "call-001",
            "name" => "bash",
            "output" => "hello\n",
            "is_error" => false
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_result
      assert entry.content.content == "hello\n"
      assert entry.content.is_error == false
      assert entry.tool_call_id == "call-001"
    end

    test "marks error results" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{
            "type" => "function_call_output",
            "call_id" => "call-002",
            "output" => "Permission denied",
            "is_error" => true
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.is_error == true
    end
  end

  # ---------------------------------------------------------------------------
  # item.completed — unknown subtype → []
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — item.completed unknown subtype" do
    test "unknown item type returns []" do
      line =
        json(%{
          "type" => "item.completed",
          "item" => %{"type" => "future_item_type", "data" => "ignored"}
        })

      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # turn.completed → :result
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — turn.completed" do
    test "produces :result entry with usage" do
      line =
        json(%{
          "type" => "turn.completed",
          "usage" => %{
            "input_tokens" => 55,
            "cached_input_tokens" => 10,
            "output_tokens" => 23
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :result
      assert entry.content.input_tokens == 55
      assert entry.content.output_tokens == 23
      assert entry.content.cache_read_tokens == 10
      assert entry.content.is_error == false
      assert entry.content.cost_usd == 0.0
    end

    test "missing usage defaults to zeros" do
      line = json(%{"type" => "turn.completed"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :result
      assert entry.content.input_tokens == 0
      assert entry.content.output_tokens == 0
    end
  end

  # ---------------------------------------------------------------------------
  # turn.failed → :system error
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — turn.failed" do
    test "produces :system error entry" do
      line =
        json(%{
          "type" => "turn.failed",
          "error" => %{"message" => "resume failed"}
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.event == "error"
      assert entry.content.message == "resume failed"
    end

    test "falls back to top-level message when error map is missing" do
      line = json(%{"type" => "turn.failed", "message" => "generic failure"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.message == "generic failure"
    end

    test "uses default message when no message present" do
      line = json(%{"type" => "turn.failed"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert is_binary(entry.content.message)
    end
  end

  # ---------------------------------------------------------------------------
  # error event → :system error
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — error" do
    test "produces :system entry with event error" do
      line = json(%{"type" => "error", "message" => "internal failure"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.event == "error"
      assert entry.content.message == "internal failure"
    end

    test "falls back to error field when message is absent" do
      line = json(%{"type" => "error", "error" => "network timeout"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.message == "network timeout"
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown event types → []
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — unknown types" do
    test "unknown type returns []" do
      line = json(%{"type" => "future_event_type", "data" => "ignored"})
      assert Parser.parse_line(line) == []
    end

    test "type-less event returns []" do
      line = json(%{"data" => "no type key"})
      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # parse_stream/1
  # ---------------------------------------------------------------------------

  describe "parse_stream/1" do
    test "parses a complete fake-codex stream" do
      fake_codex =
        Path.expand(Path.join([__DIR__, "..", "..", "..", "support", "fake_codex.sh"]))

      {stdout, 0} = System.cmd(fake_codex, ["exec", "--json", "-"])

      entries = Parser.parse_stream(stdout)
      kinds = Enum.map(entries, & &1.kind)

      assert :init in kinds
      assert :thinking in kinds
      assert :assistant in kinds
      assert :tool_call in kinds
      assert :tool_result in kinds
      assert :result in kinds
    end

    test "handles CRLF line endings" do
      crlf_stream =
        Enum.join(
          [
            ~s|{"type":"thread.started","thread_id":"t1"}|,
            ~s|{"type":"turn.completed","usage":{"input_tokens":1,"cached_input_tokens":0,"output_tokens":1}}|
          ],
          "\r\n"
        )

      entries = Parser.parse_stream(crlf_stream)
      assert length(entries) == 2
    end

    test "skips malformed lines without crashing" do
      stream =
        Enum.join(
          [
            ~s|{"type":"thread.started","thread_id":"t1"}|,
            "this is not json",
            ~s|{"type":"turn.completed","usage":{}}|
          ],
          "\n"
        )

      entries = Parser.parse_stream(stream)
      # 2 valid events, 1 malformed skipped
      assert length(entries) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # extract_session_id/1
  # ---------------------------------------------------------------------------

  describe "extract_session_id/1" do
    test "returns the thread_id from thread.started" do
      stdout =
        Enum.join(
          [
            ~s|{"type":"thread.started","thread_id":"thread_123"}|,
            ~s|{"type":"turn.completed","usage":{}}|
          ],
          "\n"
        )

      assert Parser.extract_session_id(stdout) == "thread_123"
    end

    test "returns nil when no thread.started event present" do
      assert Parser.extract_session_id("no json here") == nil
    end

    test "returns nil for empty string" do
      assert Parser.extract_session_id("") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # extract_result_metrics/1
  # ---------------------------------------------------------------------------

  describe "extract_result_metrics/1" do
    test "returns token counts from turn.completed event" do
      stdout =
        json(%{
          "type" => "turn.completed",
          "usage" => %{
            "input_tokens" => 100,
            "cached_input_tokens" => 20,
            "output_tokens" => 50
          }
        })

      metrics = Parser.extract_result_metrics(stdout)
      assert metrics.input_tokens == 100
      assert metrics.output_tokens == 50
      assert metrics.cache_read_tokens == 20
    end

    test "returns nil when no result event present" do
      assert Parser.extract_result_metrics("") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # unknown_session_error?/2
  # ---------------------------------------------------------------------------

  describe "unknown_session_error?/2" do
    test "detects no rollout found for thread id" do
      stderr =
        "Error: thread/resume: thread/resume failed: no rollout found for thread id d448e715"

      assert Parser.unknown_session_error?("", stderr) == true
    end

    test "detects unknown thread in stdout" do
      assert Parser.unknown_session_error?("unknown thread id", "") == true
    end

    test "detects state db missing rollout path" do
      assert Parser.unknown_session_error?("", "state db missing rollout path for thread abc") ==
               true
    end

    test "does not classify unrelated failures as stale session" do
      assert Parser.unknown_session_error?("", "model overloaded") == false
    end

    test "returns false for empty strings" do
      assert Parser.unknown_session_error?("", "") == false
    end
  end
end
