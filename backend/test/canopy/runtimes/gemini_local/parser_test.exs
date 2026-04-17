defmodule Canopy.Runtimes.GeminiLocal.ParserTest do
  @moduledoc """
  Unit tests for `Canopy.Runtimes.GeminiLocal.Parser`.

  Each event type that Gemini's stream-json can produce is tested against
  the expected `TranscriptEntry` shape. Malformed JSON and partial-line
  handling are also verified.

  Tests are async because the Parser module is pure (no process state).
  """

  use ExUnit.Case, async: true

  alias Canopy.Runtimes.GeminiLocal.Parser

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
  # assistant — text content
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — assistant text" do
    test "produces :assistant entry from content block" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "fake-gemini-session-001",
          "message" => %{
            "content" => [%{"type" => "text", "text" => "Hello from Gemini."}]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Hello from Gemini."
    end

    test "produces :assistant entry from output_text content block" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "output_text", "text" => "Output text block."}]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Output text block."
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

    test "multiple text blocks produce multiple :assistant entries" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{"type" => "text", "text" => "First."},
              %{"type" => "text", "text" => "Second."}
            ]
          }
        })

      entries = Parser.parse_line(line)
      assert length(entries) == 2
      assert Enum.at(entries, 0).content.text == "First."
      assert Enum.at(entries, 1).content.text == "Second."
    end

    test "assistant with no content list falls back to flat message text" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{"text" => "Flat text message."}
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Flat text message."
    end
  end

  # ---------------------------------------------------------------------------
  # assistant — thinking blocks
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — thinking" do
    test "produces :thinking entry for thinking block" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "thinking", "thinking" => "I am reasoning deeply."}]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :thinking
      assert entry.content.text == "I am reasoning deeply."
    end

    test "empty thinking block produces []" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [%{"type" => "thinking", "thinking" => "   "}]
          }
        })

      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # assistant — function_call (tool use)
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — function_call" do
    test "produces :tool_call entry with correct fields" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{
                "type" => "function_call",
                "id" => "fc-001",
                "name" => "run_shell_command",
                "args" => %{"command" => "ls -la"}
              }
            ]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_call
      assert entry.content.name == "run_shell_command"
      assert entry.content.input == %{"command" => "ls -la"}
      assert entry.tool_call_id == "fc-001"
    end

    test "function_call using call_id field" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{
                "type" => "function_call",
                "call_id" => "my-call",
                "name" => "Bash",
                "args" => %{}
              }
            ]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.tool_call_id == "my-call"
    end

    test "function_call with input alias for args" do
      line =
        json(%{
          "type" => "assistant",
          "session_id" => "s1",
          "message" => %{
            "content" => [
              %{
                "type" => "function_call",
                "id" => "fc-002",
                "name" => "Write",
                "input" => %{"path" => "/tmp/x"}
              }
            ]
          }
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.input == %{"path" => "/tmp/x"}
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
          "session_id" => "s1",
          "id" => "fc-001",
          "call_id" => "fc-001",
          "tool_name" => "run_shell_command",
          "is_error" => false,
          "content" => "hello\n"
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :tool_result
      assert entry.content.tool_name == "run_shell_command"
      assert entry.content.content == "hello\n"
      assert entry.content.is_error == false
      assert entry.tool_call_id == "fc-001"
    end

    test "marks error results" do
      line =
        json(%{
          "type" => "tool_result",
          "id" => "fc-002",
          "call_id" => "fc-002",
          "is_error" => true,
          "content" => "Permission denied"
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.is_error == true
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
            "input_tokens" => 55,
            "output_tokens" => 23,
            "cached_input_tokens" => 0
          },
          "total_cost_usd" => 0.000189
        })

      [entry] = Parser.parse_line(line)
      assert entry.kind == :result
      assert entry.content.text == "Task complete."
      assert entry.content.input_tokens == 55
      assert entry.content.output_tokens == 23
      assert entry.content.cached_input_tokens == 0
      assert_in_delta entry.content.cost_usd, 0.000189, 0.0000001
      assert entry.content.is_error == false
    end

    test "marks error subtype as is_error: true" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "error",
          "result" => "",
          "usage" => %{},
          "total_cost_usd" => 0.0
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.is_error == true
    end

    test "marks is_error: true flag" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "is_error" => true,
          "result" => "",
          "usage" => %{},
          "total_cost_usd" => 0.0
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.is_error == true
    end

    test "accepts camelCase usageMetadata" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "success",
          "result" => "done",
          "usageMetadata" => %{
            "promptTokenCount" => 100,
            "candidatesTokenCount" => 40,
            "cachedContentTokenCount" => 5
          },
          "total_cost_usd" => 0.001
        })

      [entry] = Parser.parse_line(line)
      assert entry.content.input_tokens == 100
      assert entry.content.output_tokens == 40
      assert entry.content.cached_input_tokens == 5
    end

    test "cost_usd falls back to cost_usd key" do
      line =
        json(%{
          "type" => "result",
          "session_id" => "s1",
          "subtype" => "success",
          "result" => "done",
          "usage" => %{},
          "cost_usd" => 0.003
        })

      [entry] = Parser.parse_line(line)
      assert_in_delta entry.content.cost_usd, 0.003, 0.0000001
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

    test "extracts error from error field" do
      line = json(%{"type" => "error", "error" => "quota exceeded"})
      [entry] = Parser.parse_line(line)
      assert entry.content.message == "quota exceeded"
    end
  end

  # ---------------------------------------------------------------------------
  # system event
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — system" do
    test "system with subtype error produces :system entry" do
      line = json(%{"type" => "system", "subtype" => "error", "message" => "auth failed"})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :system
      assert entry.content.event == "error"
      assert entry.content.message == "auth failed"
    end

    test "system with non-error subtype returns []" do
      line = json(%{"type" => "system", "subtype" => "heartbeat"})
      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # text event (flat prompt response)
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — text event" do
    test "produces :assistant entry from part.text" do
      line = json(%{"type" => "text", "part" => %{"text" => "Flat response text."}})
      [entry] = Parser.parse_line(line)
      assert entry.kind == :assistant
      assert entry.content.text == "Flat response text."
    end

    test "empty part.text returns []" do
      line = json(%{"type" => "text", "part" => %{"text" => ""}})
      assert Parser.parse_line(line) == []
    end
  end

  # ---------------------------------------------------------------------------
  # step_finish — silently ignored
  # ---------------------------------------------------------------------------

  describe "parse_line/1 — step_finish" do
    test "step_finish returns []" do
      line =
        json(%{
          "type" => "step_finish",
          "session_id" => "s1",
          "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
        })

      assert Parser.parse_line(line) == []
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
  end

  # ---------------------------------------------------------------------------
  # parse_stream/1
  # ---------------------------------------------------------------------------

  describe "parse_stream/1" do
    test "parses a complete fake-gemini stream" do
      fake_gemini =
        Path.expand(Path.join([__DIR__, "..", "..", "..", "support", "fake_gemini.sh"]))

      {stdout, 0} =
        System.cmd(fake_gemini, ["--output-format", "stream-json", "--prompt", "hello"])

      entries = Parser.parse_stream(stdout)
      kinds = Enum.map(entries, & &1.kind)

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
            ~s|{"type":"assistant","session_id":"s1","message":{"content":[{"type":"text","text":"Hello"}]}}|,
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
            ~s|{"type":"assistant","session_id":"s1","message":{"content":[{"type":"text","text":"Hi"}]}}|,
            "this is not json",
            ~s|{"type":"result","session_id":"s1","subtype":"success","result":"ok","usage":{},"total_cost_usd":0.0}|
          ],
          "\n"
        )

      entries = Parser.parse_stream(stream)
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
            ~s|{"type":"assistant","session_id":"first","message":{"content":[]}}|,
            ~s|{"type":"result","session_id":"final","subtype":"success","result":"","usage":{},"total_cost_usd":0.0}|
          ],
          "\n"
        )

      assert Parser.extract_session_id(stdout) == "final"
    end

    test "accepts sessionId camelCase" do
      stdout =
        ~s|{"type":"result","sessionId":"camel-case-id","subtype":"success","result":"","usage":{},"total_cost_usd":0.0}|

      assert Parser.extract_session_id(stdout) == "camel-case-id"
    end

    test "accepts checkpoint_id" do
      stdout =
        ~s|{"type":"result","checkpoint_id":"checkpoint-001","subtype":"success","result":"","usage":{},"total_cost_usd":0.0}|

      assert Parser.extract_session_id(stdout) == "checkpoint-001"
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
            "input_tokens" => 55,
            "output_tokens" => 23,
            "cached_input_tokens" => 3
          },
          "total_cost_usd" => 0.000189
        })

      metrics = Parser.extract_result_metrics(stdout)
      assert metrics.input_tokens == 55
      assert metrics.output_tokens == 23
      assert metrics.cached_input_tokens == 3
      assert_in_delta metrics.cost_usd, 0.000189, 0.0000001
    end

    test "returns nil when no result event present" do
      assert Parser.extract_result_metrics("") == nil
    end
  end
end
