#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# fake_claude.sh — test fixture that emits Claude stream-json on stdout
#
# Reads stdin (the prompt written by the Runner), ignores content, then
# emits a canned sequence of stream-json lines ending with a result event.
# The exit code is 0 unless the env var FAKE_CLAUDE_EXIT_CODE is set.
#
# Usage (from ExUnit test):
#   System.cmd(fake_claude_path, ["--print", "-", "--output-format", "stream-json", ...])
#   Port.open({:spawn_executable, fake_claude_path}, [...])
#
# This binary participates in the triple-key resume flow by accepting
# --resume <id> without error (it ignores the flag).
#
# Lines 1–4 simulate a real Claude stream-json session. The session_id
# is "fake-session-id-001" so tests can assert on the parsed result.
# ---------------------------------------------------------------------------

# Drain stdin so the Port doesn't block
read_stdin() {
  while IFS= read -r -t 0.05; do :; done 2>/dev/null || true
}

read_stdin

# Emit stream-json events one per line
printf '{"type":"system","subtype":"init","session_id":"fake-session-id-001","model":"claude-sonnet-4-6"}\n'
printf '{"type":"assistant","session_id":"fake-session-id-001","message":{"content":[{"type":"text","text":"Hello from fake Claude. I am here to help."}]}}\n'
printf '{"type":"assistant","session_id":"fake-session-id-001","message":{"content":[{"type":"thinking","thinking":"I am thinking deeply."}]}}\n'
printf '{"type":"assistant","session_id":"fake-session-id-001","message":{"content":[{"type":"tool_use","id":"tool-call-001","name":"Bash","input":{"command":"echo hello"}}]}}\n'
printf '{"type":"tool_result","tool_use_id":"tool-call-001","tool_name":"Bash","is_error":false,"content":"hello\\n"}\n'
printf '{"type":"result","session_id":"fake-session-id-001","subtype":"success","result":"Task complete.","usage":{"input_tokens":42,"output_tokens":17,"cache_read_input_tokens":0,"cache_creation_input_tokens":0},"total_cost_usd":0.000234}\n'

exit "${FAKE_CLAUDE_EXIT_CODE:-0}"
