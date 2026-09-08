/**
 * transcript-grouping.ts — pure function for grouping consecutive transcript entries.
 *
 * Groups:
 *   - Consecutive shell tool_call + tool_result pairs (≥2) → command_group
 *   - Consecutive non-shell tool_call + tool_result pairs (≥3) → tool_group
 *   - Everything else passes through as single entries
 *
 * Safe to re-run on every SSE append — pure, no side effects.
 */

import type { TranscriptEntry } from '$lib/domain/sessions/types.js';

// ── Types ────────────────────────────────────────────────────────────────────

export type CommandPair = {
  call: TranscriptEntry & { kind: 'tool_call' };
  result?: TranscriptEntry & { kind: 'tool_result' };
};

export type ToolPair = {
  call: TranscriptEntry & { kind: 'tool_call' };
  result?: TranscriptEntry & { kind: 'tool_result' };
};

export type GroupedEntry =
  | { kind: 'single'; entry: TranscriptEntry }
  | {
      kind: 'command_group';
      commands: CommandPair[];
      startedAt: string;
      endedAt: string;
      exitCodes: number[];
    }
  | {
      kind: 'tool_group';
      tools: ToolPair[];
      toolNames: string[];
      startedAt: string;
      endedAt: string;
    };

// ── Shell tool name set ───────────────────────────────────────────────────────

/** All tool names that represent a shell/command execution. */
const SHELL_TOOL_NAMES = new Set([
  'bash',
  'Bash',
  'run_shell_command',
  'shell',
  'execute_command',
  'run_command',
  'sh',
  'zsh',
  'cmd',
  'powershell',
  'exec',
]);

function isShellTool(toolName: string): boolean {
  return SHELL_TOOL_NAMES.has(toolName);
}

// ── Exit code extraction ──────────────────────────────────────────────────────

/**
 * Attempt to extract an exit code from a tool_result content string.
 * Common formats:
 *   "Exit code: 1\n..."
 *   "<exit_code>0</exit_code>"
 *   "exit_code=127"
 * Returns 0 if content looks successful, 1 if error flag is set, -1 if unknown.
 */
function extractExitCode(result: (TranscriptEntry & { kind: 'tool_result' }) | undefined): number {
  if (!result) return -1;
  if (result.isError) return 1;

  const text = result.content;
  const codeMatch =
    text.match(/[Ee]xit[\s_-]code[:\s=]+(\d+)/i) ??
    text.match(/<exit_code>(\d+)<\/exit_code>/i) ??
    text.match(/\bexit[\s_]?code[:\s]+(\d+)/i);

  if (codeMatch) return parseInt(codeMatch[1], 10);
  return 0;
}

// ── Pair-building pass ────────────────────────────────────────────────────────

/**
 * Intermediate representation: tool_call paired with its result (by toolCallId),
 * or an orphan result / non-tool entry.
 */
type PairedEntry =
  | {
      type: 'shell_pair';
      call: TranscriptEntry & { kind: 'tool_call' };
      result?: TranscriptEntry & { kind: 'tool_result' };
    }
  | {
      type: 'tool_pair';
      call: TranscriptEntry & { kind: 'tool_call' };
      result?: TranscriptEntry & { kind: 'tool_result' };
    }
  | { type: 'passthrough'; entry: TranscriptEntry };

/**
 * First pass: match tool_result entries to their tool_call by toolCallId.
 * Orphan tool_results (no matching call) become passthrough singles.
 */
function buildPairs(entries: TranscriptEntry[]): PairedEntry[] {
  // Index all tool_calls by toolCallId for O(1) lookup
  const callIndex = new Map<string, TranscriptEntry & { kind: 'tool_call' }>();
  for (const e of entries) {
    if (e.kind === 'tool_call') {
      callIndex.set(e.toolCallId, e);
    }
  }

  // Track which toolCallIds have been consumed (either as call or result)
  const consumed = new Set<string>();
  const pairs: PairedEntry[] = [];

  for (const entry of entries) {
    if (entry.kind === 'tool_call') {
      if (consumed.has(entry.toolCallId)) continue; // already emitted as part of a pair
      consumed.add(entry.toolCallId);

      if (isShellTool(entry.toolName)) {
        pairs.push({ type: 'shell_pair', call: entry });
      } else {
        pairs.push({ type: 'tool_pair', call: entry });
      }
      continue;
    }

    if (entry.kind === 'tool_result') {
      if (consumed.has(entry.toolCallId)) {
        // Result for a call we already emitted — attach it
        const existing = pairs.find(
          (p): p is PairedEntry & { type: 'shell_pair' | 'tool_pair' } =>
            (p.type === 'shell_pair' || p.type === 'tool_pair') &&
            p.call.toolCallId === entry.toolCallId
        );
        if (existing) {
          existing.result = entry;
        } else {
          // Orphan result
          pairs.push({ type: 'passthrough', entry });
        }
        continue;
      }

      // Result with no matching call in the list → orphan
      if (!callIndex.has(entry.toolCallId)) {
        pairs.push({ type: 'passthrough', entry });
        continue;
      }

      // Result arrived before we hit the call in the loop — unusual but handle it:
      // mark consumed, find the call and attach
      consumed.add(entry.toolCallId);
      const matchedCall = callIndex.get(entry.toolCallId)!;
      if (isShellTool(matchedCall.toolName)) {
        pairs.push({ type: 'shell_pair', call: matchedCall, result: entry });
      } else {
        pairs.push({ type: 'tool_pair', call: matchedCall, result: entry });
      }
      continue;
    }

    // All other entry kinds
    pairs.push({ type: 'passthrough', entry });
  }

  return pairs;
}

// ── Grouping pass ─────────────────────────────────────────────────────────────

const MIN_COMMAND_GROUP = 2; // ≥2 shell pairs → command_group
const MIN_TOOL_GROUP = 3; // ≥3 non-shell pairs → tool_group

export function groupTranscript(entries: TranscriptEntry[]): GroupedEntry[] {
  if (entries.length === 0) return [];

  const pairs = buildPairs(entries);
  const result: GroupedEntry[] = [];

  let i = 0;

  while (i < pairs.length) {
    const p = pairs[i];

    // --- Try to collect a run of shell pairs ---
    if (p.type === 'shell_pair') {
      const run: (PairedEntry & { type: 'shell_pair' })[] = [];
      let j = i;
      while (j < pairs.length && pairs[j].type === 'shell_pair') {
        run.push(pairs[j] as PairedEntry & { type: 'shell_pair' });
        j++;
      }

      if (run.length >= MIN_COMMAND_GROUP) {
        const commands: CommandPair[] = run.map((r) => ({
          call: r.call,
          result: r.result,
        }));
        const exitCodes = commands.map((c) => extractExitCode(c.result));
        result.push({
          kind: 'command_group',
          commands,
          startedAt: run[0].call.createdAt,
          endedAt: (run[run.length - 1].result ?? run[run.length - 1].call).createdAt,
          exitCodes,
        });
        i = j;
        continue;
      }

      // Degrade: emit each shell pair as individual singles
      for (const r of run) {
        result.push({ kind: 'single', entry: r.call });
        if (r.result) result.push({ kind: 'single', entry: r.result });
      }
      i = j;
      continue;
    }

    // --- Try to collect a run of non-shell tool pairs ---
    if (p.type === 'tool_pair') {
      const run: (PairedEntry & { type: 'tool_pair' })[] = [];
      let j = i;
      while (j < pairs.length && pairs[j].type === 'tool_pair') {
        run.push(pairs[j] as PairedEntry & { type: 'tool_pair' });
        j++;
      }

      if (run.length >= MIN_TOOL_GROUP) {
        const tools: ToolPair[] = run.map((r) => ({
          call: r.call,
          result: r.result,
        }));
        const toolNames = run.map((r) => r.call.toolName);
        result.push({
          kind: 'tool_group',
          tools,
          toolNames,
          startedAt: run[0].call.createdAt,
          endedAt: (run[run.length - 1].result ?? run[run.length - 1].call).createdAt,
        });
        i = j;
        continue;
      }

      // Degrade: emit each tool pair as individual singles
      for (const r of run) {
        result.push({ kind: 'single', entry: r.call });
        if (r.result) result.push({ kind: 'single', entry: r.result });
      }
      i = j;
      continue;
    }

    // --- Passthrough ---
    result.push({
      kind: 'single',
      entry: (p as PairedEntry & { type: 'passthrough' }).entry,
    });
    i++;
  }

  return result;
}
