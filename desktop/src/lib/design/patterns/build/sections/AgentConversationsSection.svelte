<script lang="ts">
  /**
   * AgentConversationsSection — agent transcript panel inside the Build rail.
   * CSS prefix: brl-conv-
   *
   * Shape (matches the popover other shells expose for agent transcripts):
   *   ┌─────────────────────────────┐
   *   │ Search box                  │
   *   ├─────────────────────────────┤
   *   │ ▾ ACTIVE                    │
   *   │   • Conversation row        │
   *   │   • Conversation row        │
   *   │ ▾ RECENT                    │
   *   │   • Conversation row        │
   *   ├─────────────────────────────┤
   *   │ + New conversation          │
   *   └─────────────────────────────┘
   *
   * Click row     → focus pane if open (or open a new pane attached to that
   *                  session in the active tile).
   * Right-click   → ContextMenu: Fork in new pane / Fork in new tab / Delete.
   * + button      → POST /api/v1/sessions (kind=agent_conversation) → open in
   *                  a fresh pane in the active tile.
   *
   * Reuses:
   *   - agentConversationsQuery / createAgentConversationMutation
   *     (which themselves are thin wrappers over sessionsQuery /
   *      createSessionMutation — there is no parallel /conversations endpoint)
   *   - foundation/menus ContextMenu primitive
   *   - mosaic-layout store for pane lifecycle
   *
   * LOC target: ≤ 360.
   */

  import { Bot, Loader2, Plus, Search } from "lucide-svelte";
  import {
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import {
    ContextMenu,
    type ContextMenuAnchor,
    type ContextMenuItem,
    toast,
  } from "$lib/design/foundation/index.js";
  import {
    agentConversationsQuery,
    createAgentConversationMutation,
    deleteAgentConversationMutation,
    isActiveConversation,
  } from "$lib/api/queries/conversations.js";
  import { updateSessionMutation } from "$lib/api/queries/sessions.js";
  import type { Session } from "$lib/domain/sessions/types.js";
  import { mosaicLayout, type Pane } from "$lib/stores/mosaic-layout.svelte.js";

  interface Props {
    workspaceSlug: string;
  }

  let { workspaceSlug }: Props = $props();

  // ── Query (reuses the sessions list under the hood) ────────────────────────
  function buildOpts(): CreateQueryOptions<Session[]> {
    return agentConversationsQuery({
      workspaceSlug,
      limit: 100,
    }) as CreateQueryOptions<Session[]>;
  }
  const optsStore = writable(untrack(() => buildOpts()));
  $effect(() => {
    optsStore.set(buildOpts());
  });
  const conversationsQ = createQuery<Session[]>(optsStore);

  const queryClient = useQueryClient();

  // ── Mutations ──────────────────────────────────────────────────────────────
  const createConvo = createMutation(createAgentConversationMutation());
  const deleteConvo = createMutation(deleteAgentConversationMutation());
  const renameConvo = createMutation(updateSessionMutation());

  // ── Local state ────────────────────────────────────────────────────────────
  let filterText = $state("");
  let activeOpen = $state(true);
  let recentOpen = $state(true);

  let menuAnchor = $state<ContextMenuAnchor | null>(null);
  let menuTarget = $state<Session | null>(null);

  // Inline rename state — only one session can be renamed at a time.
  let renamingId = $state<string | null>(null);
  let renameValue = $state("");

  // ── Filtering / grouping ───────────────────────────────────────────────────
  /**
   * Pre-filter: hide legacy rows (kind === null) so this panel only ever
   * shows true agent_conversation transcripts even if the backend hasn't
   * shipped the kind column yet (and is therefore returning everything).
   */
  const conversations = $derived<Session[]>(
    ($conversationsQ.data ?? []).filter((s) => s.kind === "agent_conversation"),
  );

  const filtered = $derived<Session[]>(
    (() => {
      const needle = filterText.trim().toLowerCase();
      if (!needle) return conversations;
      return conversations.filter((s) => {
        const title = conversationTitle(s).toLowerCase();
        const cwd = (s.cwd ?? "").toLowerCase();
        return title.includes(needle) || cwd.includes(needle);
      });
    })(),
  );

  const active = $derived(filtered.filter(isActiveConversation));
  const recent = $derived(filtered.filter((s) => !isActiveConversation(s)));

  // ── Display helpers ────────────────────────────────────────────────────────
  function conversationTitle(s: Session): string {
    if (s.prompt && s.prompt.trim().length > 0) {
      return truncate(s.prompt.trim(), 80);
    }
    if (s.agentSlug) return s.agentSlug;
    return `Conversation ${s.id.slice(0, 8)}`;
  }

  function truncate(text: string, max: number): string {
    if (text.length <= max) return text;
    return `${text.slice(0, max - 1)}…`;
  }

  function relativeTime(iso: string | null): string {
    if (!iso) return "";
    const then = new Date(iso).getTime();
    if (Number.isNaN(then)) return "";
    const diff = Date.now() - then;
    const m = Math.round(diff / 60000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m`;
    const h = Math.round(m / 60);
    if (h < 24) return `${h}h`;
    const d = Math.round(h / 24);
    return `${d}d`;
  }

  function newPane(session: Session): Pane {
    return {
      id: Math.random().toString(36).slice(2, 9),
      kind: "agent_conversation",
      ref: session.id,
      title: conversationTitle(session),
      config: {
        sessionId: session.id,
        cwd: session.cwd,
        model: session.modelId ?? undefined,
      },
    };
  }

  /**
   * Find an open mosaic pane already attached to this session, returning
   * { tileId, paneId } so we can focus it instead of duplicating.
   */
  function findOpenPane(
    sessionId: string,
  ): { tileId: string; paneId: string } | null {
    for (const tile of mosaicLayout.allTiles()) {
      for (const pane of tile.panes) {
        if (pane.kind === "agent_conversation" && pane.ref === sessionId) {
          return { tileId: tile.id, paneId: pane.id };
        }
      }
    }
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  function openOrFocus(session: Session): void {
    const existing = findOpenPane(session.id);
    if (existing) {
      mosaicLayout.activatePane(existing.tileId, existing.paneId);
      return;
    }
    mosaicLayout.openPane(newPane(session));
  }

  function forkInNewPane(session: Session): void {
    // "Fork in new pane" — split the active tile and put the convo there.
    const activeTileId = mosaicLayout.activeTileId;
    if (!activeTileId) {
      mosaicLayout.openPane(newPane(session));
      return;
    }
    mosaicLayout.splitTile(activeTileId, "vertical", newPane(session));
  }

  function forkInNewTab(session: Session): void {
    // Add the conversation to the active tile as a new tab.
    mosaicLayout.openPane(newPane(session));
  }

  async function deleteConversation(session: Session): Promise<void> {
    const previous = $conversationsQ.data;
    // Optimistic remove from cache.
    queryClient.setQueryData<Session[]>(
      ["agent-conversations", { kind: "agent_conversation", workspaceSlug, limit: 100 }],
      (old) => (old ? old.filter((s) => s.id !== session.id) : old),
    );
    try {
      await $deleteConvo.mutateAsync(session.id);
      // Also close any pane attached to it so the user isn't stranded.
      const open = findOpenPane(session.id);
      if (open) mosaicLayout.closePane(open.tileId, open.paneId);
      toast.success("Conversation deleted");
      await queryClient.invalidateQueries({ queryKey: ["agent-conversations"] });
    } catch (err) {
      // Rollback the optimistic mutation.
      if (previous) {
        queryClient.setQueryData<Session[]>(
          ["agent-conversations", { kind: "agent_conversation", workspaceSlug, limit: 100 }],
          previous,
        );
      }
      const message = err instanceof Error ? err.message : "Delete failed";
      toast.error("Failed to delete conversation", message);
    }
  }

  async function newConversation(): Promise<void> {
    try {
      const session = await $createConvo.mutateAsync({
        runtimeType: "claude-local",
        cwd: "~",
        workspaceSlug,
      });
      // Refetch so the new row shows up in ACTIVE.
      await queryClient.invalidateQueries({ queryKey: ["agent-conversations"] });
      // Open the brand-new conversation in a pane.
      mosaicLayout.openPane(newPane(session));
    } catch (err) {
      const message = err instanceof Error ? err.message : "Could not start";
      toast.error("Failed to start conversation", message);
    }
  }

  // ── Rename ─────────────────────────────────────────────────────────────────
  function startRename(session: Session): void {
    renamingId = session.id;
    renameValue = conversationTitle(session);
  }

  function cancelRename(): void {
    renamingId = null;
    renameValue = "";
  }

  async function commitRename(session: Session): Promise<void> {
    const trimmed = renameValue.trim();
    if (!trimmed || trimmed === conversationTitle(session)) {
      cancelRename();
      return;
    }
    renamingId = null;
    try {
      await $renameConvo.mutateAsync({ id: session.id, title: trimmed });
      toast.success("Session renamed");
      await queryClient.invalidateQueries({ queryKey: ["agent-conversations"] });
    } catch (err) {
      const message = err instanceof Error ? err.message : "Rename failed";
      toast.error("Failed to rename session", message);
    }
  }

  // ── Svelte actions ─────────────────────────────────────────────────────────
  function focusOnMount(node: HTMLInputElement): void {
    node.focus();
    node.select();
  }

  // ── Context menu ───────────────────────────────────────────────────────────
  function openContextMenu(session: Session, ev: MouseEvent): void {
    ev.preventDefault();
    menuTarget = session;
    menuAnchor = { x: ev.clientX, y: ev.clientY };
  }

  function closeContextMenu(): void {
    menuAnchor = null;
    menuTarget = null;
  }

  const menuItems = $derived<ContextMenuItem[]>(
    menuTarget
      ? [
          {
            id: "rename",
            label: "Rename",
            onSelect: () => menuTarget && startRename(menuTarget),
          },
          {
            id: "fork-pane",
            label: "Fork in new pane",
            onSelect: () => menuTarget && forkInNewPane(menuTarget),
          },
          {
            id: "fork-tab",
            label: "Fork in new tab",
            onSelect: () => menuTarget && forkInNewTab(menuTarget),
          },
          {
            id: "delete",
            label: "Delete",
            destructive: true,
            onSelect: () => menuTarget && void deleteConversation(menuTarget),
          },
        ]
      : [],
  );
</script>

<div class="brl-conv">
  <header class="brl-conv__header">
    <span class="brl-conv__title">Conversations</span>
    {#if conversations.length > 0}
      <span class="brl-conv__count">{conversations.length}</span>
    {/if}
  </header>

  <div class="brl-conv__search">
    <span class="brl-conv__search-icon" aria-hidden="true">
      <Search size={12} />
    </span>
    <input
      type="search"
      class="brl-conv__search-input"
      placeholder="Search conversations…"
      bind:value={filterText}
      aria-label="Search agent conversations"
    />
  </div>

  <div class="brl-conv__body">
    {#if $conversationsQ.isLoading}
      <div class="brl-conv__empty">Loading conversations…</div>
    {:else if $conversationsQ.isError}
      <div class="brl-conv__error" role="alert">
        Failed to load conversations
      </div>
    {:else if conversations.length === 0}
      <div class="brl-conv__empty">No conversations yet</div>
    {:else if filtered.length === 0}
      <div class="brl-conv__empty">No matches</div>
    {:else}
      {#if active.length > 0}
        <section class="brl-conv__group">
          <button
            type="button"
            class="brl-conv__group-header"
            aria-expanded={activeOpen}
            onclick={() => (activeOpen = !activeOpen)}
          >
            <span class="brl-conv__chev" aria-hidden="true">
              {activeOpen ? "▾" : "▸"}
            </span>
            <span class="brl-conv__group-title">ACTIVE</span>
            <span class="brl-conv__group-count">{active.length}</span>
          </button>
          {#if activeOpen}
            <ul class="brl-conv__list" role="list">
              {#each active as session (session.id)}
                {@render conversationRow(session)}
              {/each}
            </ul>
          {/if}
        </section>
      {/if}

      {#if recent.length > 0}
        <section class="brl-conv__group">
          <button
            type="button"
            class="brl-conv__group-header"
            aria-expanded={recentOpen}
            onclick={() => (recentOpen = !recentOpen)}
          >
            <span class="brl-conv__chev" aria-hidden="true">
              {recentOpen ? "▾" : "▸"}
            </span>
            <span class="brl-conv__group-title">RECENT</span>
            <span class="brl-conv__group-count">{recent.length}</span>
          </button>
          {#if recentOpen}
            <ul class="brl-conv__list" role="list">
              {#each recent as session (session.id)}
                {@render conversationRow(session)}
              {/each}
            </ul>
          {/if}
        </section>
      {/if}
    {/if}
  </div>

  <footer class="brl-conv__footer">
    <button
      type="button"
      class="brl-conv__new"
      onclick={newConversation}
      disabled={$createConvo.isPending}
      aria-label="Start a new conversation"
    >
      {#if $createConvo.isPending}
        <Loader2 size={14} class="brl-conv__spin" aria-hidden="true" />
        Starting…
      {:else}
        <Plus size={14} aria-hidden="true" />
        New conversation
      {/if}
    </button>
    {#if $createConvo.isError}
      <p class="brl-conv__footer-error" role="alert">
        Could not start conversation
      </p>
    {/if}
  </footer>
</div>

<ContextMenu
  items={menuItems}
  anchor={menuAnchor}
  onclose={closeContextMenu}
  ariaLabel="Conversation actions"
/>

{#snippet conversationRow(session: Session)}
  <li>
    <div
      class="brl-conv__row"
      role="button"
      tabindex="0"
      data-session-id={session.id}
      title={conversationTitle(session)}
      onclick={() => renamingId !== session.id && openOrFocus(session)}
      onkeydown={(e) => {
        if (renamingId === session.id) return;
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          openOrFocus(session);
        }
      }}
      oncontextmenu={(e) => openContextMenu(session, e)}
    >
      <span class="brl-conv__row-icon" aria-hidden="true">
        <Bot size={14} />
      </span>
      <span class="brl-conv__row-body">
        {#if renamingId === session.id}
          <input
            type="text"
            class="brl-conv__rename-input"
            bind:value={renameValue}
            aria-label="Rename session"
            onclick={(e) => e.stopPropagation()}
            onkeydown={(e) => {
              if (e.key === "Enter") { e.preventDefault(); void commitRename(session); }
              if (e.key === "Escape") { e.preventDefault(); cancelRename(); }
            }}
            onblur={() => void commitRename(session)}
            use:focusOnMount
          />
        {:else}
          <span class="brl-conv__row-title">{conversationTitle(session)}</span>
        {/if}
        {#if session.cwd}
          <span class="brl-conv__row-cwd">{session.cwd}</span>
        {/if}
      </span>
      <span class="brl-conv__row-time">
        {relativeTime(session.updatedAt ?? session.startedAt)}
      </span>
    </div>
  </li>
{/snippet}

<style>
  .brl-conv {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .brl-conv__header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    padding: 10px var(--space-3) 6px;
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-conv__title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .brl-conv__count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .brl-conv__search {
    position: relative;
    padding: var(--space-2);
  }

  .brl-conv__search-icon {
    position: absolute;
    left: 16px;
    top: 50%;
    transform: translateY(-50%);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .brl-conv__search-input {
    width: 100%;
    height: 26px;
    padding: 0 var(--space-2) 0 26px;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    background: var(--bg-inset, rgba(0, 0, 0, 0.04));
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: var(--radius-sm, 4px);
    outline: none;
  }

  .brl-conv__search-input:focus-visible {
    border-color: var(--cnp-accent, #1e96eb);
  }

  .brl-conv__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding-bottom: var(--space-2);
  }

  .brl-conv__empty,
  .brl-conv__error {
    padding: var(--space-6) var(--space-3);
    text-align: center;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .brl-conv__error {
    color: var(--signal-error, #eb4335);
  }

  .brl-conv__group {
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.04));
  }

  .brl-conv__group-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: 6px var(--space-3);
    border: none;
    background: transparent;
    text-align: left;
    cursor: pointer;
    font-family: var(--font-sans);
  }

  .brl-conv__group-header:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .brl-conv__chev {
    font-size: 10px;
    color: var(--fg-subtle);
    width: 10px;
  }

  .brl-conv__group-title {
    flex: 1;
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    letter-spacing: 0.06em;
  }

  .brl-conv__group-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .brl-conv__list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-conv__row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: 6px var(--space-3) 6px var(--space-4);
    cursor: pointer;
    color: var(--fg-muted);
    transition: background 80ms ease-out;
  }

  .brl-conv__row:hover,
  .brl-conv__row:focus-visible {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
    outline: none;
  }

  .brl-conv__row-icon {
    flex-shrink: 0;
    margin-top: 2px;
    color: var(--cnp-accent, #1e96eb);
  }

  .brl-conv__row-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
    overflow: hidden;
  }

  .brl-conv__row-title {
    font-family: var(--font-sans);
    font-size: 12px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-conv__rename-input {
    width: 100%;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg);
    background: var(--bg-inset, rgba(0, 0, 0, 0.04));
    border: 1px solid var(--cnp-accent, #1e96eb);
    border-radius: var(--radius-sm, 4px);
    padding: 1px 4px;
    outline: none;
    height: 20px;
  }

  .brl-conv__row-cwd {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-conv__row-time {
    flex-shrink: 0;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    margin-top: 3px;
  }

  .brl-conv__footer {
    flex-shrink: 0;
    padding: var(--space-2);
    border-top: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-conv__new {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    width: 100%;
    height: 30px;
    border: 1px dashed var(--border, rgba(0, 0, 0, 0.16));
    background: transparent;
    color: var(--fg-muted);
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: 12px;
    transition: all 80ms ease-out;
  }

  .brl-conv__new:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent, #1e96eb) 8%, transparent 92%);
    border-color: var(--cnp-accent, #1e96eb);
    border-style: solid;
    color: var(--fg);
  }

  .brl-conv__new:disabled {
    cursor: progress;
    opacity: 0.7;
  }

  .brl-conv__footer-error {
    margin: 6px 0 0;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--signal-error, #eb4335);
    text-align: center;
  }

  :global(.brl-conv__spin) {
    animation: brl-conv-spin 1s linear infinite;
  }

  @keyframes brl-conv-spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
