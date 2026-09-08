/**
 * Unit tests for groupTranscript() — transcript grouping engine.
 *
 * Covers: empty input, single entry, command_group formation, degrade rules,
 * tool_group formation, orphan tool_result, order preservation, mixed streams.
 */
import { describe, expect, it } from 'vitest';
import type { TranscriptEntry } from '$lib/domain/sessions/types.js';
import { groupTranscript } from '../transcript-grouping.js';

// ── Helpers ──────────────────────────────────────────────────────────────────

let seq = 0;
function id(): string {
  return `e${++seq}`;
}

function assistant(text = 'hello'): TranscriptEntry {
  return {
    id: id(),
    kind: 'assistant',
    text,
    createdAt: '2024-01-01T00:00:00Z',
  };
}

function thinking(text = '...'): TranscriptEntry {
  return {
    id: id(),
    kind: 'thinking',
    text,
    createdAt: '2024-01-01T00:00:00Z',
  };
}

function shellCall(callId: string, cmd = 'ls'): TranscriptEntry & { kind: 'tool_call' } {
  return {
    id: id(),
    kind: 'tool_call',
    toolName: 'bash',
    args: { command: cmd },
    toolCallId: callId,
    createdAt: '2024-01-01T00:00:00Z',
  };
}

function shellResult(
  callId: string,
  content = 'output',
  isError = false
): TranscriptEntry & { kind: 'tool_result' } {
  return {
    id: id(),
    kind: 'tool_result',
    toolCallId: callId,
    content,
    isError,
    createdAt: '2024-01-01T00:01:00Z',
  };
}

function toolCall(callId: string, toolName = 'read_file'): TranscriptEntry & { kind: 'tool_call' } {
  return {
    id: id(),
    kind: 'tool_call',
    toolName,
    args: { file_path: '/foo.ts' },
    toolCallId: callId,
    createdAt: '2024-01-01T00:00:00Z',
  };
}

function toolResult(
  callId: string,
  content = 'file content',
  isError = false
): TranscriptEntry & { kind: 'tool_result' } {
  return {
    id: id(),
    kind: 'tool_result',
    toolCallId: callId,
    content,
    isError,
    createdAt: '2024-01-01T00:01:00Z',
  };
}

function orphanResult(callId = 'orphan-99'): TranscriptEntry & { kind: 'tool_result' } {
  return {
    id: id(),
    kind: 'tool_result',
    toolCallId: callId,
    content: 'late result',
    isError: false,
    createdAt: '2024-01-01T00:02:00Z',
  };
}

// ── Tests ─────────────────────────────────────────────────────────────────────

describe('groupTranscript()', () => {
  // 1. Empty array
  it('returns empty array for empty input', () => {
    expect(groupTranscript([])).toEqual([]);
  });

  // 2. Single assistant entry
  it('wraps a single assistant entry as single', () => {
    const msg = assistant();
    const result = groupTranscript([msg]);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('single');
    if (result[0].kind === 'single') {
      expect(result[0].entry).toBe(msg);
    }
  });

  // 3. Single shell pair — degrades to singles (below MIN 2 threshold is just 1)
  it('degrades a single shell command pair to two singles', () => {
    const entries: TranscriptEntry[] = [shellCall('c1'), shellResult('c1')];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(2);
    expect(result.every((g) => g.kind === 'single')).toBe(true);
  });

  // 4. Exactly 2 consecutive shell pairs → command_group
  it('groups 2 consecutive shell commands into a command_group', () => {
    const entries: TranscriptEntry[] = [
      shellCall('c1', 'ls'),
      shellResult('c1'),
      shellCall('c2', 'pwd'),
      shellResult('c2'),
    ];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('command_group');
    if (result[0].kind === 'command_group') {
      expect(result[0].commands).toHaveLength(2);
    }
  });

  // 5. Three consecutive shell commands → command_group
  it('groups 3 consecutive shell commands into a command_group', () => {
    const entries: TranscriptEntry[] = [
      shellCall('c1', 'echo hello'),
      shellResult('c1'),
      shellCall('c2', 'cat file'),
      shellResult('c2'),
      shellCall('c3', 'grep foo'),
      shellResult('c3'),
    ];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('command_group');
    if (result[0].kind === 'command_group') {
      expect(result[0].commands).toHaveLength(3);
    }
  });

  // 6. command_group carries correct exitCodes
  it('extracts exit codes from shell results (error flag)', () => {
    const entries: TranscriptEntry[] = [
      shellCall('c1'),
      shellResult('c1', 'ok', false),
      shellCall('c2'),
      shellResult('c2', 'fail', true), // isError = true → exitCode 1
    ];
    const result = groupTranscript(entries);
    expect(result[0].kind).toBe('command_group');
    if (result[0].kind === 'command_group') {
      expect(result[0].exitCodes).toEqual([0, 1]);
    }
  });

  // 7. Shell group interrupted by assistant → two singles + command_group
  it('breaks command_group when interrupted by a non-tool entry', () => {
    const entries: TranscriptEntry[] = [
      shellCall('c1'),
      shellResult('c1'),
      shellCall('c2'),
      shellResult('c2'),
      assistant('comment'), // breaks the run
      shellCall('c3'),
      shellResult('c3'),
      shellCall('c4'),
      shellResult('c4'),
    ];
    const result = groupTranscript(entries);
    // first group (2 commands), 1 assistant single, second group (2 commands)
    expect(result).toHaveLength(3);
    expect(result[0].kind).toBe('command_group');
    expect(result[1].kind).toBe('single');
    expect(result[2].kind).toBe('command_group');
  });

  // 8. 2 shell + 1 non-shell tool → command_group(2) + singles for non-shell pair
  it('does not mix shell and non-shell pairs into the same group', () => {
    const entries: TranscriptEntry[] = [
      shellCall('c1'),
      shellResult('c1'),
      shellCall('c2'),
      shellResult('c2'),
      toolCall('t1', 'read_file'),
      toolResult('t1'),
    ];
    const result = groupTranscript(entries);
    // command_group(2) + 2 singles (tool call + result degrade, only 1 pair)
    expect(result[0].kind).toBe('command_group');
    expect(result.slice(1).every((g) => g.kind === 'single')).toBe(true);
  });

  // 9. Orphan tool_result (no matching call) → single
  it('renders an orphan tool_result as a single entry', () => {
    const orphan = orphanResult('no-such-call');
    const entries: TranscriptEntry[] = [assistant('before'), orphan];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(2);
    expect(result[1].kind).toBe('single');
    if (result[1].kind === 'single') {
      expect(result[1].entry).toBe(orphan);
    }
  });

  // 10. Exactly 3 non-shell tool pairs → tool_group
  it('groups 3 consecutive non-shell tool pairs into a tool_group', () => {
    const entries: TranscriptEntry[] = [
      toolCall('t1', 'read_file'),
      toolResult('t1'),
      toolCall('t2', 'grep'),
      toolResult('t2'),
      toolCall('t3', 'ls'),
      toolResult('t3'),
    ];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(1);
    expect(result[0].kind).toBe('tool_group');
    if (result[0].kind === 'tool_group') {
      expect(result[0].tools).toHaveLength(3);
      expect(result[0].toolNames).toEqual(['read_file', 'grep', 'ls']);
    }
  });

  // 11. Exactly 2 non-shell tool pairs → degrades to singles
  it('degrades 2 non-shell tool pairs to singles (below tool_group threshold)', () => {
    const entries: TranscriptEntry[] = [
      toolCall('t1', 'read_file'),
      toolResult('t1'),
      toolCall('t2', 'grep'),
      toolResult('t2'),
    ];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(4);
    expect(result.every((g) => g.kind === 'single')).toBe(true);
  });

  // 12. tool_group carries toolNames list
  it('tool_group toolNames lists all tool names in order', () => {
    const entries: TranscriptEntry[] = [
      toolCall('t1', 'read_file'),
      toolResult('t1'),
      toolCall('t2', 'grep'),
      toolResult('t2'),
      toolCall('t3', 'read_file'),
      toolResult('t3'),
      toolCall('t4', 'Write'),
      toolResult('t4'),
    ];
    const result = groupTranscript(entries);
    expect(result[0].kind).toBe('tool_group');
    if (result[0].kind === 'tool_group') {
      expect(result[0].toolNames).toEqual(['read_file', 'grep', 'read_file', 'Write']);
    }
  });

  // 13. Mixed stream: assistant + thinking + shell group + assistant → order preserved
  it('preserves order in a mixed stream', () => {
    const a1 = assistant('task intro');
    const t1 = thinking('planning...');
    const entries: TranscriptEntry[] = [
      a1,
      t1,
      shellCall('c1', 'git status'),
      shellResult('c1'),
      shellCall('c2', 'git diff'),
      shellResult('c2'),
      shellCall('c3', 'git log'),
      shellResult('c3'),
      assistant('done'),
    ];
    const result = groupTranscript(entries);
    expect(result).toHaveLength(4); // assistant, thinking, command_group(3), assistant
    expect(result[0].kind).toBe('single');
    expect(result[1].kind).toBe('single');
    expect(result[2].kind).toBe('command_group');
    expect(result[3].kind).toBe('single');
    if (result[0].kind === 'single') expect(result[0].entry).toBe(a1);
    if (result[1].kind === 'single') expect(result[1].entry).toBe(t1);
  });

  // 14. Shell tool name variants are all recognized
  it('recognises all shell tool name variants', () => {
    const shellNames = [
      'bash',
      'Bash',
      'run_shell_command',
      'shell',
      'execute_command',
      'run_command',
    ];
    for (const name of shellNames) {
      const call: TranscriptEntry = {
        id: id(),
        kind: 'tool_call',
        toolName: name,
        args: {},
        toolCallId: `test-${name}`,
        createdAt: '2024-01-01T00:00:00Z',
      };
      const result_entry: TranscriptEntry = {
        id: id(),
        kind: 'tool_result',
        toolCallId: `test-${name}`,
        content: 'ok',
        isError: false,
        createdAt: '2024-01-01T00:00:01Z',
      };
      // Pair two of this tool to hit the min threshold
      const sibling_call: TranscriptEntry = {
        id: id(),
        kind: 'tool_call',
        toolName: name,
        args: {},
        toolCallId: `test-${name}-b`,
        createdAt: '2024-01-01T00:00:02Z',
      };
      const sibling_result: TranscriptEntry = {
        id: id(),
        kind: 'tool_result',
        toolCallId: `test-${name}-b`,
        content: 'ok',
        isError: false,
        createdAt: '2024-01-01T00:00:03Z',
      };
      const grouped = groupTranscript([call, result_entry, sibling_call, sibling_result]);
      expect(grouped[0].kind).toBe('command_group');
    }
  });

  // 15. command_group startedAt / endedAt timestamps
  it('sets startedAt to first call and endedAt to last result createdAt', () => {
    const c1 = shellCall('c1');
    c1.createdAt = '2024-01-01T10:00:00Z';
    const r1 = shellResult('c1');
    r1.createdAt = '2024-01-01T10:00:01Z';
    const c2 = shellCall('c2');
    c2.createdAt = '2024-01-01T10:00:02Z';
    const r2 = shellResult('c2');
    r2.createdAt = '2024-01-01T10:00:05Z';

    const result = groupTranscript([c1, r1, c2, r2]);
    expect(result[0].kind).toBe('command_group');
    if (result[0].kind === 'command_group') {
      expect(result[0].startedAt).toBe('2024-01-01T10:00:00Z');
      expect(result[0].endedAt).toBe('2024-01-01T10:00:05Z');
    }
  });
});
