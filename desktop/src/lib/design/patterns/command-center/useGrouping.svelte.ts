/**
 * useGrouping — pure reactive grouping logic for Command Center.
 * Reads filteredSessions, returns groups keyed by the chosen dimension.
 * localStorage key: canopy.command_center.group_by
 * LOC target: ≤ 120.
 */

import type { Session } from '$lib/domain/sessions/types.js';

export type GroupBy = 'none' | 'project' | 'workspace' | 'agent' | 'runtime';

const LS_KEY_GROUP = 'canopy.command_center.group_by';
const LS_KEY_COLLAPSED = 'canopy.command_center.collapsed';

export interface SessionGroup {
  key: string;
  label: string;
  sessions: Session[];
}

// ── Persistence helpers ────────────────────────────────────────────────────────

function readGroupBy(): GroupBy {
  try {
    const raw = localStorage.getItem(LS_KEY_GROUP);
    const valid: GroupBy[] = ['none', 'project', 'workspace', 'agent', 'runtime'];
    return valid.includes(raw as GroupBy) ? (raw as GroupBy) : 'none';
  } catch {
    return 'none';
  }
}

function writeGroupBy(v: GroupBy): void {
  try {
    localStorage.setItem(LS_KEY_GROUP, v);
  } catch {
    // ignore
  }
}

function readCollapsed(): Set<string> {
  try {
    const raw = localStorage.getItem(LS_KEY_COLLAPSED);
    if (!raw) return new Set();
    return new Set(JSON.parse(raw) as string[]);
  } catch {
    return new Set();
  }
}

function writeCollapsed(s: Set<string>): void {
  try {
    localStorage.setItem(LS_KEY_COLLAPSED, JSON.stringify([...s]));
  } catch {
    // ignore
  }
}

// ── Grouping logic ─────────────────────────────────────────────────────────────

function extractKey(session: Session, by: GroupBy): string {
  switch (by) {
    case 'project':
      return session.workspaceSlug ?? 'ungrouped';
    case 'workspace':
      return session.workspaceSlug ?? 'default';
    case 'agent':
      return session.agentSlug ?? 'no-agent';
    case 'runtime':
      return session.runtimeType;
    default:
      return '__all__';
  }
}

function buildGroups(sessions: Session[], by: GroupBy): SessionGroup[] {
  if (by === 'none') {
    return [{ key: '__all__', label: 'All sessions', sessions }];
  }

  const map = new Map<string, Session[]>();
  for (const s of sessions) {
    const k = extractKey(s, by);
    const bucket = map.get(k) ?? [];
    bucket.push(s);
    map.set(k, bucket);
  }

  return [...map.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, sList]) => ({ key, label: key, sessions: sList }));
}

// ── Reactive class ─────────────────────────────────────────────────────────────

export class GroupingState {
  groupBy = $state<GroupBy>(typeof localStorage !== 'undefined' ? readGroupBy() : 'none');

  collapsed = $state<Set<string>>(
    typeof localStorage !== 'undefined' ? readCollapsed() : new Set()
  );

  setGroupBy(v: GroupBy): void {
    this.groupBy = v;
    writeGroupBy(v);
  }

  toggleCollapsed(key: string): void {
    const next = new Set(this.collapsed);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    this.collapsed = next;
    writeCollapsed(this.collapsed);
  }

  isCollapsed(key: string): boolean {
    return this.collapsed.has(key);
  }

  groups(sessions: Session[]): SessionGroup[] {
    return buildGroups(sessions, this.groupBy);
  }
}
