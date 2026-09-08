/**
 * AgentLiveCard unit tests — pure logic, no DOM rendering.
 *
 * Tests:
 *   1. visualState resolution from last TranscriptEntry kind
 *   2. statusLabel text for each state
 *   3. truncate preview to 60 chars
 *   4. relative-time formatting via date-fns formatDistanceToNow
 *   5. dotColor mapping
 */

import { formatDistanceToNow } from 'date-fns';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import type { TranscriptEntry } from '$lib/domain/sessions/types.js';

// ── Helpers mirrored from AgentLiveCard.svelte ─────────────────────────────

type VisualState = 'idle' | 'thinking' | 'tool_call' | 'assistant' | 'error' | 'completed';

function resolveVisualState(
  runningSession: boolean,
  sessionCompleted: boolean,
  lastEntry: TranscriptEntry | null
): VisualState {
  if (sessionCompleted) return 'completed';
  if (!runningSession || !lastEntry) return 'idle';
  switch (lastEntry.kind) {
    case 'thinking':
      return 'thinking';
    case 'tool_call':
      return 'tool_call';
    case 'assistant':
      return 'assistant';
    case 'system':
    case 'stderr':
      return 'error';
    default:
      return 'assistant';
  }
}

function resolveDotColor(state: VisualState): 'green' | 'amber' | 'red' | 'grey' {
  switch (state) {
    case 'thinking':
    case 'tool_call':
    case 'assistant':
    case 'completed':
      return 'green';
    case 'error':
      return 'red';
    default:
      return 'grey';
  }
}

function truncate(text: string, maxLen = 60): string {
  return text.length > maxLen ? text.slice(0, maxLen) + '\u2026' : text;
}

function resolveStatusLabel(
  state: VisualState,
  lastEntry: TranscriptEntry | null,
  startedAt: string | null,
  completedAt: number | null
): string {
  switch (state) {
    case 'idle': {
      if (!startedAt) return 'Never run';
      const ago = formatDistanceToNow(new Date(startedAt), { addSuffix: true });
      return `Last run: ${ago}`;
    }
    case 'thinking':
      return 'Thinking\u2026';
    case 'tool_call':
      return lastEntry?.kind === 'tool_call' ? `Using: ${lastEntry.toolName}` : 'Using tool\u2026';
    case 'assistant':
      return 'Responding\u2026';
    case 'error':
      return lastEntry?.kind === 'system' ? `Error: ${lastEntry.text}` : 'Error';
    case 'completed': {
      if (completedAt && startedAt) {
        const durSec = Math.round((completedAt - new Date(startedAt).getTime()) / 1000);
        return `Completed ${durSec}s`;
      }
      return 'Completed';
    }
  }
}

// ── Fixtures ───────────────────────────────────────────────────────────────

function makeThinking(id = '1'): TranscriptEntry {
  return {
    id,
    kind: 'thinking',
    text: 'I need to think about this.',
    createdAt: '2026-04-18T00:00:00Z',
  };
}

function makeToolCall(id = '2'): TranscriptEntry {
  return {
    id,
    kind: 'tool_call',
    toolName: 'Bash',
    args: { command: 'ls -la' },
    toolCallId: 'tc-1',
    createdAt: '2026-04-18T00:00:01Z',
  };
}

function makeAssistant(id = '3'): TranscriptEntry {
  return {
    id,
    kind: 'assistant',
    text: 'Here is the result.',
    createdAt: '2026-04-18T00:00:02Z',
  };
}

function makeSystem(id = '4', text = 'Rate limit exceeded'): TranscriptEntry {
  return { id, kind: 'system', text, createdAt: '2026-04-18T00:00:03Z' };
}

function makeStderr(id = '5'): TranscriptEntry {
  return {
    id,
    kind: 'stderr',
    text: 'command not found',
    createdAt: '2026-04-18T00:00:04Z',
  };
}

// ── VisualState resolution ─────────────────────────────────────────────────

describe('resolveVisualState', () => {
  it('returns idle when no running session', () => {
    expect(resolveVisualState(false, false, null)).toBe('idle');
  });

  it('returns idle when running but no last entry yet', () => {
    expect(resolveVisualState(true, false, null)).toBe('idle');
  });

  it('returns completed when session just finished (overrides last entry)', () => {
    expect(resolveVisualState(true, true, makeAssistant())).toBe('completed');
  });

  it('returns thinking when last entry kind is thinking', () => {
    expect(resolveVisualState(true, false, makeThinking())).toBe('thinking');
  });

  it('returns tool_call when last entry kind is tool_call', () => {
    expect(resolveVisualState(true, false, makeToolCall())).toBe('tool_call');
  });

  it('returns assistant when last entry kind is assistant', () => {
    expect(resolveVisualState(true, false, makeAssistant())).toBe('assistant');
  });

  it('returns error when last entry kind is system', () => {
    expect(resolveVisualState(true, false, makeSystem())).toBe('error');
  });

  it('returns error when last entry kind is stderr', () => {
    expect(resolveVisualState(true, false, makeStderr())).toBe('error');
  });
});

// ── dotColor mapping ───────────────────────────────────────────────────────

describe('resolveDotColor', () => {
  it('maps thinking → green', () => expect(resolveDotColor('thinking')).toBe('green'));
  it('maps tool_call → green', () => expect(resolveDotColor('tool_call')).toBe('green'));
  it('maps assistant → green', () => expect(resolveDotColor('assistant')).toBe('green'));
  it('maps completed → green', () => expect(resolveDotColor('completed')).toBe('green'));
  it('maps error → red', () => expect(resolveDotColor('error')).toBe('red'));
  it('maps idle → grey', () => expect(resolveDotColor('idle')).toBe('grey'));
});

// ── statusLabel text ───────────────────────────────────────────────────────

describe('resolveStatusLabel', () => {
  it('shows Never run when idle with no prior session', () => {
    expect(resolveStatusLabel('idle', null, null, null)).toBe('Never run');
  });

  it('shows Last run: X ago when idle with a prior session', () => {
    // Recent enough that formatDistanceToNow gives "less than a minute ago" or similar
    const iso = new Date(Date.now() - 5000).toISOString();
    const label = resolveStatusLabel('idle', null, iso, null);
    expect(label).toMatch(/^Last run: /);
  });

  it('shows Thinking… for thinking state', () => {
    expect(resolveStatusLabel('thinking', makeThinking(), null, null)).toBe('Thinking\u2026');
  });

  it('shows Using: {toolName} for tool_call state', () => {
    expect(resolveStatusLabel('tool_call', makeToolCall(), null, null)).toBe('Using: Bash');
  });

  it('shows Responding… for assistant state', () => {
    expect(resolveStatusLabel('assistant', makeAssistant(), null, null)).toBe('Responding\u2026');
  });

  it('shows Error: {text} for system error', () => {
    const entry = makeSystem('e1', 'Rate limit exceeded');
    expect(resolveStatusLabel('error', entry, null, null)).toBe('Error: Rate limit exceeded');
  });

  it('shows Error for non-system error entry', () => {
    expect(resolveStatusLabel('error', makeStderr(), null, null)).toBe('Error');
  });

  it('shows Completed {N}s when duration computable', () => {
    const startedAt = new Date(Date.now() - 12000).toISOString();
    const completedAt = Date.now();
    const label = resolveStatusLabel('completed', null, startedAt, completedAt);
    expect(label).toMatch(/^Completed \d+s$/);
  });

  it('shows Completed (no duration) when times unavailable', () => {
    expect(resolveStatusLabel('completed', null, null, null)).toBe('Completed');
  });
});

// ── Truncate logic ─────────────────────────────────────────────────────────

describe('truncate', () => {
  it('returns short strings unchanged', () => {
    expect(truncate('hello')).toBe('hello');
  });

  it('truncates at 60 chars and appends ellipsis', () => {
    const long = 'a'.repeat(80);
    const result = truncate(long);
    expect(result).toHaveLength(61); // 60 + '…'
    expect(result.endsWith('\u2026')).toBe(true);
  });

  it('does not truncate strings exactly at the limit', () => {
    const exact = 'x'.repeat(60);
    expect(truncate(exact)).toBe(exact);
  });
});

// ── Relative-time formatting ───────────────────────────────────────────────

describe('formatDistanceToNow (date-fns)', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-04-18T12:00:00Z'));
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('formats 2 hours ago correctly', () => {
    const twoHrsAgo = new Date('2026-04-18T10:00:00Z');
    const result = formatDistanceToNow(twoHrsAgo, { addSuffix: true });
    expect(result).toMatch(/about 2 hours ago/i);
  });

  it('formats 30 seconds ago correctly', () => {
    const recent = new Date('2026-04-18T11:59:30Z');
    const result = formatDistanceToNow(recent, { addSuffix: true });
    // date-fns v4 returns "1 minute ago" for the 30-59s range
    expect(result).toMatch(/minute(s)? ago/i);
  });

  it('formats 1 day ago correctly', () => {
    const yesterday = new Date('2026-04-17T12:00:00Z');
    const result = formatDistanceToNow(yesterday, { addSuffix: true });
    expect(result).toMatch(/1 day ago/i);
  });
});
