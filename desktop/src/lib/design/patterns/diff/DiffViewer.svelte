<script lang="ts">
  /**
   * DiffViewer — renders a single DiffFile with hunk collapsing and syntax highlighting.
   * Uses shiki for highlighting (confirmed installed at ^4.0.2).
   * CSS prefix: dv-
   * LOC target: ≤ 260.
   */
  import { Copy } from 'lucide-svelte';
  import { onMount } from 'svelte';
  import type { DiffFile, DiffHunk, DiffLine } from '$lib/utils/parse-diff.js';

  interface Props {
    file: DiffFile;
  }

  let { file }: Props = $props();

  // ── View mode ────────────────────────────────────────────────────────────────

  const STORAGE_KEY = 'canopy.diff.view_mode';
  let viewMode = $state<'inline' | 'side-by-side'>(
    typeof localStorage !== 'undefined'
      ? ((localStorage.getItem(STORAGE_KEY) as 'inline' | 'side-by-side') ?? 'inline')
      : 'inline',
  );

  function setViewMode(m: 'inline' | 'side-by-side'): void {
    viewMode = m;
    if (typeof localStorage !== 'undefined') localStorage.setItem(STORAGE_KEY, m);
  }

  // ── Hunk collapse ─────────────────────────────────────────────────────────────

  let collapsedHunks = $state<Set<number>>(new Set());
  function toggleHunk(i: number): void {
    const next = new Set(collapsedHunks);
    if (next.has(i)) next.delete(i);
    else next.add(i);
    collapsedHunks = next;
  }

  // ── Shiki highlight ──────────────────────────────────────────────────────────

  // Map file extension → shiki language id
  function langFromPath(path: string): string {
    const ext = path.split('.').pop()?.toLowerCase() ?? '';
    const map: Record<string, string> = {
      ts: 'typescript', tsx: 'tsx', js: 'javascript', jsx: 'jsx',
      svelte: 'svelte', css: 'css', html: 'html', json: 'json',
      md: 'markdown', ex: 'elixir', exs: 'elixir', rs: 'rust',
      go: 'go', py: 'python', sh: 'bash', yaml: 'yaml', yml: 'yaml',
      toml: 'toml', sql: 'sql',
    };
    return map[ext] ?? 'text';
  }

  // Highlighted line cache: hunk index → line index → html string
  let highlightedLines = $state<Map<string, string>>(new Map());
  let shikiReady = $state(false);

  onMount(async () => {
    try {
      const { createHighlighter } = await import('shiki');
      const hl = await createHighlighter({
        themes: ['github-dark-dimmed'],
        langs: [langFromPath(file.path)],
      });
      const lang = langFromPath(file.path);

      // Collect all content lines to highlight
      const next = new Map<string, string>();
      for (let hi = 0; hi < file.hunks.length; hi++) {
        const hunk = file.hunks[hi];
        if (!hunk) continue;
        for (let li = 0; li < hunk.lines.length; li++) {
          const dl = hunk.lines[li];
          if (!dl || dl.type === 'hunk_header') continue;
          const key = `${hi}:${li}`;
          const tokens = hl.codeToHtml(dl.content, { lang, theme: 'github-dark-dimmed' });
          // Extract just the inner code span from shiki output
          const inner = tokens.replace(/^<pre[^>]*><code[^>]*>([\s\S]*)<\/code><\/pre>$/, '$1');
          next.set(key, inner);
        }
      }
      highlightedLines = next;
      shikiReady = true;
    } catch {
      // shiki failed — fallback to mono text, shikiReady stays false
    }
  });

  function lineHtml(hunkIdx: number, lineIdx: number, content: string): string {
    const key = `${hunkIdx}:${lineIdx}`;
    return highlightedLines.get(key) ?? escapeHtml(content);
  }

  function escapeHtml(s: string): string {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // ── Copy hunk ─────────────────────────────────────────────────────────────────

  function copyHunk(hunk: DiffHunk): void {
    const text = hunk.lines.map((l) => l.content).join('\n');
    void navigator.clipboard.writeText(text);
  }

  // ── Line bg ───────────────────────────────────────────────────────────────────

  function lineBg(type: DiffLine['type']): string {
    if (type === 'add') return 'color-mix(in oklch, var(--success, oklch(0.72 0.18 145)) 15%, transparent)';
    if (type === 'del') return 'color-mix(in oklch, var(--destructive, oklch(0.65 0.22 25)) 15%, transparent)';
    return 'transparent';
  }
</script>

<!-- Toolbar -->
<div class="dv-toolbar">
  <span class="dv-filepath">{file.path}</span>
  <div class="dv-view-toggle" role="group" aria-label="View mode">
    {#each (['inline', 'side-by-side'] as const) as mode (mode)}
      <button
        class="dv-toggle-btn"
        class:dv-toggle-btn--active={viewMode === mode}
        onclick={() => setViewMode(mode)}
        aria-pressed={viewMode === mode}
      >
        {mode === 'inline' ? 'Inline' : 'Side by side'}
      </button>
    {/each}
  </div>
</div>

<!-- Binary -->
{#if file.binary}
  <div class="dv-binary-notice">Binary file — no diff available.</div>
{:else}
  <div class="dv-hunks">
    {#each file.hunks as hunk, hi (hi)}
      {@const isCollapsed = collapsedHunks.has(hi)}
      <!-- Hunk header -->
      <div class="dv-hunk-header">
        <button
          class="dv-hunk-toggle"
          onclick={() => toggleHunk(hi)}
          aria-expanded={!isCollapsed}
          aria-label={isCollapsed ? 'Expand hunk' : 'Collapse hunk'}
        >
          <span class="dv-hunk-caret" aria-hidden="true">{isCollapsed ? '▶' : '▼'}</span>
          <span class="dv-hunk-label">{hunk.header}</span>
        </button>
        <button
          class="dv-copy-btn"
          onclick={() => copyHunk(hunk)}
          aria-label="Copy hunk to clipboard"
          title="Copy hunk"
        >
          <Copy size={11} aria-hidden="true" />
        </button>
      </div>

      {#if !isCollapsed}
        <table class="dv-table" class:dv-table--side={viewMode === 'side-by-side'}>
          <tbody>
            {#each hunk.lines as dl, li (li)}
              {#if dl.type === 'hunk_header'}
                <!-- skip — rendered above -->
              {:else if viewMode === 'inline'}
                <tr class="dv-line" style:background={lineBg(dl.type)}>
                  <td class="dv-lineno dv-lineno-old">{dl.oldLineNo ?? ''}</td>
                  <td class="dv-lineno dv-lineno-new">{dl.newLineNo ?? ''}</td>
                  <td class="dv-sign"
                    class:dv-sign-add={dl.type === 'add'}
                    class:dv-sign-del={dl.type === 'del'}
                  >{dl.type === 'add' ? '+' : dl.type === 'del' ? '−' : ' '}</td>
                  <td class="dv-code">
                    <!-- eslint-disable-next-line svelte/no-at-html-tags -->
                    {@html lineHtml(hi, li, dl.content)}
                  </td>
                </tr>
              {:else}
                <!-- Side-by-side: old on left, new on right -->
                {#if dl.type === 'del'}
                  <tr class="dv-line" style:background={lineBg('del')}>
                    <td class="dv-lineno dv-lineno-old">{dl.oldLineNo ?? ''}</td>
                    <td class="dv-sign dv-sign-del">−</td>
                    <td class="dv-code">{@html lineHtml(hi, li, dl.content)}</td>
                    <td class="dv-lineno dv-lineno-new"></td>
                    <td class="dv-sign"></td>
                    <td class="dv-code dv-code-empty"></td>
                  </tr>
                {:else if dl.type === 'add'}
                  <tr class="dv-line" style:background={lineBg('add')}>
                    <td class="dv-lineno dv-lineno-old"></td>
                    <td class="dv-sign"></td>
                    <td class="dv-code dv-code-empty"></td>
                    <td class="dv-lineno dv-lineno-new">{dl.newLineNo ?? ''}</td>
                    <td class="dv-sign dv-sign-add">+</td>
                    <td class="dv-code">{@html lineHtml(hi, li, dl.content)}</td>
                  </tr>
                {:else}
                  <tr class="dv-line">
                    <td class="dv-lineno dv-lineno-old">{dl.oldLineNo ?? ''}</td>
                    <td class="dv-sign"></td>
                    <td class="dv-code">{@html lineHtml(hi, li, dl.content)}</td>
                    <td class="dv-lineno dv-lineno-new">{dl.newLineNo ?? ''}</td>
                    <td class="dv-sign"></td>
                    <td class="dv-code">{@html lineHtml(hi, li, dl.content)}</td>
                  </tr>
                {/if}
              {/if}
            {/each}
          </tbody>
        </table>
      {/if}
    {/each}
  </div>
{/if}

<style>
  .dv-toolbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-2);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .dv-filepath {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
    min-width: 0;
  }

  .dv-view-toggle {
    display: flex;
    gap: 2px;
    flex-shrink: 0;
  }

  .dv-toggle-btn {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 2px 6px;
    cursor: pointer;
    transition: color 0.1s ease, background 0.1s ease;
  }
  .dv-toggle-btn--active {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 10%, transparent);
    border-color: var(--fg-subtle);
  }
  .dv-toggle-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .dv-binary-notice {
    padding: var(--space-6);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-align: center;
    font-style: italic;
  }

  .dv-hunks {
    flex: 1;
    overflow-y: auto;
    overflow-x: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .dv-hunk-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 var(--space-2);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    border-top: 1px solid var(--border);
    border-bottom: 1px solid var(--border);
    position: sticky;
    top: 0;
    z-index: 1;
  }

  .dv-hunk-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex: 1;
    background: transparent;
    border: none;
    cursor: pointer;
    padding: var(--space-1) 0;
    text-align: left;
  }

  .dv-hunk-caret {
    font-size: 8px;
    color: var(--fg-subtle);
    flex-shrink: 0;
    user-select: none;
  }

  .dv-hunk-label {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .dv-copy-btn {
    display: flex;
    align-items: center;
    background: transparent;
    border: none;
    cursor: pointer;
    color: var(--fg-subtle);
    padding: var(--space-1);
    border-radius: var(--radius-sm);
    transition: color 0.1s ease;
    flex-shrink: 0;
  }
  .dv-copy-btn:hover { color: var(--fg); }
  .dv-copy-btn:focus-visible { outline: 2px solid var(--cnp-accent); }

  .dv-table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.5;
  }

  .dv-line { vertical-align: top; }

  .dv-lineno {
    user-select: none;
    padding: 0 var(--space-2);
    min-width: 42px;
    color: var(--fg-subtle);
    text-align: right;
    border-right: 1px solid var(--border);
    white-space: nowrap;
  }

  .dv-sign {
    width: 16px;
    padding: 0 4px;
    color: var(--fg-subtle);
    text-align: center;
    user-select: none;
    white-space: nowrap;
  }
  .dv-sign-add { color: var(--success, oklch(0.72 0.18 145)); }
  .dv-sign-del { color: var(--destructive, oklch(0.65 0.22 25)); }

  .dv-code {
    padding: 0 var(--space-2);
    white-space: pre;
    color: var(--fg);
    width: 100%;
  }

  .dv-code-empty {
    background: color-mix(in oklch, var(--border) 30%, transparent);
  }

  /* Side-by-side: split halves */
  .dv-table--side .dv-code { width: 50%; }
</style>
