#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# fake_codex.sh — test fixture that emits Codex JSONL stream on stdout
#
# Reads stdin (the prompt written by the Runner), ignores content, then
# emits a canned sequence of Codex JSONL events ending with a turn.completed.
# The exit code is 0 unless the env var FAKE_CODEX_EXIT_CODE is set.
#
# Usage (from ExUnit test):
#   System.cmd(fake_codex_path, ["exec", "--json", "-"])
#   Port.open({:spawn_executable, fake_codex_path}, [...])
#
# The fixture accepts `exec --json [--model <m>] [resume <id>] -` arguments
# without error; all flags are silently ignored.
#
# Emitted events mirror the real Codex CLI `--json` JSONL format:
#   thread.started    → session init (thread_id = "fake-thread-id-001")
#   item.completed    → agent_message, reasoning, function_call, function_call_output
#   turn.completed    → end of turn with usage stats
#
# The thread_id "fake-thread-id-001" lets tests assert on the parsed session ID.
# Usage numbers (input_tokens: 55, cached_input_tokens: 10, output_tokens: 23)
# are stable so tests can make exact assertions.
#
# NOTE: The function_call arguments field uses a pre-encoded JSON string.
# The single-quoted heredoc avoids shell interpolation issues with nested quotes.
# ---------------------------------------------------------------------------

# Drain stdin so the Port doesn't block waiting for EOF
read_stdin() {
  while IFS= read -r -t 0.05; do :; done 2>/dev/null || true
}

read_stdin

# Emit Codex JSONL events one per line
printf '%s\n' '{"type":"thread.started","thread_id":"fake-thread-id-001"}'
printf '%s\n' '{"type":"item.completed","item":{"type":"reasoning","text":"I am analyzing the task carefully."}}'
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"Hello from fake Codex. I am ready to help."}}'
printf '%s\n' '{"type":"item.completed","item":{"type":"function_call","call_id":"call-001","name":"bash","arguments":"{\"command\":\"echo hello\"}"}}'
printf '%s\n' '{"type":"item.completed","item":{"type":"function_call_output","call_id":"call-001","name":"bash","output":"hello\\n","is_error":false}}'
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"Task complete. The command ran successfully."}}'
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":55,"cached_input_tokens":10,"output_tokens":23}}'

exit "${FAKE_CODEX_EXIT_CODE:-0}"
