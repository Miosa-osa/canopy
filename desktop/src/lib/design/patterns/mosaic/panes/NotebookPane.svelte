<script lang="ts">
  /**
   * NotebookPane — Jupyter-style annotated runbook viewer for the Mosaic.
   * CSS prefix: nbp-
   *
   * Parses a Drive notebook entry's markdown content into alternating cell
   * types: `markdown` (rendered HTML) and `command` (executable fenced code).
   * Command cells can be run individually or via "Run all" sequentially.
   *
   * Parsing: splits on ``` fences — content outside = markdown, inside = command.
   * Run mechanics: POST /sessions/{sessionId}/messages with the command text,
   * or spawns a new terminal session when no sessionId is available.
   *
   * Props: notebookRef (Drive entry slug/id), workspaceSlug.
   */

  import { createQuery } from '@tanstack/svelte-query';
  import { writable } from 'svelte/store';
  import { untrack } from 'svelte';
  import { Play, RotateCcw, ChevronDown, ChevronRight, BookOpen } from 'lucide-svelte';
  import { driveEntryQuery } from '$lib/api/queries/drive.js';
  import { createSession } from '$lib/api/queries/sessions.js';
  import { apiPost } from '$lib/api/client.js';
  import type { DriveEntry } from '$lib/domain/drive/types.js';

  // ── Props ──────────────────────────────────────────────────────────────────

  interface Props {
    notebookRef: string;
    workspaceSlug?: string;
  }

  let { notebookRef, workspaceSlug = 'default' }: Props = $props();

  // ── Drive entry query ──────────────────────────────────────────────────────

  const entryOptsStore = writable(
    untrack(() => driveEntryQuery(notebookRef)),
  );
  $effect(() => { entryOptsStore.set(driveEntryQuery(notebookRef)); });
  const entryQ = createQuery<DriveEntry>(entryOptsStore);

  const entry = $derived($entryQ.data ?? null);

  // ── Cell types ─────────────────────────────────────────────────────────────

  type CellStatus = 'idle' | 'running' | 'success' | 'error';

  interface Cell {
    id: number;
    type: 'markdown' | 'command';
    content: string;
    lang: string;
    status: CellStatus;
    output: string;
    outputOpen: boolean;
  }

  // ── Minimal markdown renderer (headers, bold, italic, code, lists) ─────────

  function renderMarkdown(md: string): string {
    return md
      // Fenced code (inline)
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      // Headers
      .replace(/^### (.+)$/gm, '<h3>$1</h3>')
      .replace(/^## (.+)$/gm, '<h2>$1</h2>')
      .replace(/^# (.+)$/gm, '<h1>$1</h1>')
      // Bold / italic
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/\*([^*]+)\*/g, '<em>$1</em>')
      // Unordered list items
      .replace(/^[-*] (.+)$/gm, '<li>$1</li>')
      // Ordered list items
      .replace(/^\d+\. (.+)$/gm, '<li>$1</li>')
      // Paragraphs (blank-line-separated blocks)
      .replace(/\n{2,}/g, '</p><p>')
      .replace(/^(?!<[hlico])(.+)$/gm, (m) => m)
      // Wrap in paragraph if not already a block element
      .replace(/^([^<\n].+)$/gm, (m) => m.includes('<li>') ? m : m);
  }

  // ── Parse notebook content into cells ─────────────────────────────────────

  function parseCells(content: string): Cell[] {
    const cells: Cell[] = [];
    let id = 0;
    // Split on fenced code blocks: ```lang?\n...content...\n```
    const fence = /^```([^\n]*)\n([\s\S]*?)^```/gm;
    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = fence.exec(content)) !== null) {
      // Text before this fence → markdown cell
      const before = content.slice(lastIndex, match.index).trim();
      if (before) {
        cells.push({ id: id++, type: 'markdown', content: before, lang: '', status: 'idle', output: '', outputOpen: false });
      }
      // The fence itself → command cell
      const lang = match[1].trim() || 'bash';
      const cmd = match[2].trim();
      if (cmd) {
        cells.push({ id: id++, type: 'command', content: cmd, lang, status: 'idle', output: '', outputOpen: false });
      }
      lastIndex = match.index + match[0].length;
    }

    // Trailing markdown after last fence
    const tail = content.slice(lastIndex).trim();
    if (tail) {
      cells.push({ id: id++, type: 'markdown', content: tail, lang: '', status: 'idle', output: '', outputOpen: false });
    }

    return cells.length ? cells : [{ id: 0, type: 'markdown', content: content, lang: '', status: 'idle', output: '', outputOpen: false }];
  }

  // ── Derive content string from Drive body ──────────────────────────────────

  const rawContent = $derived(
    !entry
      ? ''
      : typeof (entry.body as Record<string, unknown>)['content'] === 'string'
        ? (entry.body as Record<string, unknown>)['content'] as string
        : typeof (entry.body as Record<string, unknown>)['body'] === 'string'
          ? (entry.body as Record<string, unknown>)['body'] as string
          : `# ${entry.name}\n\nThis notebook has no content yet.\n`
  );

  // ── Reactive cells ($state array, reparsed when entry changes) ────────────

  let cells = $state<Cell[]>([]);

  $effect(() => {
    cells = parseCells(rawContent);
  });

  const commandCount = $derived(cells.filter((c) => c.type === 'command').length);

  // ── Session for running commands ───────────────────────────────────────────

  let sessionId = $state<string | null>(null);

  async function ensureSession(): Promise<string> {
    if (sessionId) return sessionId;
    const s = (await createSession({
      runtimeType: 'claude-local',
      workspaceSlug,
      cwd: '~',
    })) as unknown as { id?: string; sessionId?: string };
    const id = s.sessionId ?? s.id ?? '';
    sessionId = id;
    return id;
  }

  async function runCell(cell: Cell): Promise<void> {
    if (cell.type !== 'command' || cell.status === 'running') return;
    cell.status = 'running';
    cell.output = '';
    cell.outputOpen = false;
    try {
      const sid = await ensureSession();
      const result = (await apiPost<{ output?: string; stdout?: string }>(
        `/sessions/${sid}/messages`,
        { content: cell.content, role: 'user' },
      )) as { output?: string; stdout?: string };
      cell.output = result.output ?? result.stdout ?? '(no output)';
      cell.status = 'success';
      cell.outputOpen = true;
    } catch (err) {
      cell.output = err instanceof Error ? err.message : 'Unknown error';
      cell.status = 'error';
      cell.outputOpen = true;
    }
  }

  let runningAll = $state(false);

  async function runAll(): Promise<void> {
    if (runningAll) return;
    runningAll = true;
    for (const cell of cells) {
      if (cell.type === 'command') {
        await runCell(cell);
        if (cell.status === 'error') break;
      }
    }
    runningAll = false;
  }

  function resetCell(cell: Cell): void {
    cell.status = 'idle';
    cell.output = '';
    cell.outputOpen = false;
  }

  function statusLabel(s: CellStatus): string {
    return s === 'idle' ? 'idle' : s === 'running' ? 'running' : s === 'success' ? 'done' : 'error';
  }
</script>

<div class="nbp-root">
  <!-- ── Empty / loading / error states ──────────────────────────────────── -->
  {#if $entryQ.isLoading}
    <div class="nbp-empty">
      <span class="nbp-empty-hint" style="font-style:italic">Loading notebook…</span>
    </div>

  {:else if $entryQ.isError || !entry}
    <div class="nbp-empty">
      <BookOpen size={28} class="nbp-empty-icon" aria-hidden="true" />
      <p class="nbp-empty-title">Notebook not found</p>
      <p class="nbp-empty-hint">No Drive entry matches <code>{notebookRef}</code>.</p>
    </div>

  {:else}
    <!-- ── Header ───────────────────────────────────────────────────────── -->
    <header class="nbp-header">
      <div class="nbp-header-left">
        <BookOpen size={14} aria-hidden="true" class="nbp-header-icon" />
        <span class="nbp-title">{entry.name}</span>
        <span class="nbp-meta">{commandCount} command{commandCount === 1 ? '' : 's'}</span>
      </div>
      <button
        class="nbp-run-all"
        onclick={runAll}
        disabled={runningAll || commandCount === 0}
        aria-label="Run all command cells"
      >
        <Play size={12} aria-hidden="true" />
        {runningAll ? 'Running…' : 'Run all'}
      </button>
    </header>

    <!-- ── Cell list ────────────────────────────────────────────────────── -->
    <div class="nbp-cells" role="list">
      {#each cells as cell (cell.id)}
        {#if cell.type === 'markdown'}
          <!-- Markdown cell -->
          <div class="nbp-cell nbp-cell--md" role="listitem">
            <div class="nbp-md-body">
              {@html renderMarkdown(cell.content)}
            </div>
          </div>

        {:else}
          <!-- Command cell -->
          <div
            class="nbp-cell nbp-cell--cmd"
            data-status={cell.status}
            role="listitem"
            aria-label="Command cell, status: {statusLabel(cell.status)}"
          >
            <div class="nbp-cmd-header">
              <span class="nbp-cmd-lang">{cell.lang}</span>
              <span class="nbp-status-pill nbp-status-pill--{cell.status}">
                {statusLabel(cell.status)}
              </span>
              <div class="nbp-cmd-actions">
                {#if cell.status !== 'idle'}
                  <button
                    class="nbp-icon-btn"
                    onclick={() => resetCell(cell)}
                    aria-label="Reset cell"
                    title="Reset"
                  >
                    <RotateCcw size={11} aria-hidden="true" />
                  </button>
                {/if}
                <button
                  class="nbp-run-btn"
                  onclick={() => runCell(cell)}
                  disabled={cell.status === 'running'}
                  aria-label="Run command"
                >
                  <Play size={12} aria-hidden="true" />
                  Run
                </button>
              </div>
            </div>

            <pre class="nbp-cmd-pre"><code>{cell.content}</code></pre>

            {#if cell.output}
              <div class="nbp-output-toggle">
                <button
                  class="nbp-output-btn"
                  onclick={() => { cell.outputOpen = !cell.outputOpen; }}
                  aria-expanded={cell.outputOpen}
                  aria-label={cell.outputOpen ? 'Collapse output' : 'Expand output'}
                >
                  {#if cell.outputOpen}
                    <ChevronDown size={11} aria-hidden="true" />
                  {:else}
                    <ChevronRight size={11} aria-hidden="true" />
                  {/if}
                  Output
                </button>
              </div>
              {#if cell.outputOpen}
                <pre class="nbp-output" data-status={cell.status}>{cell.output}</pre>
              {/if}
            {/if}
          </div>
        {/if}
      {/each}
    </div>
  {/if}
</div>

<style>
  .nbp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    overflow: hidden;
    background: var(--bg);
  }

  /* ── Empty / loading ──────────────────────────────────────────────────── */
  .nbp-empty {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3, 12px);
    padding: var(--space-8, 32px);
    text-align: center;
    font-family: var(--font-sans);
    color: var(--fg-subtle);
  }

  .nbp-empty-title {
    margin: 0;
    font-size: var(--text-sm, 13px);
    font-weight: 600;
    color: var(--fg-muted);
  }

  .nbp-empty-hint {
    margin: 0;
    font-size: var(--text-xs, 11px);
    color: var(--fg-subtle);
  }

  /* ── Header ───────────────────────────────────────────────────────────── */
  .nbp-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2, 8px) var(--space-3, 12px);
    border-bottom: 1px solid var(--border);
    background: var(--bg-elevated, var(--bg));
    flex-shrink: 0;
    gap: var(--space-2, 8px);
    font-family: var(--font-sans);
  }

  .nbp-header-left {
    display: flex;
    align-items: center;
    gap: var(--space-2, 8px);
    min-width: 0;
  }

  .nbp-title {
    font-size: var(--text-sm, 13px);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .nbp-meta {
    font-size: var(--text-xs, 11px);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .nbp-run-all {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 4px 10px;
    background: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 14%, transparent 86%);
    color: var(--signal-thinking, oklch(0.7 0.15 230));
    border: 1px solid color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 30%, transparent 70%);
    border-radius: var(--radius-sm, 4px);
    font-family: var(--font-sans);
    font-size: var(--text-xs, 11px);
    font-weight: 600;
    cursor: pointer;
    flex-shrink: 0;
    transition: opacity 0.1s ease;
  }

  .nbp-run-all:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  /* ── Cell list ─────────────────────────────────────────────────────────── */
  .nbp-cells {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-3, 12px);
    display: flex;
    flex-direction: column;
    gap: var(--space-3, 12px);
  }

  .nbp-cell {
    border-radius: var(--radius-md, 6px);
    overflow: hidden;
  }

  /* ── Markdown cell ─────────────────────────────────────────────────────── */
  .nbp-cell--md {
    padding: var(--space-1, 4px) var(--space-2, 8px);
  }

  .nbp-md-body {
    font-family: var(--font-sans);
    font-size: var(--text-sm, 13px);
    line-height: 1.65;
    color: var(--fg);
  }

  .nbp-md-body :global(h1) { font-size: 1.2em; font-weight: 700; margin: 0.75em 0 0.4em; color: var(--fg); }
  .nbp-md-body :global(h2) { font-size: 1.05em; font-weight: 700; margin: 0.6em 0 0.3em; color: var(--fg); }
  .nbp-md-body :global(h3) { font-size: 0.95em; font-weight: 700; margin: 0.5em 0 0.25em; color: var(--fg-muted); }
  .nbp-md-body :global(p)  { margin: 0.4em 0; }
  .nbp-md-body :global(li) { margin: 0.2em 0 0.2em 1.2em; list-style: disc; }
  .nbp-md-body :global(strong) { font-weight: 700; }
  .nbp-md-body :global(em) { font-style: italic; }
  .nbp-md-body :global(code) {
    font-family: var(--font-mono);
    font-size: 0.88em;
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    border-radius: 3px;
    padding: 1px 4px;
    color: var(--fg-muted);
  }

  /* ── Command cell ──────────────────────────────────────────────────────── */
  .nbp-cell--cmd {
    border: 1px solid var(--border);
    background: var(--bg-elevated, var(--bg));
    transition: border-color 0.1s ease;
  }

  .nbp-cell--cmd[data-status='running'] {
    border-color: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 50%, var(--border) 50%);
  }

  .nbp-cell--cmd[data-status='success'] {
    border-color: color-mix(in oklch, var(--signal-success, oklch(0.65 0.18 145)) 40%, var(--border) 60%);
  }

  .nbp-cell--cmd[data-status='error'] {
    border-color: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 40%, var(--border) 60%);
  }

  .nbp-cmd-header {
    display: flex;
    align-items: center;
    gap: var(--space-2, 8px);
    padding: 5px var(--space-3, 12px);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 70%, transparent 30%);
    font-family: var(--font-mono);
  }

  .nbp-cmd-lang {
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: lowercase;
    letter-spacing: 0.03em;
  }

  .nbp-cmd-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1, 4px);
    margin-left: auto;
  }

  .nbp-status-pill {
    display: inline-flex;
    align-items: center;
    padding: 1px 6px;
    border-radius: 999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg-subtle);
  }

  .nbp-status-pill--running {
    background: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 14%, transparent 86%);
    color: var(--signal-thinking, oklch(0.7 0.15 230));
    animation: nbp-pulse 1.4s ease-in-out infinite;
  }

  .nbp-status-pill--success {
    background: color-mix(in oklch, var(--signal-success, oklch(0.65 0.18 145)) 14%, transparent 86%);
    color: var(--signal-success, oklch(0.65 0.18 145));
  }

  .nbp-status-pill--error {
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 18%, transparent 82%);
    color: var(--signal-error, oklch(0.55 0.22 25));
  }

  @keyframes nbp-pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  .nbp-icon-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    padding: 0;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm, 4px);
    color: var(--fg-subtle);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }

  .nbp-icon-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .nbp-run-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 8px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 4px);
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease, border-color 0.1s ease;
  }

  .nbp-run-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 10%, transparent 90%);
    color: var(--signal-thinking, oklch(0.7 0.15 230));
    border-color: color-mix(in oklch, var(--signal-thinking, oklch(0.7 0.15 230)) 35%, transparent 65%);
  }

  .nbp-run-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .nbp-cmd-pre {
    margin: 0;
    padding: var(--space-3, 12px);
    font-family: var(--font-mono);
    font-size: var(--text-xs, 11px);
    line-height: 1.6;
    color: var(--fg);
    background: transparent;
    overflow-x: auto;
    white-space: pre;
  }

  /* ── Output area ───────────────────────────────────────────────────────── */
  .nbp-output-toggle {
    border-top: 1px solid color-mix(in oklch, var(--border) 60%, transparent 40%);
    padding: 3px var(--space-2, 8px);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 50%, transparent 50%);
  }

  .nbp-output-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: transparent;
    border: none;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    cursor: pointer;
    padding: 2px 4px;
    border-radius: var(--radius-sm, 4px);
    transition: color 0.1s ease;
  }

  .nbp-output-btn:hover { color: var(--fg); }

  .nbp-output {
    margin: 0;
    padding: var(--space-3, 12px);
    font-family: var(--font-mono);
    font-size: var(--text-xs, 11px);
    line-height: 1.5;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--bg-inset, var(--bg)) 80%, transparent 20%);
    overflow-x: auto;
    white-space: pre-wrap;
    word-break: break-all;
    border-top: 1px solid color-mix(in oklch, var(--border) 40%, transparent 60%);
  }

  .nbp-output[data-status='error'] {
    color: var(--signal-error, oklch(0.55 0.22 25));
  }
</style>
