<script lang="ts">
  /**
   * FilesWorkspacePicker — left-pane workspace list for the /files project
   * explorer. CSS prefix: fwp- (Files Workspace Picker).
   *
   * Lists every workspace from `workspacesQuery()`, highlights the active one,
   * and routes to /workspaces?new=true for the "+ New workspace" CTA. Calls
   * `activeWorkspace.setActive(slug)` on click — also mirrors to
   * `ui.setCurrentWorkspace` for legacy components that still read `ui`.
   *
   * LOC target: ≤ 200.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { FolderOpen, Plus } from "lucide-svelte";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import { goto } from "$app/navigation";

  import { workspacesQuery } from "$lib/api/queries/workspaces.js";
  import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
  import type { Workspace } from "$lib/domain/workspaces/types.js";
  import { activeWorkspace } from "$lib/stores/active-workspace.svelte.js";
  import { ui } from "$lib/stores/ui.svelte.js";

  // ── Workspace list query ───────────────────────────────────────────────────
  const optsStore = writable(
    untrack(
      () => workspacesQuery() as CreateQueryOptions<Workspace[]>,
    ),
  );
  const workspacesQ = createQuery<Workspace[]>(optsStore);
  const workspaces = $derived(($workspacesQ.data ?? []) as Workspace[]);

  // Sync the pool into the activeWorkspace store on every fresh fetch so
  // `setActive()` can validate the slug.
  $effect(() => {
    if (workspaces.length > 0) activeWorkspace.syncPool(workspaces);
  });

  const activeSlug = $derived(activeWorkspace.slug);

  function pickWorkspace(slug: string): void {
    if (activeWorkspace.setActive(slug)) {
      // Mirror to legacy ui store (WorkspaceSwitcher, file uploader, etc.).
      ui.setCurrentWorkspace(slug);
    }
  }

  function newWorkspace(): void {
    goto("/workspaces?new=true");
  }
</script>

<aside class="fwp" aria-label="Workspaces">
  <div class="fwp__header">
    <span class="fwp__label">WORKSPACES</span>
  </div>

  <div class="fwp__list" role="listbox" aria-label="Workspace list">
    {#if $workspacesQ.isLoading}
      <div class="fwp__skeleton">
        <SkeletonList count={4} height="2.25rem" gap="2px" />
      </div>
    {:else if $workspacesQ.isError}
      <p class="fwp__empty" role="alert">
        {(($workspacesQ.error as Error)?.message ?? "Couldn't load workspaces") || "Couldn't load workspaces"}
      </p>
    {:else if workspaces.length === 0}
      <div class="fwp__empty-block">
        <p class="fwp__empty">No workspaces yet.</p>
        <button
          type="button"
          class="fwp__cta"
          onclick={newWorkspace}
        >
          + Create your first workspace
        </button>
      </div>
    {:else}
      {#each workspaces as ws (ws.slug)}
        <button
          type="button"
          class="fwp__row"
          class:fwp__row--active={ws.slug === activeSlug}
          role="option"
          aria-selected={ws.slug === activeSlug}
          onclick={() => pickWorkspace(ws.slug)}
          title={ws.rootPath}
        >
          <span class="fwp__icon" aria-hidden="true">
            <FolderOpen size={13} />
          </span>
          <span class="fwp__meta">
            <span class="fwp__name">{ws.name}</span>
            <span class="fwp__path">{ws.rootPath}</span>
          </span>
        </button>
      {/each}
    {/if}
  </div>

  <div class="fwp__footer">
    <button
      type="button"
      class="fwp__new"
      onclick={newWorkspace}
      aria-label="Create new workspace"
    >
      <Plus size={11} aria-hidden="true" />
      <span>New workspace</span>
    </button>
  </div>
</aside>

<style>
  .fwp {
    width: 240px;
    min-width: 200px;
    max-width: 260px;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border);
    flex-shrink: 0;
    overflow: hidden;
    background: var(--bg);
  }

  .fwp__header {
    padding: var(--space-4) var(--space-3) var(--space-2);
    flex-shrink: 0;
  }

  .fwp__label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    letter-spacing: 0.1em;
    text-transform: uppercase;
  }

  .fwp__list {
    flex: 1;
    overflow-y: auto;
    padding: 0 var(--space-1);
  }

  .fwp__skeleton {
    padding: var(--space-2);
  }

  .fwp__empty,
  .fwp__empty-block {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-3) var(--space-2);
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .fwp__cta {
    background: transparent;
    border: 1px dashed var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-2);
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-muted);
    cursor: pointer;
    text-align: center;
    transition: all 80ms ease-out;
  }

  .fwp__cta:hover {
    border-color: var(--cnp-accent, #6e8df1);
    color: var(--fg);
  }

  .fwp__row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-1) var(--space-2);
    background: transparent;
    border: none;
    border-left: 2px solid transparent;
    border-radius: 0;
    cursor: pointer;
    text-align: left;
    transition:
      background var(--dur-instant, 80ms) var(--ease-out, ease-out),
      border-color var(--dur-instant, 80ms) var(--ease-out, ease-out);
    min-height: 40px;
  }

  .fwp__row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .fwp__row--active {
    border-left-color: var(--cnp-accent, #6e8df1);
    background: var(--bg-inset);
  }

  .fwp__icon {
    flex-shrink: 0;
    color: var(--fg-subtle);
    margin-top: 2px;
  }

  .fwp__meta {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
    flex: 1;
  }

  .fwp__name {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-weight: 450;
  }

  .fwp__row--active .fwp__name {
    color: var(--fg);
    font-weight: 500;
  }

  .fwp__path {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .fwp__footer {
    border-top: 1px solid var(--border);
    padding: var(--space-1);
    flex-shrink: 0;
  }

  .fwp__new {
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: var(--space-2);
    background: transparent;
    border: none;
    text-align: left;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    padding: var(--space-2);
    min-height: 28px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: color 80ms ease-out, background 80ms ease-out;
  }

  .fwp__new:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }
</style>
