<script lang="ts">
  import {
    Bot,
    Braces,
    FileText,
    GitPullRequest,
    GripHorizontal,
    Maximize2,
    Minimize2,
    Network,
    Terminal,
    X,
  } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import TerminalSession from '$lib/design/patterns/TerminalSession.svelte';
  import AgentConversationPane from '$lib/design/patterns/mosaic/panes/AgentConversationPane.svelte';
  import ChangesPanel from '$lib/design/patterns/diff/ChangesPanel.svelte';
  import GitChangesPanel from '$lib/design/patterns/review/GitChangesPanel.svelte';
  import WorkbenchModuleRenderer from './WorkbenchModuleRenderer.svelte';
  import FileTree from '$lib/design/foundation/file-tree/FileTree.svelte';
  import { createSession } from '$lib/api/queries/sessions.js';

  export type WorkbenchTileKind =
    | 'terminal'
    | 'agent'
    | 'git'
    | 'files'
    | 'mission'
    | 'tmux'
    | 'module';

  export interface WorkbenchTileModel {
    id: string;
    kind: WorkbenchTileKind;
    title: string;
    subtitle: string;
    x: number;
    y: number;
    w: number;
    h: number;
    z?: number;
    restore?: { x: number; y: number; w: number; h: number };
    sessionId?: string;
    error?: string;
    route?: string;
    panes?: WorkbenchPaneModel[];
  }

  export type WorkbenchPaneKind = 'terminal' | 'agent' | 'git' | 'files';

  export interface WorkbenchPaneModel {
    id: string;
    kind: WorkbenchPaneKind;
    title: string;
    x?: number;
    y?: number;
    w?: number;
    h?: number;
    sessionId?: string;
    error?: string;
  }

  interface Props {
    tile: WorkbenchTileModel;
    selected: boolean;
    scale: number;
    workspaceSlug: string;
    rootPath: string;
    runtimeType: string;
    linkedSessionId: string | null;
    onSelect: (id: string) => void;
    onMove: (id: string, x: number, y: number) => void;
    onResize: (id: string, x: number, y: number, w: number, h: number) => void;
    onRemove: (id: string) => void;
    onToggleMaximize: (id: string) => void;
    onPatch: (id: string, patch: Partial<WorkbenchTileModel>) => void;
    onAddTile: (kind: WorkbenchTileKind, patch?: Partial<WorkbenchTileModel>) => void;
  }

  let {
    tile,
    selected,
    scale,
    workspaceSlug,
    rootPath,
    runtimeType,
    linkedSessionId,
    onSelect,
    onMove,
    onResize,
    onRemove,
    onToggleMaximize,
    onPatch,
    onAddTile,
  }: Props = $props();

  let dragStart = $state<{ px: number; py: number; x: number; y: number } | null>(null);
  let resizeStart = $state<{
    px: number;
    py: number;
    x: number;
    y: number;
    w: number;
    h: number;
    direction: ResizeDirection;
  } | null>(null);
  let starting = $state(false);
  let startingPaneId = $state('');
  let paneDragStart = $state<{ id: string; px: number; py: number; x: number; y: number } | null>(null);
  let paneResizeStart = $state<{ id: string; px: number; py: number; w: number; h: number } | null>(null);
  type ResizeDirection = 'n' | 'e' | 's' | 'w' | 'ne' | 'nw' | 'se' | 'sw';

  function iconFor(kind: WorkbenchTileKind): typeof Terminal {
    if (kind === 'agent') return Bot;
    if (kind === 'git') return GitPullRequest;
    if (kind === 'files') return FileText;
    if (kind === 'mission') return Network;
    if (kind === 'tmux') return Braces;
    if (kind === 'module') return Braces;
    return Terminal;
  }

  function beginDrag(event: PointerEvent): void {
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
    dragStart = { px: event.clientX, py: event.clientY, x: tile.x, y: tile.y };
    onSelect(tile.id);
  }

  function moveDrag(event: PointerEvent): void {
    if (!dragStart) return;
    const dx = (event.clientX - dragStart.px) / scale;
    const dy = (event.clientY - dragStart.py) / scale;
    onMove(tile.id, Math.round(dragStart.x + dx), Math.round(dragStart.y + dy));
  }

  function endDrag(event: PointerEvent): void {
    if (!dragStart) return;
    try {
      (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
    } catch {
      // Pointer may have ended on window after a fast drag.
    }
    dragStart = null;
  }

  function beginResize(event: PointerEvent, direction: ResizeDirection): void {
    event.preventDefault();
    event.stopPropagation();
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
    resizeStart = { px: event.clientX, py: event.clientY, x: tile.x, y: tile.y, w: tile.w, h: tile.h, direction };
    onSelect(tile.id);
  }

  function moveResize(event: PointerEvent): void {
    if (!resizeStart) return;
    const dw = (event.clientX - resizeStart.px) / scale;
    const dh = (event.clientY - resizeStart.py) / scale;
    const minW = 260;
    const minH = 180;
    let nextX = resizeStart.x;
    let nextY = resizeStart.y;
    let nextW = resizeStart.w;
    let nextH = resizeStart.h;
    if (resizeStart.direction.includes('e')) nextW = Math.max(minW, resizeStart.w + dw);
    if (resizeStart.direction.includes('s')) nextH = Math.max(minH, resizeStart.h + dh);
    if (resizeStart.direction.includes('w')) {
      nextW = Math.max(minW, resizeStart.w - dw);
      nextX = resizeStart.x + (resizeStart.w - nextW);
    }
    if (resizeStart.direction.includes('n')) {
      nextH = Math.max(minH, resizeStart.h - dh);
      nextY = resizeStart.y + (resizeStart.h - nextH);
    }
    onResize(tile.id, Math.round(nextX), Math.round(nextY), Math.round(nextW), Math.round(nextH));
  }

  function endResize(event: PointerEvent): void {
    if (!resizeStart) return;
    try {
      (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
    } catch {
      // Pointer may have ended on window after a fast resize.
    }
    resizeStart = null;
  }

  const Icon = $derived(iconFor(tile.kind));
  const effectiveSessionId = $derived(tile.sessionId ?? linkedSessionId);

  async function startTerminal(): Promise<void> {
    if (starting || tile.sessionId) return;
    starting = true;
    onPatch(tile.id, { error: undefined });
    try {
      const session = await createSession({
        runtimeType,
        workspaceSlug,
        cwd: rootPath,
        prompt: '',
        kind: 'terminal',
        interactive: true,
      });
      const sessionId = (session as unknown as { sessionId?: string; id?: string }).sessionId
        ?? (session as unknown as { id?: string }).id;
      if (!sessionId) throw new Error('Session created without an id');
      onPatch(tile.id, {
        sessionId,
        subtitle: `session ${sessionId.slice(0, 8)}`,
      });
    } catch (err) {
      onPatch(tile.id, {
        error: err instanceof Error ? err.message : 'Failed to start terminal',
      });
    } finally {
      starting = false;
    }
  }

  function openSession(): void {
    if (tile.sessionId) void goto(`/sessions/${tile.sessionId}`);
  }

  function addPane(kind: WorkbenchPaneKind): void {
    const panes = tile.panes ?? [];
    const index = panes.length;
    onPatch(tile.id, {
      panes: [
        ...panes,
        {
          id: `${kind}-${Math.random().toString(36).slice(2, 8)}`,
          kind,
          title: kind === 'terminal' ? 'Terminal' : kind === 'agent' ? 'Agent' : kind === 'git' ? 'Git' : 'Files',
          x: 18 + (index % 3) * 270,
          y: 52 + Math.floor(index / 3) * 220,
          w: 250,
          h: 190,
        },
      ],
    });
  }

  function patchPane(paneId: string, patch: Partial<WorkbenchPaneModel>): void {
    onPatch(tile.id, {
      panes: (tile.panes ?? []).map((pane) => pane.id === paneId ? { ...pane, ...patch } : pane),
    });
  }

  function removePane(paneId: string): void {
    onPatch(tile.id, {
      panes: (tile.panes ?? []).filter((pane) => pane.id !== paneId),
    });
  }

  async function startPaneTerminal(pane: WorkbenchPaneModel): Promise<void> {
    if (startingPaneId || pane.sessionId) return;
    startingPaneId = pane.id;
    patchPane(pane.id, { error: undefined });
    try {
      const session = await createSession({
        runtimeType,
        workspaceSlug,
        cwd: rootPath,
        prompt: '',
        kind: 'terminal',
        interactive: true,
      });
      const sessionId = (session as unknown as { sessionId?: string; id?: string }).sessionId
        ?? (session as unknown as { id?: string }).id;
      if (!sessionId) throw new Error('Session created without an id');
      patchPane(pane.id, { sessionId, title: `Terminal ${sessionId.slice(0, 6)}` });
    } catch (err) {
      patchPane(pane.id, { error: err instanceof Error ? err.message : 'Failed to start terminal' });
    } finally {
      startingPaneId = '';
    }
  }

  function beginPaneDrag(event: PointerEvent, pane: WorkbenchPaneModel): void {
    event.stopPropagation();
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
    paneDragStart = { id: pane.id, px: event.clientX, py: event.clientY, x: pane.x ?? 0, y: pane.y ?? 0 };
  }

  function movePaneDrag(event: PointerEvent): void {
    if (!paneDragStart) return;
    const dx = (event.clientX - paneDragStart.px) / scale;
    const dy = (event.clientY - paneDragStart.py) / scale;
    patchPane(paneDragStart.id, {
      x: Math.max(0, Math.round(paneDragStart.x + dx)),
      y: Math.max(0, Math.round(paneDragStart.y + dy)),
    });
  }

  function endPaneDrag(event: PointerEvent): void {
    if (!paneDragStart) return;
    try {
      (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
    } catch {
      // Pointer may have ended on window after a fast nested pane drag.
    }
    paneDragStart = null;
  }

  function beginPaneResize(event: PointerEvent, pane: WorkbenchPaneModel): void {
    event.preventDefault();
    event.stopPropagation();
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
    paneResizeStart = { id: pane.id, px: event.clientX, py: event.clientY, w: pane.w ?? 250, h: pane.h ?? 190 };
  }

  function movePaneResize(event: PointerEvent): void {
    if (!paneResizeStart) return;
    const dw = (event.clientX - paneResizeStart.px) / scale;
    const dh = (event.clientY - paneResizeStart.py) / scale;
    patchPane(paneResizeStart.id, {
      w: Math.max(180, Math.round(paneResizeStart.w + dw)),
      h: Math.max(130, Math.round(paneResizeStart.h + dh)),
    });
  }

  function endPaneResize(event: PointerEvent): void {
    if (!paneResizeStart) return;
    try {
      (event.currentTarget as HTMLElement).releasePointerCapture?.(event.pointerId);
    } catch {
      // Pointer may have ended on window after a fast nested pane resize.
    }
    paneResizeStart = null;
  }

</script>

<svelte:window
  onpointermove={(event) => {
    moveDrag(event);
    moveResize(event);
    movePaneDrag(event);
    movePaneResize(event);
  }}
  onpointerup={(event) => {
    endDrag(event);
    endResize(event);
    endPaneDrag(event);
    endPaneResize(event);
  }}
  onpointercancel={(event) => {
    endDrag(event);
    endResize(event);
    endPaneDrag(event);
    endPaneResize(event);
  }}
/>

<article
  class="wbt-tile"
  class:wbt-tile--selected={selected}
  class:wbt-tile--dragging={dragStart !== null}
  class:wbt-tile--resizing={resizeStart !== null}
  style="--wbt-hit-scale: {Math.min(5, Math.max(1, 1 / scale))}; transform: translate3d({tile.x}px, {tile.y}px, 0); width: {tile.w}px; height: {tile.h}px; z-index: {tile.z ?? 0};"
  aria-label={tile.title}
  onpointerdown={() => onSelect(tile.id)}
>
  <header
    class="wbt-head"
    onpointerdown={beginDrag}
    onpointermove={moveDrag}
    onpointerup={endDrag}
    onpointercancel={endDrag}
  >
    <span class="wbt-grip" aria-hidden="true"><GripHorizontal size={13} /></span>
    <span class="wbt-icon"><Icon size={14} aria-hidden="true" /></span>
    <span class="wbt-title">{tile.title}</span>
    <span class="wbt-kind">{tile.kind}</span>
    <button
      type="button"
      class="wbt-head-btn"
      aria-label={tile.restore ? `Restore ${tile.title}` : `Maximize ${tile.title}`}
      title={tile.restore ? 'Restore' : 'Maximize'}
      onpointerdown={(event) => {
        event.stopPropagation();
        (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
      }}
      onpointerup={(event) => {
        event.stopPropagation();
        (event.currentTarget as HTMLElement).releasePointerCapture(event.pointerId);
        onToggleMaximize(tile.id);
      }}
    >
      {#if tile.restore}
        <Minimize2 size={12} aria-hidden="true" />
      {:else}
        <Maximize2 size={12} aria-hidden="true" />
      {/if}
    </button>
    <button
      type="button"
      class="wbt-head-btn"
      aria-label="Remove {tile.title}"
      title="Remove tile"
      onpointerdown={(event) => {
        event.stopPropagation();
        (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);
      }}
      onpointerup={(event) => {
        event.stopPropagation();
        (event.currentTarget as HTMLElement).releasePointerCapture(event.pointerId);
        onRemove(tile.id);
      }}
    >
      <X size={12} aria-hidden="true" />
    </button>
  </header>

  <div class="wbt-body">
    {#if tile.kind === 'terminal'}
      {#if tile.sessionId}
        <TerminalSession sessionId={tile.sessionId} isRunning={true} />
      {:else}
        <div class="wbt-empty">
          <p>Start a real Canopy terminal session in this canvas tile.</p>
          {#if tile.error}<span class="wbt-error">{tile.error}</span>{/if}
          <button type="button" class="wbt-primary" onclick={startTerminal} disabled={starting}>
            {starting ? 'Starting...' : 'Start terminal'}
          </button>
        </div>
      {/if}
    {:else if tile.kind === 'agent'}
      <AgentConversationPane
        {workspaceSlug}
        cwd={rootPath}
        {runtimeType}
        model="auto"
      />
    {:else if tile.kind === 'git'}
      {#if effectiveSessionId}
        <ChangesPanel sessionId={effectiveSessionId} />
      {:else}
        <GitChangesPanel />
      {/if}
    {:else if tile.kind === 'files'}
      <FileTree {workspaceSlug} hideHidden={true} onFileSelect={() => {}} />
    {:else if tile.kind === 'mission'}
      <div class="wbt-module">
        <p>Mission work is backed by Tasks, Projects, Goals, Build, and Review.</p>
        <div class="wbt-module-actions">
          <button type="button" class="wbt-primary" onclick={() => goto('/tasks')}>Open Tasks</button>
          <button type="button" class="wbt-secondary" onclick={() => goto('/build')}>Open Build</button>
          <button type="button" class="wbt-secondary" onclick={() => goto('/review')}>Open Review</button>
        </div>
      </div>
    {:else if tile.kind === 'module'}
      <WorkbenchModuleRenderer
        route={tile.route ?? '/dashboard'}
        {workspaceSlug}
      />
    {:else}
      <div class="wbt-tmux-shell">
        <div class="wbt-tmux-actions">
          <button type="button" onclick={() => addPane('terminal')}>Terminal pane</button>
          <button type="button" onclick={() => addPane('agent')}>Agent pane</button>
          <button type="button" onclick={() => addPane('git')}>Git pane</button>
          <button type="button" onclick={() => addPane('files')}>Files pane</button>
        </div>
        <div class="wbt-tmux-panes">
          {#if (tile.panes ?? []).length === 0}
            <div class="wbt-empty">
              <p>Add real panes inside this tmux desk. Terminal panes start real Canopy sessions.</p>
            </div>
          {:else}
            {#each tile.panes ?? [] as pane (pane.id)}
              <section
                class="wbt-pane"
                style="transform: translate3d({pane.x ?? 18}px, {pane.y ?? 52}px, 0); width: {pane.w ?? 250}px; height: {pane.h ?? 190}px;"
              >
                <header
                  onpointerdown={(event) => beginPaneDrag(event, pane)}
                  onpointermove={movePaneDrag}
                  onpointerup={endPaneDrag}
                  onpointercancel={endPaneDrag}
                >
                  <span>{pane.title}</span>
                  <button type="button" aria-label="Remove {pane.title}" onclick={() => removePane(pane.id)}>
                    <X size={11} aria-hidden="true" />
                  </button>
                </header>
                <div class="wbt-pane-body">
                  {#if pane.kind === 'terminal'}
                    {#if pane.sessionId}
                      <TerminalSession sessionId={pane.sessionId} isRunning={true} />
                    {:else}
                      {#if pane.error}<span class="wbt-error">{pane.error}</span>{/if}
                      <button type="button" class="wbt-primary" onclick={() => startPaneTerminal(pane)} disabled={startingPaneId === pane.id}>
                        {startingPaneId === pane.id ? 'Starting...' : 'Start terminal'}
                      </button>
                    {/if}
                  {:else if pane.kind === 'agent'}
                    <AgentConversationPane {workspaceSlug} cwd={rootPath} {runtimeType} model="auto" />
                  {:else if pane.kind === 'git'}
                    {#if effectiveSessionId}
                      <ChangesPanel sessionId={effectiveSessionId} />
                    {:else}
                      <GitChangesPanel />
                    {/if}
                  {:else}
                    <div class="wbt-module">
                      <p>Files pane uses the real Files module surface.</p>
                      <button type="button" class="wbt-primary" onclick={() => goto('/files')}>Open Files</button>
                    </div>
                  {/if}
                </div>
                <button
                  type="button"
                  class="wbt-pane-resize"
                  aria-label="Resize {pane.title}"
                  onpointerdown={(event) => beginPaneResize(event, pane)}
                  onpointermove={movePaneResize}
                  onpointerup={endPaneResize}
                  onpointercancel={endPaneResize}
                ></button>
              </section>
            {/each}
          {/if}
        </div>
      </div>
    {/if}
  </div>

  <footer class="wbt-foot">
    <span>{tile.subtitle}</span>
    {#if tile.sessionId}
      <button type="button" onclick={openSession}>Open session</button>
    {/if}
  </footer>

  {#each ['n', 'e', 's', 'w', 'ne', 'nw', 'se', 'sw'] as direction}
    <button
      type="button"
      class="wbt-resize wbt-resize--{direction}"
      aria-label="Resize {tile.title} {direction}"
      onpointerdown={(event) => beginResize(event, direction as ResizeDirection)}
      onpointermove={moveResize}
      onpointerup={endResize}
      onpointercancel={endResize}
    ></button>
  {/each}
</article>

<style>
  .wbt-tile {
    position: absolute;
    display: grid;
    grid-template-rows: auto 1fr auto;
    overflow: hidden;
    border: 1px solid color-mix(in oklch, var(--border) 85%, white 8%);
    border-radius: 8px;
    background: color-mix(in oklch, var(--surface, var(--bg)) 92%, white 3%);
    box-shadow: 0 18px 50px color-mix(in oklch, black 28%, transparent);
    color: var(--fg);
    user-select: none;
    pointer-events: auto;
  }

  .wbt-tile--dragging { cursor: default; }
  .wbt-tile--resizing { cursor: nwse-resize; }

  .wbt-tile--selected {
    border-color: var(--cnp-accent, oklch(0.72 0.18 145));
    box-shadow: 0 0 0 1px color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 80%, transparent),
      0 18px 50px color-mix(in oklch, black 28%, transparent);
  }

  .wbt-head {
    display: flex;
    align-items: center;
    gap: 7px;
    min-height: 34px;
    padding: 0 10px;
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    cursor: grab;
  }

  .wbt-tile--dragging .wbt-head { cursor: grabbing; }

  .wbt-grip {
    display: inline-flex;
    color: var(--fg-subtle);
  }

  .wbt-icon {
    display: inline-flex;
    color: var(--cnp-accent, oklch(0.72 0.18 145));
  }

  .wbt-title {
    flex: 1;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 12px;
    font-weight: 650;
  }

  .wbt-kind {
    font-size: 9px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .wbt-head-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border: 1px solid transparent;
    border-radius: 5px;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
  }

  .wbt-head-btn:hover {
    border-color: var(--border);
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 7%, transparent);
  }

  .wbt-body {
    min-height: 0;
    padding: 12px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .wbt-body :global(.ts-root) {
    min-height: 0;
    border: none;
    border-radius: 0;
  }

  .wbt-body :global(.acp-root),
  .wbt-body :global(.chp-root) {
    min-height: 0;
    flex: 1;
  }

  .wbt-body :global(.ft-root-container) {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }

  .wbt-body :global(.wmr-root) {
    margin: -12px;
    flex: 1;
    min-height: 0;
  }

  .wbt-empty,
  .wbt-module {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
    gap: 8px;
    color: var(--fg-muted);
    font-size: 12px;
    line-height: 1.45;
  }

  .wbt-empty p,
  .wbt-module p {
    margin: 0;
  }

  .wbt-error {
    color: var(--destructive, oklch(0.65 0.22 25));
    font-size: 11px;
  }

  .wbt-primary,
  .wbt-secondary {
    min-height: 28px;
    padding: 0 10px;
    border: 1px solid var(--border);
    border-radius: 6px;
    font: inherit;
    font-size: 12px;
    cursor: pointer;
  }

  .wbt-primary {
    color: var(--fg);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 20%, transparent);
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 42%, var(--border));
  }

  .wbt-secondary {
    color: var(--fg-muted);
    background: transparent;
  }

  .wbt-module-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .wbt-tmux-shell {
    display: grid;
    grid-template-rows: auto 1fr;
    gap: 8px;
    min-height: 0;
    height: 100%;
  }

  .wbt-tmux-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .wbt-tmux-actions button {
    min-height: 26px;
    padding: 0 9px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    color: var(--fg-muted);
    font: inherit;
    font-size: 11px;
    cursor: pointer;
  }

  .wbt-tmux-panes {
    position: relative;
    min-height: 0;
    overflow: hidden;
    border: 1px solid var(--border);
    border-radius: 7px;
    background:
      radial-gradient(circle at 1px 1px, color-mix(in oklch, var(--fg) 12%, transparent) 1px, transparent 0) 0 0 / 18px 18px,
      color-mix(in oklch, black 8%, transparent);
  }

  .wbt-pane {
    position: absolute;
    display: grid;
    grid-template-rows: auto 1fr;
    min-height: 0;
    overflow: hidden;
    border: 1px solid var(--border);
    border-radius: 7px;
    background: color-mix(in oklch, black 14%, transparent);
    box-shadow: 0 10px 30px color-mix(in oklch, black 16%, transparent);
  }

  .wbt-pane header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-height: 26px;
    padding: 0 8px;
    border-bottom: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
    cursor: grab;
  }

  .wbt-pane header:active { cursor: grabbing; }

  .wbt-pane header button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border: none;
    border-radius: 4px;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
  }

  .wbt-pane-body {
    display: flex;
    flex-direction: column;
    min-height: 0;
    padding: 8px;
    overflow: hidden;
  }

  .wbt-pane-resize {
    position: absolute;
    right: 0;
    bottom: 0;
    z-index: 3;
    width: clamp(16px, calc(16px * var(--wbt-hit-scale, 1)), 72px);
    height: clamp(16px, calc(16px * var(--wbt-hit-scale, 1)), 72px);
    border: none;
    background:
      linear-gradient(135deg, transparent 0 50%, color-mix(in oklch, var(--fg) 30%, transparent) 50% 58%, transparent 58% 68%, color-mix(in oklch, var(--fg) 24%, transparent) 68% 76%, transparent 76%);
    cursor: nwse-resize;
    touch-action: none;
  }

  .wbt-foot {
    min-height: 30px;
    padding: 8px 10px;
    border-top: 1px solid var(--border);
    color: var(--fg-subtle);
    font-size: 11px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .wbt-foot button {
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font: inherit;
    font-size: 11px;
    cursor: pointer;
  }

  .wbt-resize {
    position: absolute;
    z-index: 5;
    border: none;
    background: transparent;
    touch-action: none;
  }

  .wbt-resize--n,
  .wbt-resize--s {
    left: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
    right: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
    height: clamp(8px, calc(8px * var(--wbt-hit-scale, 1)), 28px);
    cursor: ns-resize;
  }

  .wbt-resize--n { top: 0; }
  .wbt-resize--s { bottom: 0; }

  .wbt-resize--e,
  .wbt-resize--w {
    top: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
    bottom: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
    width: clamp(8px, calc(8px * var(--wbt-hit-scale, 1)), 28px);
    cursor: ew-resize;
  }

  .wbt-resize--e { right: 0; }
  .wbt-resize--w { left: 0; }

  .wbt-resize--ne,
  .wbt-resize--nw,
  .wbt-resize--se,
  .wbt-resize--sw {
    width: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
    height: clamp(18px, calc(18px * var(--wbt-hit-scale, 1)), 76px);
  }

  .wbt-resize--ne { top: 0; right: 0; cursor: nesw-resize; }
  .wbt-resize--nw { top: 0; left: 0; cursor: nwse-resize; }
  .wbt-resize--se {
    right: 0;
    bottom: 0;
    cursor: nwse-resize;
    background:
      linear-gradient(135deg, transparent 0 50%, color-mix(in oklch, var(--fg) 28%, transparent) 50% 58%, transparent 58% 68%, color-mix(in oklch, var(--fg) 24%, transparent) 68% 76%, transparent 76%);
  }
  .wbt-resize--sw { left: 0; bottom: 0; cursor: nesw-resize; }
</style>
