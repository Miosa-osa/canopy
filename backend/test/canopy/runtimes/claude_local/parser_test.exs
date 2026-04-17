defmodule Canopy.Runtimes.ClaudeLocal.ParserTest do
  @moduledoc """
  Unit tests for `Canopy.Runtimes.ClaudeLocal.Parser`.

  Each event type that Claude's stream-json can produce is tested against
  the expected `TranscriptEntry` shape. Malformed JSON and partial-line
  handling are also verified.

  Tests are async because the Parser module is pure (no process state).
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.ClaudeLocal.Parser

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
      assert Parser.parse_line(~s|{"type":"assistant"|) == []
    end

    test "returns [] on plain text" do
      assert Parser.parse_line("some random log line") == []
    end
  end

  # ---------------------------------------------------------------------------
  # system / init event
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — system init" do
    test "produces a single :init entry" do
      line =
        json(%{
          "type" => "system",
          "subtype" => "init",
          "session_id" => "fake-session-id-001",
          "model" => "claude-sonnet-4-6"
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :init
      assert entry.content.session_id == "fake-session-id-001"
      assert entry.content.model == "claude-sonnet-4-6"
    end

    test "init entry has emitted_at set" do
      line =
        json(%{
          "type" => "system",
          "subtype" => "init",
          "session_id" => "s1",
          "model" => "claude-haiku-4-5"
        })

      [entry] = Parser.parse_line(line)
      assert %DateTime{} = entry.emitted_at
    end
  end

  # ---------------------------------------------------------------------------
  # assistant text blocks
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — assistant text" do
    test "produces :assistant entry for text block" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "text", "text" => "Hello from Claude."}]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Hello from Claude."
    end

    test "empty text block produces []" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "text", "text" => ""}]
          }
        })

      assert Parser.parse_line(line) == []
    end

    test "multiple text blocks produce multiple entries" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{"type" => "text", "text" => "First paragraph."},
              %{"type" => "text", "text" => "Second paragraph."}
            ]
          }
        })

      entries = Parser.parse_line(line)
      assert length(entries) == 2
      assert Enum.at(entries, 0).content.text == "First paragraph."
      assert Enum.at(entries, 1).content.text == "Second paragraph."
    end
  end

  # ---------------------------------------------------------------------------
  # thinking blocks
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — thinking" do
    test "produces :thinking entry for thinking block" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "thinking", "thinking" => "I am reasoning..."}]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :thinking
      assert entry.content.text == "I am reasoning..."
    end
  end

  # ---------------------------------------------------------------------------
  # tool_use (tool_call) blocks
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — tool_use" do
    test "produces :tool_call entry with correct fields" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{
                "type" => "tool_use",
                "id" => "tool-call-001",
                "name" => "Bash",
                "input" => %{"command" => "ls -la"}
              }
            ]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_call
      assert entry.content.name == "Bash"
      assert entry.content.input == %{"command" => "ls -la"}
      assert entry.tool_call_id == "tool-call-001"
    end

    test "tool_call_id propagated from tool_use id" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{"type" => "tool_use", "id" => "my-id", "name" => "Read", "input" => %{}}
            ]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.tool_call_id == "my-id"
    end
  end

  # ---------------------------------------------------------------------------
  # tool_result
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — tool_result" do
    test "produces :tool_result entry" do
      line =
        json(%{
          "type" => "tool_result",
          "tool_use_id" => "tool-call-001",
          "tool_name" => "Bash",
          "is_error" => false,
          "content" => "hello\n"
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_result
      assert entry.content.tool_name == "Bash"
      assert entry.content.content == "hello\n"
      assert entry.content.is_error == false
      assert entry.tool_call_id == "tool-call-001"
    end

    test "marks error results" do
      line =
        json(%{
          "type" => "tool_result",
          "tool_use_id" => "t2",
          "tool_name" => "Write",
          "is_error" => true,
          "content" => "Permission denied"
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_result
      assert entry.content.is_error == true
    end

    test "handles list content in tool_result" do
      line =
        json(%{
          "type" => "tool_result",
          "tool_use_id" => "t3",
          "is_error" => false,
          "content" => [%{"type" => "text", "text" => "result text"}]
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_result
      assert entry.content.content == "result text"
    end
  end

  # ---------------------------------------------------------------------------
  # result event
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — result" do
    test "produces :result entry with usage and cost" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "success",
          "result" => "Task complete.",
          "usage" => %{
            "input_tokens" => 42,
            "output_tokens" => 17,
            "cache_read_input_tokens" => 5,
            "cache_creation_input_tokens" => 0
          },
          "total_cost_usd" => 0.000234
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :result
      assert entry.content.text == "Task complete."
      assert entry.content.input_tokens == 42
      assert entry.content.output_tokens == 17
      assert entry.content.cache_read_tokens == 5
      assert_in_delta entry.content.cost_usd, 0.000234, 0.0000001
      assert entry.content.is_error == false
    end

    test "marks error subtypes as is_error: true" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "error",
          "result" => "Something went wrong.",
          "usage" => %{},
          "total_cost_usd" => 0.0
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.is_error == true
    end

    test "result event includes errors list" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "error",
          "result" => "",
          "errors" => [%{"message" => "rate limit exceeded"}],
          "usage" => %{},
          "total_cost_usd" => 0.0
        })

      [entry] = Parser.parse_line(line)
      assert "rate limit exceeded" in entry.content.errors
    end
  end

  # ---------------------------------------------------------------------------
  # error event
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — error" do
    test "produces :system entry with event error" do
      line = json(%{"type" => "error", "message" => "internal failure"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.event == "error"
      assert entry.content.message == "internal failure"
    end
  end

  # ---------------------------------------------------------------------------
  # Unknown event types
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — unknown types" do
    test "unknown type returns []" do
      line = json(%{"type" => "future_event_type", "data" => "ignored"})
      assert Parser.parse_line(line) == []
    end

    test "system event without subtype init returns []" do
      line = json(%{"type" => "system", "subtype" => "heartbeat"})
      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # parse_stream/1
  # ---------------------------------------------------------------------------

  describe "parse_stream/1" do
    test "parses a complete fake-claude stream" do
      fake_claude =
        Path.expand(Path.join([__DIR__, "..", "..", "..", "support", "fake_claude.sh"]))

      {stdout, 0} = System.cmd(fake_claude, ["--print", "-", "--output-format", "stream-json"])

      entries = Parser.parse_stream(stdout)

      kinds = Enum.map(entries, & &1.kind)
      assert :init in kinds
      assert :assistant in kinds
      assert :thinking in kinds
      assert :tool_call in kinds
      assert :tool_result in kinds
      assert :result in kinds
    end

    test "handles CRLF line endings" do
      crlf_stream =
        Enum.join(
          [
            ~s|{"type":"system","subtype":"init","session_id":"s1","model":"claude-sonnet-4-6"}|,
            ~s|{"type":"result","session_id":"s1","subtype":"success","result":"done","usage":{},"total_cost_usd":0.0}|
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
            ~s|{"type":"system","subtype":"init","session_id":"s1","model":"m"}|,
            "this is not json",
            ~s|{"type":"result","session_id":"s1","subtype":"success","result":"ok","usage":{},"total_cost_usd":0.0}|
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
    test "returns the last session_id seen" do
      stdout =
        Enum.join(
          [
            ~s|{"type":"system","subtype":"init","session_id":"first-session","model":"m"}|,
            ~s|{"type":"result","session_id":"final-session","subtype":"success","result":"","usage":{},"total_cost_usd":0.0}|
          ],
          "\n"
        )

      assert Parser.extract_session_id(stdout) == "final-session"
    end

    test "returns nil when no session_id present" do
      assert Parser.extract_session_id("no json here") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # extract_result_metrics/1
  # ---------------------------------------------------------------------------

  describe "extract_result_metrics/1" do
    test "returns cost and token counts from result event" do
      stdout =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "success",
          "result" => "done",
          "usage" => %{
            "input_tokens" => 100,
            "output_tokens" => 50,
            "cache_read_input_tokens" => 10,
            "cache_creation_input_tokens" => 0
          },
          "total_cost_usd" => 0.005
        })

      metrics = Parser.extract_result_metrics(stdout)
      assert metrics.input_tokens == 100
      assert metrics.output_tokens == 50
      assert metrics.cache_read_tokens == 10
      assert_in_delta metrics.cost_usd, 0.005, 0.0000001
    end

    test "returns nil when no result event present" do
      assert Parser.extract_result_metrics("") == nil
    end
  end
end
