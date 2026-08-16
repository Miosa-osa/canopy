<script lang="ts">
  /**
   * DriveSection — read-only listing of the Drive super-module's tree.
   * CSS prefix: brl-drive-.
   *
   * Top-level Personal | Team toggle. Tree of folders + entries grouped by
   * kind (Workflow / Prompt / Notebook / Env Vars / MCP Server / Rule).
   * Drag an entry → drops into a Mosaic pane via a dataTransfer payload.
   *
   * Source: GET /api/v1/drive/tree?scope=personal|team (Drive dispatch is
   * building this endpoint). If absent (404), shows "Drive backend pending".
   *
   * Full management is in /drive — this rail is read-only.
   * LOC target: ≤ 240.
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import {
    BookOpen,
    ChevronRight,
    Database,
    FileText,
    Folder,
    Notebook,
    Server,
    Workflow,
  } from "lucide-svelte";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import { ApiError, apiGet } from "$lib/api/client.js";
  import type {
    DriveEntry,
    DriveKind,
    DriveScope,
    DriveTreeNode,
  } from "$lib/domain/drive/types.js";

  // ── Local backend status (mirrors search.ts pattern) ───────────────────────
  interface DriveTreeStatus {
    available: boolean;
    nodes: DriveTreeNode[];
  }

  async function fetchDriveTree(scope: DriveScope): Promise<DriveTreeStatus> {
    try {
      const data = await apiGet<DriveTreeNode[]>(
        `/drive/tree?scope=${scope}`,
      );
      return { available: true, nodes: data ?? [] };
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        return { available: false, nodes: [] };
      }
      throw err;
    }
  }

  function driveTreeQuery(scope: DriveScope) {
    return {
      queryKey: ["build-rail", "drive-tree", scope] as const,
      queryFn: () => fetchDriveTree(scope),
      staleTime: 30_000,
    };
  }

  // ── State ──────────────────────────────────────────────────────────────────
  let scope = $state<DriveScope>("personal");
  let expandedFolders = $state(new Set<string>());

  function buildOpts(): CreateQueryOptions<DriveTreeStatus> {
    return driveTreeQuery(scope) as CreateQueryOptions<DriveTreeStatus>;
  }
  const optsStore = writable(untrack(() => buildOpts()));
  $effect(() => {
    optsStore.set(buildOpts());
  });
  const treeQ = createQuery<DriveTreeStatus>(optsStore);

  // ── Helpers ────────────────────────────────────────────────────────────────
  // Returned values are lucide-svelte component classes; we render them via
  // <svelte:component this={Icon} ...> to bypass strict-mode component-type
  // generic inference.
  function iconFor(kind: DriveKind): typeof Folder {
    switch (kind) {
      case "folder":
        return Folder;
      case "workflow":
        return Workflow as unknown as typeof Folder;
      case "prompt":
        return FileText as unknown as typeof Folder;
      case "notebook":
        return Notebook as unknown as typeof Folder;
      case "env_vars":
        return Database as unknown as typeof Folder;
      case "mcp_server":
        return Server as unknown as typeof Folder;
      case "rule":
        return BookOpen as unknown as typeof Folder;
    }
  }

  function toggleFolder(id: string): void {
    const next = new Set(expandedFolders);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    expandedFolders = next;
  }

  function handleDragStart(entry: DriveEntry, ev: DragEvent): void {
    if (!ev.dataTransfer) return;
    const payload = {
      kind: "build-rail/drive-entry",
      driveKind: entry.kind,
      entryId: entry.id,
      slug: entry.slug,
      name: entry.name,
      scope: entry.scope,
    };
    ev.dataTransfer.setData(
      "application/x-canopy-rail",
      JSON.stringify(payload),
    );
    ev.dataTransfer.setData("text/plain", entry.name);
    ev.dataTransfer.effectAllowed = "copy";
  }
</script>

<div class="brl-drive">
  <header class="brl-drive__header">
    <span class="brl-drive__title">Drive</span>
    <div class="brl-drive__scope" role="tablist" aria-label="Drive scope">
      <button
        type="button"
        class="brl-drive__scope-btn"
        class:brl-drive__scope-btn--active={scope === "personal"}
        role="tab"
        aria-selected={scope === "personal"}
        onclick={() => (scope = "personal")}
      >
        Personal
      </button>
      <button
        type="button"
        class="brl-drive__scope-btn"
        class:brl-drive__scope-btn--active={scope === "team"}
        role="tab"
        aria-selected={scope === "team"}
        onclick={() => (scope = "team")}
      >
        Team
      </button>
    </div>
  </header>

  <div class="brl-drive__body">
    {#if $treeQ.isLoading}
      <div class="brl-drive__empty">Loading…</div>
    {:else if $treeQ.isError}
      <div class="brl-drive__error">Failed to load drive</div>
    {:else if $treeQ.data && !$treeQ.data.available}
      <div class="brl-drive__empty">Drive backend pending</div>
    {:else if !$treeQ.data || $treeQ.data.nodes.length === 0}
      <div class="brl-drive__empty">Empty {scope} drive</div>
    {:else}
      <ul class="brl-drive__tree" role="tree">
        {#each $treeQ.data.nodes as node (node.entry.id)}
          {@render driveNode(node, 0)}
        {/each}
      </ul>
    {/if}
  </div>
</div>

{#snippet driveNode(node: DriveTreeNode, depth: number)}
  {@const Icon = iconFor(node.entry.kind)}
  {@const isFolder = node.entry.kind === "folder"}
  {@const isOpen = expandedFolders.has(node.entry.id)}
  <li class="brl-drive__node" role="none">
    <button
      type="button"
      class="brl-drive__row"
      style="padding-left: calc(var(--space-2) + {depth * 10}px);"
      draggable={!isFolder}
      ondragstart={(e) => !isFolder && handleDragStart(node.entry, e)}
      onclick={() => isFolder && toggleFolder(node.entry.id)}
      aria-expanded={isFolder ? isOpen : undefined}
      title={node.entry.name}
    >
      {#if isFolder}
        <span class="brl-drive__chev" class:brl-drive__chev--open={isOpen} aria-hidden="true">
          <ChevronRight size={11} />
        </span>
      {:else}
        <span class="brl-drive__chev brl-drive__chev--placeholder" aria-hidden="true"></span>
      {/if}
      <span class="brl-drive__icon" aria-hidden="true">
        <!-- svelte-ignore svelte_component_deprecated -->
        <svelte:component this={Icon} size={12} />
      </span>
      <span class="brl-drive__name">{node.entry.name}</span>
      {#if !isFolder}
        <span class="brl-drive__kind">{node.entry.kind.replace("_", " ")}</span>
      {/if}
    </button>

    {#if isFolder && isOpen && node.children.length > 0}
      <ul class="brl-drive__children" role="group">
        {#each node.children as child (child.entry.id)}
          {@render driveNode(child, depth + 1)}
        {/each}
      </ul>
    {/if}
  </li>
{/snippet}

<style>
  .brl-drive {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .brl-drive__header {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    padding: 10px var(--space-3) var(--space-2);
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.08));
  }

  .brl-drive__title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .brl-drive__scope {
    display: flex;
    gap: 0;
    padding: 2px;
    background: var(--bg-inset, rgba(0, 0, 0, 0.04));
    border-radius: var(--radius-sm, 4px);
  }

  .brl-drive__scope-btn {
    flex: 1;
    height: 22px;
    padding: 0 var(--space-2);
    border: none;
    background: transparent;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-muted);
    border-radius: 3px;
    cursor: pointer;
    transition: all 80ms ease-out;
  }

  .brl-drive__scope-btn:hover {
    color: var(--fg);
  }

  .brl-drive__scope-btn--active {
    background: var(--bg, #ffffff);
    color: var(--fg);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
  }

  :global(.dark) .brl-drive__scope-btn--active {
    background: #2a2a2a;
  }

  .brl-drive__body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: var(--space-1, 4px) 0;
  }

  .brl-drive__tree,
  .brl-drive__children {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .brl-drive__node {
    list-style: none;
  }

  .brl-drive__row {
    display: flex;
    align-items: center;
    gap: var(--space-1, 4px);
    width: 100%;
    min-height: 24px;
    padding-right: var(--space-2);
    border: none;
    background: transparent;
    cursor: pointer;
    text-align: left;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: 11.5px;
    transition: background 80ms ease-out;
  }

  .brl-drive__row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .brl-drive__chev {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 12px;
    height: 12px;
    flex-shrink: 0;
    color: var(--fg-subtle);
    transition: transform 100ms ease-out;
  }

  .brl-drive__chev--open {
    transform: rotate(90deg);
  }

  .brl-drive__chev--placeholder {
    width: 12px;
  }

  .brl-drive__icon {
    display: inline-flex;
    align-items: center;
    width: 14px;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .brl-drive__name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .brl-drive__kind {
    flex-shrink: 0;
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .brl-drive__empty,
  .brl-drive__error {
    padding: var(--space-6) var(--space-3);
    text-align: center;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .brl-drive__error {
    color: var(--signal-error, #eb4335);
  }
</style>
