<script lang="ts">
/**
 * PaneContent — dispatches to the right component based on pane.kind.
 * CSS prefix: pc-
 * LOC target: ≤ 180.
 */

import { createSession, getSession } from '$lib/api/queries/sessions.js';
import TerminalSession from '$lib/design/patterns/TerminalSession.svelte';
import { mosaicLayout, type Pane } from '$lib/stores/mosaic-layout.svelte.js';

interface Props {
  pane: Pane;
}

let { pane }: Props = $props();

// Lazy-import heavy components to keep initial bundle small.
// IssueDetailMain/Sidebar, FilePreview, TiptapEditor are only loaded when needed.

// Knowledge pane stub data
type KnowledgeChunk = { id: string; title: string; preview: string };
const knowledgeChunks: KnowledgeChunk[] = [
  { id: '1', title: 'Getting started', preview: 'A brief guide to using the workspace…' },
  { id: '2', title: 'Keyboard shortcuts', preview: 'Full reference for all keyboard shortcuts…' },
];

// ── Local terminal: spawn an interactive claude-local session on first mount.
// The Mosaic "terminal" pane reuses every other runtime's channel — same
// wire-up as /sessions/[id], just without the harness chrome. Caches the
// session ID on pane.ref so remounts reattach to the same pty.
let terminalSessionId = $state<string | null>(null);
let terminalError = $state<string | null>(null);

$effect(() => {
  if (pane.kind !== 'terminal') return;

  let cancelled = false;

  const hasCachedUuid =
    !!pane.ref && pane.ref !== 'local-shell' && pane.ref !== 'local' && pane.ref.length > 20;

  async function spawnFresh(): Promise<void> {
    try {
      const s = (await createSession({
        runtimeType: 'claude-local',
        workspaceSlug: 'default',
        cwd: '~',
      })) as unknown as { id?: string; sessionId?: string };
      if (cancelled) return;
      const id = s.sessionId ?? s.id;
      if (!id) {
        terminalError = 'Session spawn returned no id';
        return;
      }
      terminalSessionId = id;
      pane.ref = id;
      mosaicLayout.save();
    } catch (err) {
      if (!cancelled) {
        terminalError = err instanceof Error ? err.message : 'Failed to spawn terminal session';
      }
    }
  }

  (async () => {
    if (hasCachedUuid) {
      // Verify the cached session still exists. If backend returns 404
      // (session cleaned up, DB rebuilt, etc.), respawn fresh.
      try {
        await getSession(pane.ref);
        if (cancelled) return;
        terminalSessionId = pane.ref;
        return;
      } catch {
        // Stale cache — fall through to fresh spawn.
        pane.ref = 'local';
        mosaicLayout.save();
      }
    }
    if (!cancelled) {
      terminalError = null;
      terminalSessionId = null;
      await spawnFresh();
    }
  })();

  return () => {
    cancelled = true;
  };
});
</script>

<div class="pc-root">
  {#if pane.kind === 'session'}
    <TerminalSession sessionId={pane.ref} isRunning={true} />

  {:else if pane.kind === 'terminal'}
    {#if terminalError}
      <div class="pc-stub">Terminal failed to start: {terminalError}</div>
    {:else if !terminalSessionId}
      <div class="pc-stub pc-stub--loading">Spawning terminal…</div>
    {:else}
      <TerminalSession sessionId={terminalSessionId} isRunning={true} />
    {/if}

  {:else if pane.kind === 'changes'}
    {#await import('$lib/design/patterns/diff/ChangesPanel.svelte')}
      <div class="pc-stub pc-stub--loading">Loading diff panel…</div>
    {:then { default: ChangesPanel }}
      <ChangesPanel sessionId={pane.ref} />
    {:catch}
      <div class="pc-stub">Diff panel not ready.</div>
    {/await}

  {:else if pane.kind === 'issue'}
    <div class="pc-stub pc-stub--issue">
      <p class="pc-stub__label">Issue {pane.ref}</p>
      <p class="pc-stub__hint">Full issue detail available in the Issues module (/issues/{pane.ref}).</p>
    </div>

  {:else if pane.kind === 'task'}
    <div class="pc-task">
      <h2 class="pc-task__title">{pane.title}</h2>
      <p class="pc-task__ref">Ref: {pane.ref}</p>
      <div class="pc-task__status">Status: open</div>
    </div>

  {:else if pane.kind === 'doc'}
    {#await import('$lib/design/patterns/TiptapEditor.svelte')}
      <div class="pc-stub pc-stub--loading">Loading doc editor…</div>
    {:then}
      <div class="pc-stub">Doc viewer for {pane.ref}</div>
    {:catch}
      <div class="pc-stub">Doc editor not available.</div>
    {/await}

  {:else if pane.kind === 'file'}
    {#await import('$lib/design/patterns/FilePreview.svelte')}
      <div class="pc-stub pc-stub--loading">Loading file preview…</div>
    {:then}
      <div class="pc-stub">File preview for {pane.ref} requires a FileRecord object. Open via the Files module.</div>
    {:catch}
      <div class="pc-stub">File preview not available.</div>
    {/await}

  {:else if pane.kind === 'knowledge'}
    <div class="pc-knowledge">
      <h2 class="pc-knowledge__heading">Knowledge</h2>
      <ul class="pc-knowledge__list">
        {#each knowledgeChunks as chunk (chunk.id)}
          <li class="pc-knowledge__item">
            <span class="pc-knowledge__title">{chunk.title}</span>
            <span class="pc-knowledge__preview">{chunk.preview}</span>
          </li>
        {/each}
      </ul>
    </div>

  {:else if pane.kind === 'agent_conversation'}
    {#await import('$lib/design/patterns/mosaic/panes/AgentConversationPane.svelte')}
      <div class="pc-stub pc-stub--loading">Loading conversation…</div>
    {:then { default: AgentConversationPane }}
      {@const cfg = (pane.config ?? {}) as { sessionId?: string; cwd?: string; model?: string }}
      {@const tile = mosaicLayout.allTiles().find((t) => t.panes.some((p) => p.id === pane.id))}
      <AgentConversationPane
        sessionId={cfg.sessionId ?? (pane.ref && pane.ref !== 'new' && pane.ref.length > 8 ? pane.ref : undefined)}
        workspaceSlug="default"
        cwd={cfg.cwd ?? '~'}
        model={cfg.model ?? 'auto (cost-efficient)'}
        paneId={pane.id}
        tileId={tile?.id}
      />
    {:catch}
      <div class="pc-stub">Conversation pane failed to load.</div>
    {/await}

  {:else if pane.kind === 'agent_kanban'}
    {#await import('$lib/design/patterns/mosaic/panes/AgentKanbanPane.svelte')}
      <div class="pc-stub pc-stub--loading">Loading kanban…</div>
    {:then { default: AgentKanbanPane }}
      {@const cfg = (pane.config ?? {}) as { workspaceSlug?: string }}
      <AgentKanbanPane workspaceSlug={cfg.workspaceSlug ?? 'default'} />
    {:catch}
      <div class="pc-stub">Agent Kanban pane failed to load.</div>
    {/await}

  {:else if pane.kind === 'block_stream'}
    {#await import('$lib/design/patterns/blocks/BlockStream.svelte')}
      <div class="pc-stub pc-stub--loading">Loading blocks…</div>
    {:then { default: BlockStream }}
      <BlockStream sessionId={pane.ref} />
    {:catch}
      <div class="pc-stub">Block stream pane failed to load.</div>
    {/await}

  {:else if pane.kind === 'workflow'}
    {#await import('$lib/design/patterns/mosaic/panes/WorkflowPane.svelte')}
      <div class="pc-stub pc-stub--loading">Loading workflow…</div>
    {:then { default: WorkflowPane }}
      <WorkflowPane workflowRef={pane.ref} workspaceSlug="default" />
    {:catch}
      <div class="pc-stub">Workflow pane failed to load.</div>
    {/await}

  {:else if pane.kind === 'notebook'}
    {#await import('$lib/design/patterns/mosaic/panes/NotebookPane.svelte')}
      <div class="pc-stub pc-stub--loading">Loading notebook…</div>
    {:then { default: NotebookPane }}
      <NotebookPane notebookRef={pane.ref} workspaceSlug="default" />
    {:catch}
      <div class="pc-stub">Notebook pane failed to load.</div>
    {/await}

  {:else if pane.kind === 'history'}
    {#await import('$lib/design/patterns/mosaic/panes/HistoryPane.svelte')}
      <div class="pc-stub pc-stub--loading">Loading history…</div>
    {:then { default: HistoryPane }}
      <HistoryPane workspaceSlug="default" />
    {:catch}
      <div class="pc-stub">History pane failed to load.</div>
    {/await}
  {/if}
</div>

<style>
  .pc-root {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    overflow: hidden;
    height: 100%;
  }

  .pc-stub {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-6, 24px);
    font-size: var(--text-sm);
    font-family: var(--font-sans);
    color: var(--fg-subtle);
    text-align: center;
    flex-direction: column;
    gap: 8px;
  }

  .pc-stub--loading { font-style: italic; }

  .pc-stub__label {
    font-weight: 600;
    color: var(--fg-muted);
    margin: 0;
  }
  .pc-stub__hint { margin: 0; }

  .pc-task {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 8px;
    font-family: var(--font-sans);
  }
  .pc-task__title {
    font-size: var(--text-lg, 18px);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }
  .pc-task__ref, .pc-task__status {
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .pc-knowledge {
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    overflow-y: auto;
    flex: 1;
  }
  .pc-knowledge__heading {
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    font-family: var(--font-sans);
  }
  .pc-knowledge__list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  .pc-knowledge__item {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 10px 12px;
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    font-family: var(--font-sans);
  }
  .pc-knowledge__title {
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }
  .pc-knowledge__preview {
    font-size: 11px;
    color: var(--fg-subtle);
  }
</style>
