<script lang="ts">
  /**
   * TypedTranscript — renders typed blocks from GET /runs/:id/transcript.
   *
   * Displays each block with a distinct icon and background tint per kind:
   *   user_prompt         → speech bubble icon, accent tint
   *   permission_request  → shield icon, amber tint
   *   tool_call           → terminal icon, neutral
   *   tool_result         → check icon, muted
   *   thinking            → eye icon, subtle
   *   stdout / stderr     → text, mono
   *   exit                → power icon, faint
   *
   * CSS prefix: tt- (TypedTranscript)
   * LOC target: ≤ 200.
   */

  import type { TranscriptBlock, TranscriptBlockKind } from '$lib/api/queries/runs.js';

  interface Props {
    blocks: TranscriptBlock[];
    isLoading?: boolean;
    error?: string | null;
  }

  const { blocks, isLoading = false, error = null }: Props = $props();

  // ── Block metadata ─────────────────────────────────────────────────────────

  const KIND_META: Record<TranscriptBlockKind, { label: string; icon: string; css: string }> = {
    user_prompt:        { label: 'Prompt',      icon: '💬', css: 'tt-block--prompt' },
    permission_request: { label: 'Permission',  icon: '🔐', css: 'tt-block--permission' },
    tool_call:          { label: 'Tool call',   icon: '⚙️', css: 'tt-block--tool-call' },
    tool_result:        { label: 'Tool result', icon: '✓',  css: 'tt-block--tool-result' },
    thinking:           { label: 'Thinking',    icon: '◉',  css: 'tt-block--thinking' },
    stdout:             { label: 'Output',      icon: '▸',  css: 'tt-block--stdout' },
    stderr:             { label: 'Error',       icon: '✗',  css: 'tt-block--stderr' },
    exit:               { label: 'Exit',        icon: '◼',  css: 'tt-block--exit' },
  };

  function metaFor(kind: TranscriptBlockKind) {
    return KIND_META[kind] ?? { label: kind, icon: '·', css: '' };
  }

  function payloadText(block: TranscriptBlock): string {
    const p = block.payload;
    if (typeof p['data'] === 'string') return p['data'];
    if (typeof p['prompt'] === 'string') return p['prompt'];
    if (typeof p['tool_name'] === 'string') {
      const params = p['params'] ? JSON.stringify(p['params'], null, 2) : '';
      return params ? `${p['tool_name']}\n${params}` : String(p['tool_name']);
    }
    if (typeof p['result'] === 'object' && p['result'] !== null) return JSON.stringify(p['result'], null, 2);
    return JSON.stringify(p, null, 2);
  }

  function formatAt(iso: string): string {
    if (!iso) return '';
    try { return new Date(iso).toLocaleTimeString(); } catch { return iso; }
  }
</script>

<div class="tt-root" aria-label="Run transcript">
  {#if isLoading}
    <p class="tt-empty">Loading transcript…</p>
  {:else if error}
    <p class="tt-empty tt-empty--error">{error}</p>
  {:else if blocks.length === 0}
    <p class="tt-empty">No transcript blocks yet.</p>
  {:else}
    {#each blocks as block (block.at + block.kind)}
      {@const meta = metaFor(block.kind)}
      <div class="tt-block {meta.css}" role="listitem">
        <div class="tt-block-header" aria-label="{meta.label}">
          <span class="tt-icon" aria-hidden="true">{meta.icon}</span>
          <span class="tt-kind-label">{meta.label}</span>
          {#if block.at}
            <time class="tt-ts" datetime={block.at}>{formatAt(block.at)}</time>
          {/if}
        </div>
        <pre class="tt-payload">{payloadText(block)}</pre>
      </div>
    {/each}
  {/if}
</div>

<style>
  .tt-root {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: var(--space-2) 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .tt-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    padding: var(--space-4) var(--space-3);
    text-align: center;
  }

  .tt-empty--error { color: oklch(0.55 0.25 25); }

  .tt-block {
    border-radius: var(--radius-md);
    border: 1px solid transparent;
    overflow: hidden;
    transition: background 0.1s ease;
  }

  .tt-block-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: 3px var(--space-3);
    border-bottom: 1px solid color-mix(in oklch, var(--border) 60%, transparent);
  }

  .tt-icon {
    font-size: 10px;
    flex-shrink: 0;
    width: 14px;
    text-align: center;
  }

  .tt-kind-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    flex: 1;
  }

  .tt-ts {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .tt-payload {
    margin: 0;
    padding: var(--space-2) var(--space-3);
    white-space: pre-wrap;
    word-break: break-word;
    color: var(--fg);
    font-size: var(--text-xs);
    line-height: 1.6;
    max-height: 200px;
    overflow-y: auto;
  }

  /* Per-kind tints */
  .tt-block--prompt     { background: color-mix(in oklch, oklch(0.85 0.18 55) 8%, transparent);  border-color: color-mix(in oklch, oklch(0.85 0.18 55) 25%, transparent); }
  .tt-block--permission { background: color-mix(in oklch, oklch(0.80 0.20 60) 10%, transparent); border-color: color-mix(in oklch, oklch(0.80 0.20 60) 30%, transparent); }
  .tt-block--tool-call  { background: var(--bg-inset); border-color: var(--border); }
  .tt-block--tool-result{ background: color-mix(in oklch, oklch(0.75 0.18 145) 6%, transparent); border-color: color-mix(in oklch, oklch(0.75 0.18 145) 20%, transparent); }
  .tt-block--thinking   { background: color-mix(in oklch, oklch(0.70 0.10 270) 6%, transparent); border-color: color-mix(in oklch, oklch(0.70 0.10 270) 20%, transparent); }
  .tt-block--stdout     { background: transparent; border-color: transparent; }
  .tt-block--stderr     { background: color-mix(in oklch, oklch(0.65 0.25 25) 6%, transparent);  border-color: color-mix(in oklch, oklch(0.65 0.25 25) 20%, transparent); }
  .tt-block--exit       { background: color-mix(in oklch, var(--fg) 4%, transparent); border-color: var(--border); }
</style>
