<script lang="ts">
/**
 * /chat/[id] — Thread detail: transcript + composer + metadata panel.
 * Live streaming via subscribeToSession() when last session is running.
 * Export downloads the thread as markdown.
 * CSS prefix: ct- (ChatThread)
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Download, Pin, Trash2 } from 'lucide-svelte';
import { onMount, untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  continueThreadMutation,
  deleteThreadMutation,
  exportThreadMarkdown,
  threadQuery,
  updateThreadMutation,
} from '$lib/api/queries/chat.js';
import { subscribeToSession } from '$lib/api/realtime.js';
import Composer from '$lib/design/patterns/Composer.svelte';
import PushPanel from '$lib/design/patterns/PushPanel.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import TranscriptView from '$lib/design/patterns/TranscriptView.svelte';
import type {
  ContinueThreadBody,
  ContinueThreadResponse,
  Thread,
  ThreadDetail,
  UpdateThreadBody,
} from '$lib/domain/chat/types.js';
import type { SessionStatus, TranscriptEntry } from '$lib/domain/sessions/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

const threadId = $derived(page.params.id ?? '');
const queryClient = useQueryClient();

// ── Query ────────────────────────────────────────────────────────────────────

const queryOptsStore = writable(
  untrack(() => threadQuery(threadId) as CreateQueryOptions<ThreadDetail>)
);
$effect(() => {
  queryOptsStore.set(threadQuery(threadId) as CreateQueryOptions<ThreadDetail>);
});
const query = createQuery<ThreadDetail>(queryOptsStore);
const detail = $derived($query.data as ThreadDetail | undefined);
const thread = $derived(detail?.thread as Thread | undefined);

// ── Live transcript ───────────────────────────────────────────────────────────

let messages = $state<TranscriptEntry[]>([]);
let liveStatus = $state<SessionStatus | null>(null);

// Seed from initial query data
$effect(() => {
  const data = detail?.messages;
  if (data && messages.length === 0) {
    messages = [...data];
  }
});

const isStreaming = $derived(liveStatus === 'running');

// Subscribe to SSE if last session is running
onMount(() => {
  let unsub: (() => void) | null = null;

  const checkAndSubscribe = () => {
    const t = thread;
    if (!t?.lastSessionId) return;
    // Only subscribe if we detect a running session
    // (status is unknown until we see SSE events; subscribe conservatively)
    unsub = subscribeToSession(
      t.lastSessionId,
      (entry: TranscriptEntry) => {
        messages = [...messages, entry];
      },
      (status: SessionStatus) => {
        liveStatus = status;
      },
      () => {
        liveStatus = 'done' as SessionStatus;
      }
    );
  };

  // Subscribe when thread data arrives
  const unsubEffect = $effect.root(() => {
    $effect(() => {
      if (thread?.lastSessionId && !unsub) {
        checkAndSubscribe();
      }
    });
  });

  return () => {
    unsub?.();
    unsubEffect();
  };
});

// ── Mutations ─────────────────────────────────────────────────────────────────

const continueMutOptsStore = writable(
  untrack(
    () =>
      continueThreadMutation(threadId) as CreateMutationOptions<
        ContinueThreadResponse,
        Error,
        ContinueThreadBody
      >
  )
);
$effect(() => {
  continueMutOptsStore.set(
    continueThreadMutation(threadId) as CreateMutationOptions<
      ContinueThreadResponse,
      Error,
      ContinueThreadBody
    >
  );
});
const continueMut = createMutation<ContinueThreadResponse, Error, ContinueThreadBody>(
  continueMutOptsStore
);

const updateMut = createMutation<Thread, Error, { id: string; body: UpdateThreadBody }>(
  updateThreadMutation() as CreateMutationOptions<
    Thread,
    Error,
    { id: string; body: UpdateThreadBody }
  >
);

const deleteMut = createMutation<void, Error, string>(
  deleteThreadMutation() as CreateMutationOptions<void, Error, string>
);

function invalidate(): void {
  queryClient.invalidateQueries({ queryKey: ['chat', 'threads', threadId] });
  queryClient.invalidateQueries({ queryKey: ['chat', 'threads'] });
}

function handleSend(prompt: string): void {
  if (!prompt.trim()) return;
  $continueMut.mutate(
    { prompt },
    {
      onSuccess: () => {
        invalidate();
      },
      onError: (err: Error) => {
        toasts.error(`Send failed: ${err.message}`);
      },
    }
  );
}

// ── Title edit ────────────────────────────────────────────────────────────────

let localTitle = $state('');
let titleDirty = $state(false);

$effect(() => {
  if (thread && !titleDirty) {
    localTitle = thread.title ?? '';
  }
});

function saveTitle(): void {
  if (!titleDirty || !localTitle.trim()) return;
  $updateMut.mutate(
    { id: threadId, body: { title: localTitle.trim() } },
    {
      onSuccess: () => {
        titleDirty = false;
        invalidate();
        toasts.success('Title updated');
      },
      onError: (err: Error) => {
        toasts.error(`Update failed: ${err.message}`);
      },
    }
  );
}

// ── Pin / archive ─────────────────────────────────────────────────────────────

function handlePin(): void {
  if (!thread) return;
  $updateMut.mutate(
    { id: threadId, body: { pinned: !thread.pinned } },
    {
      onSuccess: () => {
        invalidate();
        toasts.success(thread!.pinned ? 'Unpinned' : 'Pinned');
      },
    }
  );
}

function handleArchive(): void {
  $updateMut.mutate(
    { id: threadId, body: { archived: true } },
    {
      onSuccess: () => {
        invalidate();
        toasts.success('Thread archived');
      },
    }
  );
}

// ── Delete ────────────────────────────────────────────────────────────────────

let deleteConfirm = $state(false);

function handleDelete(): void {
  $deleteMut.mutate(threadId, {
    onSuccess: () => {
      toasts.success('Thread deleted');
      goto('/chat');
    },
    onError: (err: Error) => {
      toasts.error(`Delete failed: ${err.message}`);
      deleteConfirm = false;
    },
  });
}

// ── Export ────────────────────────────────────────────────────────────────────

let exporting = $state(false);

async function handleExport(): Promise<void> {
  exporting = true;
  try {
    const md = await exportThreadMarkdown(threadId);
    const blob = new Blob([md], { type: 'text/markdown' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `thread-${threadId}.md`;
    a.click();
    URL.revokeObjectURL(url);
    toasts.success('Exported');
  } catch (err) {
    toasts.error(`Export failed: ${(err as Error).message}`);
  } finally {
    exporting = false;
  }
}

// ── Panel ─────────────────────────────────────────────────────────────────────

let panelOpen = $state(false);

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}
</script>

<div class="ct-shell">
  <!-- Header -->
  <header class="ct-header">
    <nav class="ct-breadcrumb" aria-label="Breadcrumb">
      <a class="ct-breadcrumb-link" href="/chat">Chat</a>
      <span class="ct-breadcrumb-sep" aria-hidden="true">/</span>
      <span class="ct-breadcrumb-current" aria-current="page">{thread?.title ?? 'Untitled'}</span>
    </nav>

    {#if thread}
      <div class="ct-actions">
        {#if titleDirty}
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={saveTitle}
            disabled={$updateMut.isPending}
            aria-label="Save title"
          >
            Save
          </button>
        {/if}

        <button
          class="btn-compact btn-compact-ghost"
          onclick={handlePin}
          disabled={$updateMut.isPending}
          aria-label={thread.pinned ? 'Unpin thread' : 'Pin thread'}
          aria-pressed={thread.pinned}
        >
          <Pin size={13} aria-hidden="true" class={thread.pinned ? 'ct-pinned-icon' : ''} />
        </button>

        <button
          class="btn-compact btn-compact-ghost"
          onclick={handleExport}
          disabled={exporting}
          aria-label="Export thread as markdown"
        >
          <Download size={13} aria-hidden="true" />
          {exporting ? 'Exporting…' : 'Export'}
        </button>

        <button
          class="btn-compact btn-compact-ghost"
          onclick={handleArchive}
          disabled={$updateMut.isPending || Boolean(thread.archivedAt)}
          aria-label="Archive thread"
        >
          Archive
        </button>

        {#if !deleteConfirm}
          <button
            class="btn-compact btn-compact-ghost ct-delete-btn"
            onclick={() => { deleteConfirm = true; }}
            aria-label="Delete thread"
          >
            <Trash2 size={13} aria-hidden="true" />
          </button>
        {:else}
          <button
            class="btn-compact btn-compact-ghost ct-confirm-btn"
            onclick={handleDelete}
            disabled={$deleteMut.isPending}
            aria-label="Confirm delete"
          >
            {$deleteMut.isPending ? 'Deleting…' : 'Confirm delete'}
          </button>
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { deleteConfirm = false; }}
            aria-label="Cancel delete"
          >
            Cancel
          </button>
        {/if}

        <button
          class="btn-compact btn-compact-secondary"
          onclick={() => { panelOpen = !panelOpen; }}
          aria-label="Toggle metadata panel"
          aria-expanded={panelOpen}
        >
          Details
        </button>
      </div>
    {/if}
  </header>

  <!-- Title edit -->
  {#if thread !== undefined}
    <div class="ct-title-row">
      <input
        class="ct-title-input"
        type="text"
        bind:value={localTitle}
        oninput={() => { titleDirty = true; }}
        onblur={saveTitle}
        onkeydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); saveTitle(); } }}
        aria-label="Thread title"
        placeholder="Untitled"
        autocomplete="off"
      />
    </div>
  {/if}

  <!-- Body -->
  <div class="ct-body">
    <div class="ct-transcript-col">
      {#if $query.isLoading}
        <div class="ct-skeleton">
          <SkeletonList count={5} height="2.5rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="ct-error" role="alert">
          {($query.error as Error).message ?? 'Failed to load thread.'}
        </p>
      {:else}
        <TranscriptView {messages} {isStreaming} />
      {/if}

      <!-- Composer at bottom -->
      <div class="ct-composer-wrap">
        <Composer
          placeholder="Continue this thread…"
          onSubmit={handleSend}
        />
      </div>
    </div>

    <!-- Metadata panel -->
    <PushPanel open={panelOpen} title="Thread info" onClose={() => { panelOpen = false; }}>
      {#if thread}
        <dl class="ct-meta-list">
          <dt class="ct-meta-key">Agent</dt>
          <dd class="ct-meta-val ct-mono">{thread.agentSlug ?? '—'}</dd>

          <dt class="ct-meta-key">Runtime</dt>
          <dd class="ct-meta-val ct-mono">{thread.runtimeType}</dd>

          <dt class="ct-meta-key">Model</dt>
          <dd class="ct-meta-val ct-mono">{thread.modelId ?? '—'}</dd>

          <dt class="ct-meta-key">Workspace</dt>
          <dd class="ct-meta-val ct-mono">{thread.workspaceSlug ?? '—'}</dd>

          <dt class="ct-meta-key">Pinned</dt>
          <dd class="ct-meta-val">{thread.pinned ? 'Yes' : 'No'}</dd>

          <dt class="ct-meta-key">Archived</dt>
          <dd class="ct-meta-val">{thread.archivedAt ? formatDate(thread.archivedAt) : 'No'}</dd>

          <dt class="ct-meta-key">Last message</dt>
          <dd class="ct-meta-val ct-mono">{formatDate(thread.lastMessageAt)}</dd>

          <dt class="ct-meta-key">Created</dt>
          <dd class="ct-meta-val ct-mono">{formatDate(thread.insertedAt)}</dd>

          <dt class="ct-meta-key">Updated</dt>
          <dd class="ct-meta-val ct-mono">{formatDate(thread.updatedAt)}</dd>

          {#if isStreaming}
            <dt class="ct-meta-key">Status</dt>
            <dd class="ct-meta-val ct-streaming">Running…</dd>
          {/if}
        </dl>
      {/if}
    </PushPanel>
  </div>
</div>

<style>
  .ct-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .ct-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .ct-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    min-width: 0;
  }

  .ct-breadcrumb-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-decoration: none;
    flex-shrink: 0;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .ct-breadcrumb-link:hover {
    color: var(--fg);
  }

  .ct-breadcrumb-sep {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .ct-breadcrumb-current {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .ct-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .ct-delete-btn {
    color: var(--signal-error, red);
  }

  .ct-confirm-btn {
    color: var(--signal-error, red);
  }

  :global(.ct-pinned-icon) {
    color: var(--signal-thinking) !important;
  }

  /* Title row */
  .ct-title-row {
    padding: var(--space-3) var(--space-5) 0;
    flex-shrink: 0;
  }

  .ct-title-input {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    border-bottom: 2px solid transparent;
    padding: var(--space-1) 0;
    width: 100%;
    letter-spacing: -0.015em;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .ct-title-input:focus {
    border-bottom-color: color-mix(in oklch, var(--fg) 25%, transparent);
  }

  /* Body */
  .ct-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    gap: var(--space-2);
    padding: 0 var(--space-2) var(--space-2);
  }

  .ct-transcript-col {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  .ct-skeleton {
    padding: var(--space-5);
  }

  .ct-error {
    margin: var(--space-5);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  /* Composer */
  .ct-composer-wrap {
    padding: var(--space-3) var(--space-2) var(--space-2);
    flex-shrink: 0;
  }

  /* Metadata panel */
  .ct-meta-list {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--space-2) var(--space-3);
    margin: 0;
  }

  .ct-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    align-self: start;
    padding-top: 2px;
  }

  .ct-meta-val {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    word-break: break-word;
  }

  .ct-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .ct-streaming {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-running, green);
    animation: ct-pulse 1.4s ease-in-out infinite;
  }

  @keyframes ct-pulse {
    0%, 100% { opacity: 0.5; }
    50% { opacity: 1; }
  }
</style>
