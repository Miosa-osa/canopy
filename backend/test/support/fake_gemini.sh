#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# fake_gemini.sh — test fixture that emits Gemini stream-json (JSONL) on stdout
#
# The Gemini CLI receives prompts via --prompt (not stdin), so this script
# ignores all arguments and emits a canned JSONL sequence that exercises every
# event type handled by GeminiLocal.Parser.
#
# Exit code: 0 unless FAKE_GEMINI_EXIT_CODE is set.
#
# Usage (from ExUnit test):
#   System.cmd(fake_gemini_path, ["--output-format", "stream-json", "--prompt", "hello"])
#   Port.open({:spawn_executable, fake_gemini_path}, [...])
#
# Session ID: "fake-gemini-session-001" — tests assert on the parsed result.
#
# Events emitted (in order):
#   1. assistant   — text delta
#   2. assistant   — thinking block
#   3. assistant   — function_call (tool use)
#   4. tool_result — function call result
#   5. assistant   — final text
#   6. result      — success with usage and cost
# ---------------------------------------------------------------------------

# Gemini does not read stdin — no drain needed.

SESSION="fake-gemini-session-001"

# 1. Text delta
printf '{"type":"assistant","session_id":"%s","message":{"content":[{"type":"text","text":"Hello from fake Gemini. I will help you."}]}}\n' "$SESSION"

# 2. Thinking block (Gemini 2.5 extended thinking)
printf '{"type":"assistant","session_id":"%s","message":{"content":[{"type":"thinking","thinking":"Let me think about the best approach to solve this."}]}}\n' "$SESSION"

# 3. Function call (tool use)
printf '{"type":"assistant","session_id":"%s","message":{"content":[{"type":"function_call","id":"fc-001","name":"run_shell_command","args":{"command":"echo hello"}}]}}\n' "$SESSION"

# 4. Tool result (function response)
printf '{"type":"tool_result","session_id":"%s","id":"fc-001","call_id":"fc-001","tool_name":"run_shell_command","is_error":false,"content":"hello\\n"}\n' "$SESSION"

# 5. Final text
printf '{"type":"assistant","session_id":"%s","message":{"content":[{"type":"text","text":"Task complete. I executed the command successfully."}]}}\n' "$SESSION"

# 6. Result event with usage and cost
printf '{"type":"result","session_id":"%s","subtype":"success","result":"Task complete.","usage":{"input_tokens":55,"output_tokens":23,"cached_input_tokens":0},"total_cost_usd":0.000189}\n' "$SESSION"

exit "${FAKE_GEMINI_EXIT_CODE:-0}"
