<script lang="ts">
/**
 * /channels — Channel list page.
 * Header: "Channels" + "+ New channel" pill.
 * List: icon + name + unread count badge + relative timestamp.
 * Grouped by workspace_slug when set; flat "All channels" fallback.
 * Click → navigate /channels/:id.
 * LOC target: ≤ 250.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { Hash, Lock, MessageSquare } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { channelsQuery, createChannelMutation } from '$lib/api/queries/channels.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import type { Channel, CreateChannelBody } from '$lib/domain/channels/types.js';

const queryClient = useQueryClient();

const chOptsStore = writable(
  untrack(() => channelsQuery() as CreateQueryOptions<Channel[]>)
);
const chQ = createQuery<Channel[]>(chOptsStore);
const channels = $derived(($chQ.data ?? []) as Channel[]);

const createMut = createMutation<Channel, Error, CreateChannelBody>(
  createChannelMutation() as CreateMutationOptions<Channel, Error, CreateChannelBody>
);

// ── New channel form state ───────────────────────────────────────────────────
let formOpen = $state(false);
let newName = $state('');
let newSlug = $state('');
let newVisibility = $state<'public' | 'private'>('public');
let creating = $state(false);

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .slice(0, 64);
}

$effect(() => {
  if (newName && !newSlug) {
    newSlug = slugify(newName);
  }
});

function handleCreate(): void {
  if (!newName.trim() || !newSlug.trim()) return;
  creating = true;
  $createMut.mutate(
    { name: newName.trim(), slug: newSlug.trim(), visibility: newVisibility },
    {
      onSuccess: (ch) => {
        queryClient.invalidateQueries({ queryKey: ['channels'] });
        formOpen = false;
        newName = '';
        newSlug = '';
        newVisibility = 'public';
        creating = false;
        void goto(`/channels/${ch.id}`);
      },
      onError: () => {
        creating = false;
      },
    }
  );
}

// ── Grouping ─────────────────────────────────────────────────────────────────
const grouped = $derived(() => {
  const map = new Map<string, Channel[]>();
  for (const ch of channels) {
    const key = ch.workspaceSlug ?? '__all__';
    const bucket = map.get(key) ?? [];
    bucket.push(ch);
    map.set(key, bucket);
  }
  return map;
});

const groupKeys = $derived(
  [...grouped().keys()].sort((a, b) => {
    if (a === '__all__') return 1;
    if (b === '__all__') return -1;
    return a.localeCompare(b);
  })
);

function groupLabel(key: string): string {
  return key === '__all__' ? 'All channels' : key;
}

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h`;
  return `${Math.floor(hrs / 24)}d`;
}

</script>

<div class="ch-page">
  <!-- Header -->
  <header class="ch-header">
    <h1 class="ch-title">Channels</h1>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={() => { formOpen = !formOpen; }}
      aria-label="Create a new channel"
      aria-expanded={formOpen}
    >
      + New channel
    </button>
  </header>

  <!-- Inline create form -->
  {#if formOpen}
    <form
      class="ch-create-form glass-panel"
      onsubmit={(e) => { e.preventDefault(); handleCreate(); }}
      aria-label="New channel form"
    >
      <div class="ch-form-row">
        <input
          class="ch-input"
          type="text"
          placeholder="Channel name"
          bind:value={newName}
          aria-label="Channel name"
          required
          maxlength={64}
        />
        <input
          class="ch-input ch-input--slug"
          type="text"
          placeholder="slug"
          bind:value={newSlug}
          aria-label="Channel slug"
          required
          maxlength={64}
        />
        <select class="ch-select" bind:value={newVisibility} aria-label="Visibility">
          <option value="public">Public</option>
          <option value="private">Private</option>
        </select>
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          type="submit"
          disabled={creating || !newName.trim() || !newSlug.trim()}
          aria-label="Create channel"
        >
          {creating ? 'Creating…' : 'Create'}
        </button>
        <button
          class="btn-compact btn-compact-ghost"
          type="button"
          onclick={() => { formOpen = false; }}
          aria-label="Cancel"
        >
          Cancel
        </button>
      </div>
    </form>
  {/if}

  <!-- Channel list -->
  <main class="ch-list-wrap">
    {#if $chQ.isLoading}
      <div class="ch-list" aria-busy="true">
        {#each Array(6) as _, i (i)}
          <div class="ch-skeleton" aria-hidden="true">
            <div class="ch-sk ch-sk--icon"></div>
            <div class="ch-sk-lines">
              <div class="ch-sk ch-sk--name"></div>
              <div class="ch-sk ch-sk--sub"></div>
            </div>
          </div>
        {/each}
      </div>
    {:else if $chQ.isError}
      <EmptyState
        icon={MessageSquare as never}
        title="Failed to load channels"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $chQ.refetch()}
      />
    {:else if channels.length === 0}
      <EmptyState
        icon={MessageSquare as never}
        title="No channels yet"
        body="Create your first channel to start collaborating."
        action="New channel"
        onAction={() => { formOpen = true; }}
      />
    {:else}
      <div class="ch-list">
        {#each groupKeys as key (key)}
          <section aria-label={groupLabel(key)}>
            {#if groupKeys.length > 1 || key !== '__all__'}
              <p class="ch-group-label">{groupLabel(key)}</p>
            {/if}
            {#each grouped().get(key) ?? [] as ch (ch.id)}
              <button
                class="ch-row"
                onclick={() => goto(`/channels/${ch.id}`)}
                aria-label="Open channel {ch.name}"
              >
                <span class="ch-row__icon" aria-hidden="true">
                  {#if ch.icon}
                    {ch.icon}
                  {:else if ch.visibility === 'private'}
                    <Lock size={14} />
                  {:else}
                    <Hash size={14} />
                  {/if}
                </span>
                <span class="ch-row__name">{ch.name}</span>
                <span class="ch-row__time">{relativeTime(ch.updatedAt)}</span>
              </button>
            {/each}
          </section>
        {/each}
      </div>
    {/if}
  </main>
</div>


<style>
  .ch-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .ch-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .ch-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.025em;
  }

  /* Create form */
  .ch-create-form {
    padding: var(--space-3) var(--space-6);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .ch-form-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .ch-input {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
    min-width: 140px;
  }

  .ch-input:focus {
    border-color: var(--border-strong);
  }

  .ch-input--slug {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    min-width: 120px;
  }

  .ch-select {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    outline: none;
    cursor: pointer;
  }

  /* List */
  .ch-list-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-3) var(--space-4);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ch-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .ch-group-label {
    margin: var(--space-3) 0 var(--space-1);
    padding: 0 var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .ch-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: 100%;
    padding: var(--space-2) var(--space-3);
    border: none;
    background: transparent;
    border-radius: var(--radius-md);
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-instant) var(--ease-out);
    color: var(--fg);
  }

  .ch-row:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
  }

  .ch-row__icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    flex-shrink: 0;
    color: var(--fg-subtle);
    font-size: 14px;
    line-height: 1;
  }

  .ch-row__name {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ch-row__time {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  /* Skeletons */
  .ch-skeleton {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
  }

  .ch-sk {
    animation: ch-pulse 1.5s ease-in-out infinite;
    background: var(--border);
    border-radius: var(--radius-sm);
  }

  .ch-sk--icon { width: 20px; height: 20px; border-radius: 50%; flex-shrink: 0; }
  .ch-sk-lines { display: flex; flex-direction: column; gap: 4px; flex: 1; }
  .ch-sk--name { height: 12px; width: 60%; }
  .ch-sk--sub { height: 10px; width: 35%; }

  @keyframes ch-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.65; }
  }
</style>
