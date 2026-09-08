<script lang="ts">
/**
 * /chat — Thread list: pinned-then-recent + "+ New thread" form.
 * CSS prefix: cl- (ChatList)
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
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import { createThreadMutation, threadsQuery } from '$lib/api/queries/chat.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Agent } from '$lib/domain/agents/types.js';
import type { CreateThreadBody, CreateThreadResponse, Thread } from '$lib/domain/chat/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const queryClient = useQueryClient();

// ── Threads list ──────────────────────────────────────────────────────────────

const threadsOptsStore = writable(untrack(() => threadsQuery() as CreateQueryOptions<Thread[]>));
const threadsQ = createQuery<Thread[]>(threadsOptsStore);
const allThreads = $derived(($threadsQ.data ?? []) as Thread[]);

const pinnedThreads = $derived(allThreads.filter((t) => t.pinned && !t.archivedAt));
const recentThreads = $derived(
  allThreads
    .filter((t) => !t.pinned && !t.archivedAt)
    .sort((a, b) => ((b.lastMessageAt ?? b.updatedAt) > (a.lastMessageAt ?? a.updatedAt) ? 1 : -1))
);

// ── Hired agents (for runtime/agent picker in new thread form) ────────────────

const agentsOptsStore = writable(untrack(() => hiredAgentsQuery() as CreateQueryOptions<Agent[]>));
const agentsQ = createQuery<Agent[]>(agentsOptsStore);
const hiredAgents = $derived(($agentsQ.data ?? []) as Agent[]);

// ── Create form ───────────────────────────────────────────────────────────────

let createOpen = $state(false);
let newTitle = $state('');
let newAgent = $state('');
let newRuntime = $state('claude-code');
let newPrompt = $state('');
let createError = $state<string | null>(null);

const RUNTIMES = [
  { slug: 'claude-code', name: 'Claude Code' },
  { slug: 'codex', name: 'Codex' },
  { slug: 'gemini', name: 'Gemini' },
];

const createMut = createMutation<CreateThreadResponse, Error, CreateThreadBody>(
  createThreadMutation() as CreateMutationOptions<CreateThreadResponse, Error, CreateThreadBody>
);

function openCreate(): void {
  createOpen = true;
  createError = null;
}

function closeCreate(): void {
  createOpen = false;
  newTitle = '';
  newAgent = '';
  newRuntime = 'claude-code';
  newPrompt = '';
  createError = null;
}

function submitCreate(e: SubmitEvent): void {
  e.preventDefault();
  createError = null;

  const body: CreateThreadBody = {
    runtimeType: newRuntime,
  };
  if (newTitle.trim()) body.title = newTitle.trim();
  if (newAgent.trim()) body.agentSlug = newAgent.trim();
  if (newPrompt.trim()) body.prompt = newPrompt.trim();

  $createMut.mutate(body, {
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['chat'] });
      toasts.success('Thread created');
      closeCreate();
      goto(`/chat/${res.thread.id}`);
    },
    onError: (err: Error) => {
      createError = err.message ?? 'Create failed';
    },
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatTime(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  const diff = Date.now() - d.getTime();
  const mins = Math.floor(diff / 60_000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}
</script>

<div class="cl-page">
  <!-- Header -->
  <header class="cl-header">
    <h1 class="cl-title">Chat</h1>
    <button
      class="btn-pill btn-pill-primary btn-pill-sm"
      onclick={openCreate}
      aria-label="Start new thread"
    >
      + New thread
    </button>
  </header>

  <!-- Create form -->
  {#if createOpen}
    <form class="cl-create-form glass-panel" onsubmit={submitCreate} aria-label="New thread form">
      <div class="cl-create-row">
        <label class="cl-label" for="cl-new-title">Title (optional)</label>
        <input
          id="cl-new-title"
          class="cl-input"
          type="text"
          bind:value={newTitle}
          placeholder="Thread title"
          autocomplete="off"
        />
      </div>

      <div class="cl-create-grid">
        <div class="cl-create-field">
          <label class="cl-label" for="cl-new-agent">Agent</label>
          <select id="cl-new-agent" class="cl-select" bind:value={newAgent} aria-label="Select agent">
            <option value="">Any</option>
            {#each hiredAgents as a (a.slug)}
              <option value={a.slug}>{a.name}</option>
            {/each}
          </select>
        </div>
        <div class="cl-create-field">
          <label class="cl-label" for="cl-new-runtime">Runtime</label>
          <select id="cl-new-runtime" class="cl-select" bind:value={newRuntime} aria-label="Select runtime">
            {#each RUNTIMES as r (r.slug)}
              <option value={r.slug}>{r.name}</option>
            {/each}
          </select>
        </div>
      </div>

      <div class="cl-create-row">
        <label class="cl-label" for="cl-new-prompt">Initial prompt (optional)</label>
        <textarea
          id="cl-new-prompt"
          class="cl-input cl-textarea"
          bind:value={newPrompt}
          placeholder="What are we working on?"
          rows={3}
        ></textarea>
      </div>

      {#if createError}
        <p class="cl-create-error" role="alert">{createError}</p>
      {/if}

      <div class="cl-create-actions">
        <button
          type="button"
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={closeCreate}
          disabled={$createMut.isPending}
        >
          Cancel
        </button>
        <button
          type="submit"
          class="btn-pill btn-pill-primary btn-pill-sm"
          disabled={$createMut.isPending}
          aria-busy={$createMut.isPending}
        >
          {$createMut.isPending ? 'Starting…' : 'Start thread'}
        </button>
      </div>
    </form>
  {/if}

  <!-- Thread list -->
  {#if $threadsQ.isError}
    <EmptyState
      title="Couldn't load threads"
      body={($threadsQ.error as Error).message || 'Check your connection and try again.'}
      action="Retry"
      onAction={() => $threadsQ.refetch()}
    />
  {:else if $threadsQ.isLoading}
    <div class="cl-skeleton-wrap">
      <SkeletonList count={6} height="2.75rem" gap="0.375rem" />
    </div>
  {:else if allThreads.length === 0}
    <EmptyState
      icon={MessageSquare as never}
      title="No threads yet"
      body="Start a thread to chat with an agent."
      action="+ New thread"
      onAction={openCreate}
    />
  {:else}
    <div class="cl-list-wrap">
      {#if pinnedThreads.length > 0}
        <p class="cl-section-label">Pinned</p>
        {#each pinnedThreads as t (t.id)}
          <button
            class="cl-thread-row cl-thread-row--pinned"
            onclick={() => goto(`/chat/${t.id}`)}
            aria-label="Open thread: {t.title ?? 'Untitled'}"
          >
            <span class="cl-pin-icon" aria-label="Pinned">📌</span>
            <span class="cl-thread-title">{t.title ?? 'Untitled'}</span>
            <span class="cl-thread-meta">
              {#if t.agentSlug}
                <span class="cl-thread-agent">{t.agentSlug}</span>
              {/if}
              <time class="cl-thread-time" datetime={t.lastMessageAt ?? t.updatedAt}>
                {formatTime(t.lastMessageAt ?? t.updatedAt)}
              </time>
            </span>
          </button>
        {/each}
      {/if}

      {#if recentThreads.length > 0}
        {#if pinnedThreads.length > 0}
          <p class="cl-section-label">Recent</p>
        {/if}
        {#each recentThreads as t (t.id)}
          <button
            class="cl-thread-row"
            onclick={() => goto(`/chat/${t.id}`)}
            aria-label="Open thread: {t.title ?? 'Untitled'}"
          >
            <span class="cl-thread-title">{t.title ?? 'Untitled'}</span>
            <span class="cl-thread-meta">
              {#if t.agentSlug}
                <span class="cl-thread-agent">{t.agentSlug}</span>
              {/if}
              <time class="cl-thread-time" datetime={t.lastMessageAt ?? t.updatedAt}>
                {formatTime(t.lastMessageAt ?? t.updatedAt)}
              </time>
            </span>
          </button>
        {/each}
      {/if}
    </div>
  {/if}
</div>

<style>
  .cl-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    height: 100%;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* Header */
  .cl-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .cl-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    line-height: var(--lh-2xl);
  }

  /* Create form */
  .cl-create-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    border-radius: var(--radius-lg);
  }

  .cl-create-row {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .cl-create-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--space-3);
  }

  .cl-create-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .cl-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: var(--tracking-xs);
  }

  .cl-input,
  .cl-select {
    padding: 5px 8px;
    border-radius: var(--radius-md);
    border: 1px solid var(--border);
    background: var(--bg-inset);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color 0.12s ease;
    width: 100%;
  }

  .cl-input:focus,
  .cl-select:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .cl-textarea {
    resize: vertical;
    min-height: 64px;
  }

  .cl-create-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  .cl-create-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
  }

  /* Thread list */
  .cl-skeleton-wrap {
    flex: 1;
  }

  .cl-list-wrap {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .cl-section-label {
    margin: var(--space-2) 0 var(--space-1);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .cl-thread-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-md);
    background: transparent;
    border: none;
    cursor: pointer;
    width: 100%;
    text-align: left;
    min-height: 40px;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .cl-thread-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
  }

  .cl-thread-row--pinned {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  .cl-pin-icon {
    font-size: 12px;
    flex-shrink: 0;
  }

  .cl-thread-title {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .cl-thread-meta {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .cl-thread-agent {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .cl-thread-time {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
  }
</style>
