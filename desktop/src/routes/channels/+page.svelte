<script lang="ts">
/**
 * /channels — Two-pane layout: channel list (left) + empty-state hero (right).
 * Redirects to /channels/<first-id> when channels exist.
 * CSS prefix: cp- (ChannelsPage)
 * LOC target: ≤200
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { MessageSquare } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { channelsQuery, createChannelMutation } from '$lib/api/queries/channels.js';
import ChannelList from '$lib/design/patterns/channels/ChannelList.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import type { ViewState } from '$lib/design/primitives/ViewPicker.svelte';
import ViewPicker from '$lib/design/primitives/ViewPicker.svelte';
import type { Channel, CreateChannelBody } from '$lib/domain/channels/types.js';

const queryClient = useQueryClient();

const chOptsStore = writable(untrack(() => channelsQuery() as CreateQueryOptions<Channel[]>));
const chQ = createQuery<Channel[]>(chOptsStore);
const channels = $derived(($chQ.data ?? []) as Channel[]);

// Redirect to first channel when list loads
$effect(() => {
  if (!$chQ.isLoading && channels.length > 0) {
    goto(`/channels/${channels[0].id}`, { replaceState: true });
  }
});

// ── New channel form ──────────────────────────────────────────────────────────
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

const createMut = createMutation<Channel, Error, CreateChannelBody>(
  createChannelMutation() as CreateMutationOptions<Channel, Error, CreateChannelBody>
);

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

function handleSelect(ch: Channel): void {
  void goto(`/channels/${ch.id}`);
}

let view = $state<ViewState>({ layout: 'list', density: 'comfortable', sort: 'recent' });
</script>

<div class="cp-shell">
  <!-- Left: channel list -->
  <aside class="cp-sidebar" aria-label="Channels">
    <div class="cp-sidebar-toolbar">
      <ViewPicker routeSlug="channels" bind:view />
    </div>
    <ChannelList
      {channels}
      isLoading={$chQ.isLoading}
      onSelect={handleSelect}
      onNew={() => { formOpen = true; }}
    />
  </aside>

  <!-- Right: empty state or create form -->
  <main class="cp-main">
    {#if formOpen}
      <div class="cp-form-wrap">
        <form
          class="cp-create-form"
          onsubmit={(e) => { e.preventDefault(); handleCreate(); }}
          aria-label="New channel form"
        >
          <h2 class="cp-form-title">Create a channel</h2>

          <div class="cp-field">
            <label class="cp-label" for="cp-name">Name</label>
            <input
              id="cp-name"
              class="cp-input"
              type="text"
              placeholder="e.g. engineering"
              bind:value={newName}
              required
              maxlength={64}
              autocomplete="off"
            />
          </div>

          <div class="cp-field">
            <label class="cp-label" for="cp-slug">Slug</label>
            <input
              id="cp-slug"
              class="cp-input cp-input--mono"
              type="text"
              placeholder="engineering"
              bind:value={newSlug}
              required
              maxlength={64}
              autocomplete="off"
            />
          </div>

          <div class="cp-field">
            <label class="cp-label" for="cp-visibility">Visibility</label>
            <select id="cp-visibility" class="cp-select" bind:value={newVisibility}>
              <option value="public">Public</option>
              <option value="private">Private</option>
            </select>
          </div>

          <div class="cp-form-actions">
            <button
              type="button"
              class="btn-compact btn-compact-ghost"
              onclick={() => { formOpen = false; }}
            >Cancel</button>
            <button
              class="btn-pill btn-pill-primary btn-pill-sm"
              type="submit"
              disabled={creating || !newName.trim() || !newSlug.trim()}
            >
              {creating ? 'Creating…' : 'Create channel'}
            </button>
          </div>
        </form>
      </div>
    {:else if !$chQ.isLoading}
      <EmptyState
        icon={MessageSquare as never}
        title="No channels yet"
        body="Channels are where your team communicates. Create one to get started."
        action="Create channel"
        onAction={() => { formOpen = true; }}
      />
    {/if}
  </main>
</div>

<style>
  .cp-shell {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  .cp-sidebar {
    width: 240px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    background: var(--bg-inset);
    display: flex;
    flex-direction: column;
  }

  .cp-sidebar-toolbar {
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .cp-main {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
  }

  .cp-form-wrap {
    width: 100%;
    max-width: 360px;
    padding: var(--space-6);
  }

  .cp-create-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .cp-form-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: -0.015em;
  }

  .cp-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .cp-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .cp-input,
  .cp-select {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 7px 10px;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .cp-input:focus,
  .cp-select:focus {
    border-color: var(--border-strong);
  }

  .cp-input--mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .cp-form-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
    padding-top: var(--space-2);
  }
</style>
