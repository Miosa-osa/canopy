<script lang="ts">
/**
 * /drive — Drive super-module main page.
 * Powered by Vault (the Drive Curator) via /api/v1/drive/*.
 *
 * Layout:
 *   - Top bar: Personal | Team scope toggle, search, "+ New" entry button
 *   - Left:    Tree view (collapsible folders, kind-iconed leaves)
 *   - Right:   Detail pane — kind-specific renderer for selected entry
 *
 * CSS prefix: dr-
 */
import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import {
  Archive,
  BookOpen,
  ChevronDown,
  ChevronRight,
  FileText,
  Folder,
  KeyRound,
  MessageSquareCode,
  Notebook,
  Plug,
  Plus,
  Search,
  Shield,
  Workflow,
} from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  archiveDriveEntry,
  createDriveEntry,
  driveSearchQuery,
  driveTreeQuery,
} from '$lib/api/queries/drive.js';
import { Button, Input, Modal } from '$lib/design/foundation';
import type {
  DriveEntry,
  DriveEntryCreate,
  DriveKind,
  DriveScope,
  DriveTree,
  DriveTreeNode,
} from '$lib/domain/drive/types.js';

const qc = useQueryClient();

// ── State ────────────────────────────────────────────────────────────────

let scope = $state<DriveScope>('personal');
let selectedId = $state<string | null>(null);
let expandedIds = $state<Set<string>>(new Set());
let searchTerm = $state('');
let creating = $state(false);
let createKind = $state<DriveKind>('folder');
let createSlug = $state('');
let createName = $state('');
let createBody = $state('');
let createError = $state<string | null>(null);

// ── Tree query (reactive on scope) ───────────────────────────────────────

const treeStore = writable(untrack(() => driveTreeQuery(scope) as CreateQueryOptions<DriveTree>));
$effect(() => {
  treeStore.set(driveTreeQuery(scope) as CreateQueryOptions<DriveTree>);
});
const treeQ = createQuery<DriveTree>(treeStore);

// ── Search query (only when term set) ────────────────────────────────────

const searchStore = writable(
  untrack(() => driveSearchQuery('', { scope }) as CreateQueryOptions<DriveEntry[]>)
);
$effect(() => {
  searchStore.set(driveSearchQuery(searchTerm, { scope }) as CreateQueryOptions<DriveEntry[]>);
});
const searchQ = createQuery<DriveEntry[]>(searchStore);

// ── Mutations ────────────────────────────────────────────────────────────

const createMut = createMutation({
  mutationFn: (entry: DriveEntryCreate) => createDriveEntry(entry),
  onSuccess: () => {
    qc.invalidateQueries({ queryKey: ['drive'] });
    creating = false;
    createSlug = '';
    createName = '';
    createBody = '';
    createError = null;
  },
  onError: (err: Error) => {
    createError = err.message;
  },
});

const archiveMut = createMutation({
  mutationFn: (id: string) => archiveDriveEntry(id),
  onSuccess: () => {
    qc.invalidateQueries({ queryKey: ['drive'] });
  },
});

// ── Seed data (shown when tree is empty) ─────────────────────────────────

const SEED_ENTRIES: DriveEntry[] = [
  {
    id: 'seed-1',
    slug: 'deploy-checklist',
    name: 'Deploy Checklist',
    kind: 'workflow',
    scope: 'team',
    parentId: null,
    body: { routine_id: 'example-routine' },
    ownerId: null,
    tags: [],
    position: 0,
    archivedAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'seed-2',
    slug: 'code-review-template',
    name: 'Code Review Template',
    kind: 'prompt',
    scope: 'team',
    parentId: null,
    body: {
      body: 'Review the following code for correctness, performance, and style.\n\n{{code}}',
    },
    ownerId: null,
    tags: [],
    position: 1,
    archivedAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: 'seed-3',
    slug: 'onboarding-runbook',
    name: 'Onboarding Runbook',
    kind: 'notebook',
    scope: 'team',
    parentId: null,
    body: { session_id: 'example-session', block_ids: [] },
    ownerId: null,
    tags: [],
    position: 2,
    archivedAt: null,
    insertedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

const SEED_NODES: DriveTreeNode[] = SEED_ENTRIES.map((e) => ({ entry: e, children: [] }));

// ── Derived ──────────────────────────────────────────────────────────────

const treeNodes = $derived($treeQ.data?.data ?? []);
const flatEntries = $derived(flatten(treeNodes));
const selectedEntry = $derived(
  selectedId ? (flatEntries.find((e) => e.id === selectedId) ?? null) : null
);
const showSearch = $derived(searchTerm.trim().length > 0);
const searchResults = $derived($searchQ.data ?? []);

// ── Helpers ──────────────────────────────────────────────────────────────

function flatten(nodes: DriveTreeNode[]): DriveEntry[] {
  const out: DriveEntry[] = [];
  for (const n of nodes) {
    out.push(n.entry);
    out.push(...flatten(n.children));
  }
  return out;
}

function toggle(id: string) {
  const next = new Set(expandedIds);
  if (next.has(id)) {
    next.delete(id);
  } else {
    next.add(id);
  }
  expandedIds = next;
}

function select(id: string) {
  selectedId = id;
}

function setScope(s: DriveScope) {
  scope = s;
  selectedId = null;
}

function iconFor(kind: DriveKind) {
  switch (kind) {
    case 'folder':
      return Folder;
    case 'workflow':
      return Workflow;
    case 'prompt':
      return MessageSquareCode;
    case 'notebook':
      return Notebook;
    case 'env_vars':
      return KeyRound;
    case 'mcp_server':
      return Plug;
    case 'rule':
      return Shield;
    default:
      return FileText;
  }
}

function submitCreate(e: Event) {
  e.preventDefault();
  createError = null;
  if (!createSlug.trim() || !createName.trim()) {
    createError = 'Slug and name are required.';
    return;
  }

  let body: Record<string, unknown> = {};
  if (createBody.trim()) {
    try {
      body = JSON.parse(createBody);
    } catch {
      createError = 'Body must be valid JSON.';
      return;
    }
  }

  $createMut.mutate({
    slug: createSlug.trim(),
    name: createName.trim(),
    kind: createKind,
    scope,
    body,
  });
}

function handleArchive(id: string) {
  if (confirm('Archive this entry?')) {
    $archiveMut.mutate(id);
    if (selectedId === id) selectedId = null;
  }
}
</script>

<div class="dr-page">
  <header class="dr-header">
    <div class="dr-header-left">
      <h1 class="dr-title">Drive</h1>
      <span class="dr-subtitle">
        Powered by Vault · Knowledge store
      </span>
    </div>
    <div class="dr-header-right">
      <a href="/settings/drive" class="dr-settings-link">Settings</a>
    </div>
  </header>

  <div class="dr-toolbar">
    <div class="dr-scope-toggle" role="tablist" aria-label="Drive scope">
      <button
        type="button"
        class="dr-scope-btn"
        class:active={scope === "personal"}
        role="tab"
        aria-selected={scope === "personal"}
        onclick={() => setScope("personal")}
      >
        Personal
      </button>
      <button
        type="button"
        class="dr-scope-btn"
        class:active={scope === "team"}
        role="tab"
        aria-selected={scope === "team"}
        onclick={() => setScope("team")}
      >
        Team
      </button>
    </div>

    <div class="dr-search">
      <Search size={14} aria-hidden="true" />
      <Input
        type="text"
        placeholder="Search Drive…"
        bind:value={searchTerm}
        aria-label="Search drive entries"
      />
    </div>

    <Button onclick={() => (creating = true)} aria-label="Create new drive entry">
      <Plus size={14} aria-hidden="true" />
      New
    </Button>
  </div>

  <div class="dr-body">
    <!-- Tree pane -->
    <aside class="dr-tree" aria-label="Drive tree">
      {#if $treeQ.isLoading}
        <p class="dr-empty">Loading…</p>
      {:else if showSearch}
        {#if searchResults.length === 0}
          <p class="dr-empty">No matches for "{searchTerm}".</p>
        {:else}
          <ul class="dr-list" role="list">
            {#each searchResults as entry (entry.id)}
              {@const Icon = iconFor(entry.kind)}
              <li>
                <button
                  type="button"
                  class="dr-row"
                  class:selected={selectedId === entry.id}
                  onclick={() => select(entry.id)}
                  aria-label={`Open ${entry.name}`}
                >
                  <Icon size={14} aria-hidden="true" />
                  <span class="dr-row-name">{entry.name}</span>
                  <span class="dr-row-kind">{entry.kind}</span>
                </button>
              </li>
            {/each}
          </ul>
        {/if}
      {:else}
        {#if treeNodes.length === 0}
          <p class="dr-empty dr-seed-hint">Examples — click <strong>+ New</strong> to add real entries.</p>
        {/if}
        <ul class="dr-list" role="list">
          {#each (treeNodes.length === 0 ? SEED_NODES : treeNodes) as node (node.entry.id)}
            {@render treeBranch(node, 0)}
          {/each}
        </ul>
      {/if}
    </aside>

    <!-- Detail pane -->
    <section class="dr-detail" aria-label="Drive entry detail">
      {#if selectedEntry}
        {@render detail(selectedEntry)}
      {:else}
        <div class="dr-detail-empty">
          <p>Select an entry to view its details.</p>
        </div>
      {/if}
    </section>
  </div>
</div>

{#snippet treeBranch(node: DriveTreeNode, depth: number)}
  {@const Icon = iconFor(node.entry.kind)}
  {@const expanded = expandedIds.has(node.entry.id)}
  {@const hasChildren = node.children.length > 0}
  <li>
    <div class="dr-tree-row" style="padding-left: {depth * 1.1 + 0.5}rem">
      {#if hasChildren}
        <button
          type="button"
          class="dr-tree-chevron"
          aria-label={expanded ? "Collapse" : "Expand"}
          aria-expanded={expanded}
          onclick={() => toggle(node.entry.id)}
        >
          {#if expanded}
            <ChevronDown size={12} aria-hidden="true" />
          {:else}
            <ChevronRight size={12} aria-hidden="true" />
          {/if}
        </button>
      {:else}
        <span class="dr-tree-spacer" aria-hidden="true"></span>
      {/if}
      <button
        type="button"
        class="dr-row"
        class:selected={selectedId === node.entry.id}
        onclick={() => select(node.entry.id)}
        aria-label={`Open ${node.entry.name}`}
      >
        <Icon size={14} aria-hidden="true" />
        <span class="dr-row-name">{node.entry.name}</span>
        <span class="dr-row-kind">{node.entry.kind}</span>
      </button>
    </div>
    {#if expanded && hasChildren}
      <ul class="dr-list" role="list">
        {#each node.children as child (child.entry.id)}
          {@render treeBranch(child, depth + 1)}
        {/each}
      </ul>
    {/if}
  </li>
{/snippet}

{#snippet detail(entry: DriveEntry)}
  <header class="dr-detail-header">
    <div class="dr-detail-title-row">
      <h2 class="dr-detail-title">{entry.name}</h2>
      <span class="dr-detail-kind">{entry.kind}</span>
    </div>
    <div class="dr-detail-meta">
      <span>scope: {entry.scope}</span>
      <span>·</span>
      <span class="dr-mono">{entry.slug}</span>
      {#if entry.tags.length > 0}
        <span>·</span>
        <span>{entry.tags.join(", ")}</span>
      {/if}
    </div>
  </header>

  <div class="dr-detail-body">
    {#if entry.kind === "folder"}
      {@render folderRenderer(entry)}
    {:else if entry.kind === "workflow"}
      {@render workflowRenderer(entry)}
    {:else if entry.kind === "prompt"}
      {@render promptRenderer(entry)}
    {:else if entry.kind === "notebook"}
      {@render notebookRenderer(entry)}
    {:else if entry.kind === "env_vars"}
      {@render envVarsRenderer(entry)}
    {:else if entry.kind === "mcp_server"}
      {@render mcpServerRenderer(entry)}
    {:else if entry.kind === "rule"}
      {@render ruleRenderer(entry)}
    {/if}
  </div>

  <footer class="dr-detail-footer">
    <a href={`/drive/${entry.slug}`} class="dr-link">Open deep link →</a>
    <button
      type="button"
      class="dr-link dr-link-danger"
      onclick={() => handleArchive(entry.id)}
      disabled={$archiveMut.isPending}
    >
      <Archive size={12} aria-hidden="true" />
      Archive
    </button>
  </footer>
{/snippet}

{#snippet folderRenderer(entry: DriveEntry)}
  {@const children = flatEntries.filter((e) => e.parentId === entry.id)}
  <p class="dr-section-label">Children ({children.length})</p>
  {#if children.length === 0}
    <p class="dr-empty">Empty folder.</p>
  {:else}
    <ul class="dr-children-list" role="list">
      {#each children as child (child.id)}
        {@const Icon = iconFor(child.kind)}
        <li>
          <button
            type="button"
            class="dr-row"
            onclick={() => select(child.id)}
            aria-label={`Open ${child.name}`}
          >
            <Icon size={14} aria-hidden="true" />
            <span class="dr-row-name">{child.name}</span>
            <span class="dr-row-kind">{child.kind}</span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
{/snippet}

{#snippet workflowRenderer(entry: DriveEntry)}
  {@const routineId = entry.body.routine_id as string | undefined}
  <p class="dr-section-label">Linked routine</p>
  {#if routineId}
    <a class="dr-link" href={`/routines/${routineId}`}>
      <Workflow size={14} aria-hidden="true" />
      {routineId}
    </a>
  {:else}
    <p class="dr-empty">No routine linked.</p>
  {/if}
{/snippet}

{#snippet promptRenderer(entry: DriveEntry)}
  {@const body = (entry.body.body as string | undefined) ?? ""}
  {@const variables = (entry.body.variables as unknown[] | undefined) ?? []}
  <p class="dr-section-label">Body</p>
  <pre class="dr-code">{body || "(empty)"}</pre>
  {#if variables.length > 0}
    <p class="dr-section-label">Variables</p>
    <ul class="dr-list" role="list">
      {#each variables as v, i (i)}
        <li class="dr-mono dr-var">{JSON.stringify(v)}</li>
      {/each}
    </ul>
  {/if}
{/snippet}

{#snippet notebookRenderer(entry: DriveEntry)}
  {@const sessionId = entry.body.session_id as string | undefined}
  {@const blockIds = (entry.body.block_ids as string[] | undefined) ?? []}
  <p class="dr-section-label">Linked session</p>
  {#if sessionId}
    <a class="dr-link" href={`/sessions/${sessionId}`}>
      <Notebook size={14} aria-hidden="true" />
      {sessionId}
    </a>
    <p class="dr-section-label">Blocks ({blockIds.length})</p>
    {#if blockIds.length > 0}
      <ul class="dr-list" role="list">
        {#each blockIds as bid (bid)}
          <li class="dr-mono">{bid}</li>
        {/each}
      </ul>
    {/if}
  {:else}
    <p class="dr-empty">No session linked.</p>
  {/if}
{/snippet}

{#snippet envVarsRenderer(entry: DriveEntry)}
  {@const ids = (entry.body.vault_secret_ids as string[] | undefined) ?? []}
  <p class="dr-section-label">Vault secret refs ({ids.length})</p>
  {#if ids.length === 0}
    <p class="dr-empty">No secret references.</p>
  {:else}
    <ul class="dr-list" role="list">
      {#each ids as id (id)}
        <li class="dr-mono dr-secret">
          <KeyRound size={12} aria-hidden="true" />
          {id}
        </li>
      {/each}
    </ul>
  {/if}
  <p class="dr-hint">
    Plaintext values live in the credential vault — Drive only references them.
  </p>
{/snippet}

{#snippet mcpServerRenderer(entry: DriveEntry)}
  {@const serverId = entry.body.mcp_server_id as string | undefined}
  <p class="dr-section-label">Linked MCP server</p>
  {#if serverId}
    <span class="dr-mono">
      <Plug size={14} aria-hidden="true" />
      {serverId}
    </span>
  {:else}
    <p class="dr-empty">No MCP server linked.</p>
  {/if}
{/snippet}

{#snippet ruleRenderer(entry: DriveEntry)}
  {@const body = (entry.body.body as string | undefined) ?? ""}
  {@const appliesTo = (entry.body.applies_to as string[] | undefined) ?? []}
  <p class="dr-section-label">Rule body</p>
  <pre class="dr-code">{body || "(empty)"}</pre>
  <p class="dr-section-label">Applies to</p>
  {#if appliesTo.length === 0}
    <p class="dr-empty">All agents.</p>
  {:else}
    <ul class="dr-list" role="list">
      {#each appliesTo as slug (slug)}
        <li class="dr-mono">{slug}</li>
      {/each}
    </ul>
  {/if}
{/snippet}

<!-- Create modal -->
{#if creating}
  <Modal open={creating} onOpenChange={(v) => (creating = v)}>
    <form class="dr-create-form" onsubmit={submitCreate}>
      <h2 class="dr-create-title">New drive entry</h2>

      <label class="dr-field">
        <span>Kind</span>
        <select bind:value={createKind} class="dr-select" aria-label="Entry kind">
          <option value="folder">Folder</option>
          <option value="workflow">Workflow</option>
          <option value="prompt">Prompt</option>
          <option value="notebook">Notebook</option>
          <option value="env_vars">Env vars</option>
          <option value="mcp_server">MCP server</option>
          <option value="rule">Rule</option>
        </select>
      </label>

      <label class="dr-field">
        <span>Slug</span>
        <Input bind:value={createSlug} placeholder="lowercase-with-dashes" />
      </label>

      <label class="dr-field">
        <span>Name</span>
        <Input bind:value={createName} placeholder="Display name" />
      </label>

      <label class="dr-field">
        <span>Body (JSON, optional)</span>
        <textarea
          class="dr-textarea"
          bind:value={createBody}
          rows="5"
          placeholder="e.g. routine_id: some-id (JSON)"
        ></textarea>
      </label>

      {#if createError}
        <p class="dr-error" role="alert">{createError}</p>
      {/if}

      <div class="dr-form-actions">
        <Button type="button" onclick={() => (creating = false)}>Cancel</Button>
        <Button type="submit" disabled={$createMut.isPending}>
          {$createMut.isPending ? "Creating…" : "Create"}
        </Button>
      </div>
    </form>
  </Modal>
{/if}

<style>
  .dr-page {
    display: flex;
    flex-direction: column;
    height: 100vh;
    color: var(--cnp-fg);
  }

  .dr-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    padding: 1.25rem 2rem 0.75rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .dr-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.75rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0;
  }

  .dr-subtitle {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .dr-settings-link {
    color: var(--cnp-fg-muted);
    text-decoration: none;
    font-size: 0.85rem;
    padding: 0.25rem 0.5rem;
    border-radius: 4px;
  }

  .dr-settings-link:hover {
    color: var(--cnp-fg);
    background: var(--cnp-bg-elev);
  }

  .dr-toolbar {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.75rem 2rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .dr-scope-toggle {
    display: inline-flex;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    overflow: hidden;
  }

  .dr-scope-btn {
    background: transparent;
    border: 0;
    padding: 0.4rem 0.85rem;
    font: inherit;
    color: var(--cnp-fg-muted);
    cursor: pointer;
  }

  .dr-scope-btn:hover {
    color: var(--cnp-fg);
  }

  .dr-scope-btn.active {
    color: var(--cnp-fg);
    background: var(--cnp-bg-elev);
  }

  .dr-search {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    flex: 1;
    color: var(--cnp-fg-muted);
  }

  .dr-body {
    display: grid;
    grid-template-columns: minmax(260px, 320px) 1fr;
    flex: 1;
    min-height: 0;
  }

  .dr-tree {
    border-right: 1px solid var(--cnp-border);
    overflow-y: auto;
    padding: 0.5rem;
    background: var(--cnp-bg);
  }

  .dr-detail {
    overflow-y: auto;
    padding: 1.5rem 2rem;
  }

  .dr-detail-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.9rem;
  }

  .dr-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .dr-tree-row {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }

  .dr-tree-chevron {
    background: transparent;
    border: 0;
    color: var(--cnp-fg-muted);
    cursor: pointer;
    padding: 0.15rem;
    display: inline-flex;
  }

  .dr-tree-spacer {
    display: inline-block;
    width: 1.05rem;
  }

  .dr-row {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    width: 100%;
    padding: 0.3rem 0.5rem;
    background: transparent;
    border: 0;
    border-radius: 4px;
    color: var(--cnp-fg);
    font: inherit;
    text-align: left;
    cursor: pointer;
  }

  .dr-row:hover {
    background: var(--cnp-bg-elev);
  }

  .dr-row.selected {
    background: color-mix(in oklch, var(--cnp-accent) 14%, transparent);
  }

  .dr-row-name {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dr-row-kind {
    font-size: 0.7rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .dr-detail-header {
    margin-bottom: 1.25rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .dr-detail-title-row {
    display: flex;
    align-items: baseline;
    gap: 0.6rem;
  }

  .dr-detail-title {
    font-size: 1.4rem;
    font-weight: 500;
    margin: 0;
  }

  .dr-detail-kind {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .dr-detail-meta {
    margin-top: 0.25rem;
    display: flex;
    gap: 0.4rem;
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .dr-detail-body {
    margin-bottom: 1.5rem;
  }

  .dr-detail-footer {
    display: flex;
    gap: 0.75rem;
    padding-top: 1rem;
    border-top: 1px solid var(--cnp-border);
  }

  .dr-section-label {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--cnp-fg-muted);
    margin: 1rem 0 0.4rem;
  }

  .dr-section-label:first-child {
    margin-top: 0;
  }

  .dr-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0;
  }

  .dr-hint {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    margin-top: 0.6rem;
  }

  .dr-mono {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
  }

  .dr-code {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    padding: 0.75rem;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
    white-space: pre-wrap;
    overflow-x: auto;
  }

  .dr-secret {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.25rem 0;
  }

  .dr-var {
    padding: 0.25rem 0;
  }

  .dr-link {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    color: var(--cnp-accent);
    text-decoration: none;
    font-size: 0.85rem;
    background: transparent;
    border: 0;
    padding: 0.2rem 0;
    cursor: pointer;
    font: inherit;
  }

  .dr-link:hover {
    text-decoration: underline;
  }

  .dr-link-danger {
    color: var(--cnp-warn, #d97706);
  }

  .dr-link-danger:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .dr-children-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .dr-create-form {
    display: flex;
    flex-direction: column;
    gap: 0.85rem;
    min-width: 360px;
    padding: 1.25rem;
  }

  .dr-create-title {
    font-size: 1.1rem;
    font-weight: 500;
    margin: 0 0 0.25rem;
  }

  .dr-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .dr-select,
  .dr-textarea {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    font: inherit;
    padding: 0.4rem 0.5rem;
  }

  .dr-textarea {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
    resize: vertical;
  }

  .dr-error {
    color: #dc2626;
    font-size: 0.8rem;
    margin: 0;
  }

  .dr-form-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }
</style>
