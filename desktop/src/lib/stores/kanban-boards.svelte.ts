/**
 * kanban-boards.svelte.ts — Multi-board Kanban store.
 * Boards are persisted in localStorage; no backend required.
 * CSS prefix: n/a (store only)
 */

import type { TaskStatus } from '$lib/domain/tasks/types.js';

// ── Types ─────────────────────────────────────────────────────────────────────

export type TransitionVerb = 'start' | 'build' | 'pause' | 'resume' | 'stop' | 'done' | 'noop';

/** Infer the default verb from a status when none is explicitly set. */
export function inferVerb(status: TaskStatus): TransitionVerb {
  switch (status) {
    case 'in_progress':
      return 'start';
    case 'done':
      return 'done';
    case 'cancelled':
      return 'stop';
    case 'todo':
    default:
      return 'noop';
  }
}

export interface ColumnConfig {
  status: TaskStatus;
  label: string;
  wipLimit: number;
  /** Verb emitted to the transition endpoint on card drop. Defaults via inferVerb(). */
  verb?: TransitionVerb;
}

export type BoardScope =
  | { type: 'workspace'; slug: string }
  | { type: 'agent'; agentId: string }
  | { type: 'assignee_type'; value: 'agent' | 'human' }
  | { type: 'label'; label: string };

export interface BoardConfig {
  id: string;
  name: string;
  scope: BoardScope;
  columns: ColumnConfig[];
  createdAt: string;
}

// ── Constants ─────────────────────────────────────────────────────────────────

const LS_KEY = 'canopy.kanban.boards';
const LS_ACTIVE_KEY = 'canopy.kanban.active';

const DEFAULT_COLUMNS: ColumnConfig[] = [
  { status: 'todo', label: 'Todo', wipLimit: 999 },
  { status: 'in_progress', label: 'In Progress', wipLimit: 5 },
  { status: 'done', label: 'Done', wipLimit: 999 },
  { status: 'cancelled', label: 'Cancelled', wipLimit: 999 },
];

function makeId(): string {
  return crypto.randomUUID();
}

function now(): string {
  return new Date().toISOString();
}

// ── Store class ───────────────────────────────────────────────────────────────

class KanbanBoardsStore {
  boards = $state<BoardConfig[]>([]);
  activeBoardId = $state<string>('');

  constructor() {
    this._load();
  }

  // ── Derived ─────────────────────────────────────────────────────────────────

  get activeBoard(): BoardConfig | undefined {
    return this.boards.find((b) => b.id === this.activeBoardId);
  }

  // ── Seed ────────────────────────────────────────────────────────────────────

  defaultBoards(): BoardConfig[] {
    return [
      {
        id: makeId(),
        name: 'All tasks',
        scope: { type: 'workspace', slug: 'default' },
        columns: [...DEFAULT_COLUMNS],
        createdAt: now(),
      },
      {
        id: makeId(),
        name: 'Agent tasks',
        scope: { type: 'assignee_type', value: 'agent' },
        columns: [...DEFAULT_COLUMNS],
        createdAt: now(),
      },
      {
        id: makeId(),
        name: 'Human-assigned',
        scope: { type: 'assignee_type', value: 'human' },
        columns: [...DEFAULT_COLUMNS],
        createdAt: now(),
      },
    ];
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────────

  createBoard(
    name: string,
    scope: BoardScope,
    columns: ColumnConfig[] = [...DEFAULT_COLUMNS]
  ): BoardConfig {
    const board: BoardConfig = {
      id: makeId(),
      name,
      scope,
      columns,
      createdAt: now(),
    };
    this.boards = [...this.boards, board];
    this.activeBoardId = board.id;
    this._save();
    return board;
  }

  deleteBoard(id: string): void {
    this.boards = this.boards.filter((b) => b.id !== id);
    if (this.activeBoardId === id) {
      this.activeBoardId = this.boards[0]?.id ?? '';
    }
    this._save();
  }

  renameBoard(id: string, name: string): void {
    this.boards = this.boards.map((b) => (b.id === id ? { ...b, name } : b));
    this._save();
  }

  updateScope(id: string, scope: BoardScope): void {
    this.boards = this.boards.map((b) => (b.id === id ? { ...b, scope } : b));
    this._save();
  }

  updateColumns(id: string, columns: ColumnConfig[]): void {
    this.boards = this.boards.map((b) => (b.id === id ? { ...b, columns } : b));
    this._save();
  }

  setActive(id: string): void {
    this.activeBoardId = id;
    this._save();
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  private _load(): void {
    if (typeof localStorage === 'undefined') return;
    try {
      const raw = localStorage.getItem(LS_KEY);
      const activeRaw = localStorage.getItem(LS_ACTIVE_KEY);
      const parsed = raw ? (JSON.parse(raw) as unknown) : null;

      if (
        Array.isArray(parsed) &&
        parsed.length > 0 &&
        typeof (parsed[0] as Record<string, unknown>).id === 'string'
      ) {
        this.boards = parsed as BoardConfig[];
        const activeId = typeof activeRaw === 'string' ? activeRaw : '';
        this.activeBoardId =
          this.boards.find((b) => b.id === activeId)?.id ?? this.boards[0]?.id ?? '';
      } else {
        // First run or stale JSON — seed defaults
        const seeds = this.defaultBoards();
        this.boards = seeds;
        this.activeBoardId = seeds[0]?.id ?? '';
        this._save();
      }
    } catch {
      // Corrupt JSON — reset gracefully
      const seeds = this.defaultBoards();
      this.boards = seeds;
      this.activeBoardId = seeds[0]?.id ?? '';
      this._save();
    }
  }

  private _save(): void {
    if (typeof localStorage === 'undefined') return;
    try {
      localStorage.setItem(LS_KEY, JSON.stringify(this.boards));
      localStorage.setItem(LS_ACTIVE_KEY, this.activeBoardId);
    } catch {
      // Quota exceeded — fail silently
    }
  }
}

export const kanbanBoards = new KanbanBoardsStore();
