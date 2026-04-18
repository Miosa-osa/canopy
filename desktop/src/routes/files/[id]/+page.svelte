<script lang="ts">
  /**
   * /files/[id] — File detail: metadata + tag editor + activity feed.
   * CSS prefix: fd- (FileDetail)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { page } from '$app/state';
  import { Archive, Download } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { goto } from '$app/navigation';
  import { API_BASE } from '$lib/api/client.js';
  import {
    archiveFileMutation,
    fileActivityQuery,
    fileQuery,
    formatBytes,
    updateTagsMutation,
  } from '$lib/api/queries/files.js';
  import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
  import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
  import type { FileActivity, FileRecord, UpdateTagsBody } from '$lib/domain/files/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';

  const fileId = $derived(page.params.id ?? '');
  const queryClient = useQueryClient();

  // ── Queries ──────────────────────────────────────────────────────────────────

  const fileOptsStore = writable(
    untrack(() => fileQuery(fileId) as CreateQueryOptions<FileRecord>),
  );
  $effect(() => {
    fileOptsStore.set(fileQuery(fileId) as CreateQueryOptions<FileRecord>);
  });
  const fileQ = createQuery<FileRecord>(fileOptsStore);
  const file = $derived($fileQ.data as FileRecord | undefined);

  const activityOptsStore = writable(
    untrack(() => fileActivityQuery(fileId) as CreateQueryOptions<FileActivity[]>),
  );
  $effect(() => {
    activityOptsStore.set(fileActivityQuery(fileId) as CreateQueryOptions<FileActivity[]>);
  });
  const activityQ = createQuery<FileActivity[]>(activityOptsStore);
  const activities = $derived(($activityQ.data ?? []) as FileActivity[]);

  // ── Tag editor ────────────────────────────────────────────────────────────────

  let tagInput = $state('');

  $effect(() => {
    if (file && !tagInput) {
      tagInput = file.tags.join(', ');
    }
  });

  const tagsMut = createMutation<FileRecord, Error, { id: string; body: UpdateTagsBody }>(
    updateTagsMutation() as CreateMutationOptions<FileRecord, Error, { id: string; body: UpdateTagsBody }>,
  );

  function saveTags(): void {
    const tags = tagInput
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);
    $tagsMut.mutate(
      { id: fileId, body: { tags } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: ['files', fileId] });
          toasts.success('Tags updated');
        },
        onError: (err: Error) => {
          toasts.error(`Tags update failed: ${err.message}`);
        },
      },
    );
  }

  function handleTagKeydown(e: KeyboardEvent): void {
    if (e.key === 'Enter') {
      e.preventDefault();
      saveTags();
    }
  }

  // ── Archive ───────────────────────────────────────────────────────────────────

  const archiveMut = createMutation<FileRecord, Error, string>(
    archiveFileMutation() as CreateMutationOptions<FileRecord, Error, string>,
  );

  let archiveConfirm = $state(false);

  function handleArchive(): void {
    $archiveMut.mutate(fileId, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['files'] });
        toasts.success('File archived');
        goto('/files');
      },
      onError: (err: Error) => {
        toasts.error(`Archive failed: ${err.message}`);
        archiveConfirm = false;
      },
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  function formatDate(iso: string | null | undefined): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }

  function relativeTime(iso: string): string {
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff / 60_000);
    if (mins < 1) return 'just now';
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }

  function actionLabel(action: string): string {
    const map: Record<string, string> = {
      created: 'Created',
      updated: 'Updated',
      read: 'Read',
      deleted: 'Deleted',
      renamed: 'Renamed',
      tagged: 'Tagged',
    };
    return map[action] ?? action;
  }

  const downloadUrl = $derived(`${API_BASE}/files/${fileId}/content`);
</script>

<div class="fd-shell">
  <!-- Header -->
  <header class="fd-header">
    <nav class="fd-breadcrumb" aria-label="Breadcrumb">
      <a class="fd-breadcrumb-link" href="/files">Files</a>
      <span class="fd-breadcrumb-sep" aria-hidden="true">/</span>
      <span class="fd-breadcrumb-current" aria-current="page">{file?.path ?? '…'}</span>
    </nav>

    {#if file}
      <div class="fd-actions">
        <a
          class="btn-pill btn-pill-secondary btn-pill-sm fd-download"
          href={downloadUrl}
          download={file.name}
          aria-label="Download file"
        >
          <Download size={12} aria-hidden="true" />
          Download
        </a>

        {#if !archiveConfirm}
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { archiveConfirm = true; }}
            aria-label="Archive file"
            disabled={Boolean(file.archivedAt)}
          >
            <Archive size={12} aria-hidden="true" />
            {file.archivedAt ? 'Archived' : 'Archive'}
          </button>
        {:else}
          <button
            class="btn-compact btn-compact-ghost fd-confirm-btn"
            onclick={handleArchive}
            disabled={$archiveMut.isPending}
            aria-label="Confirm archive"
          >
            {$archiveMut.isPending ? 'Archiving…' : 'Confirm archive'}
          </button>
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { archiveConfirm = false; }}
            aria-label="Cancel archive"
          >
            Cancel
          </button>
        {/if}
      </div>
    {/if}
  </header>

  <!-- Body -->
  {#if $fileQ.isLoading}
    <div class="fd-skeleton">
      <SkeletonList count={6} height="1.25rem" gap="0.5rem" />
    </div>
  {:else if $fileQ.isError}
    <p class="fd-error" role="alert">
      {($fileQ.error as Error).message ?? 'Failed to load file.'}
    </p>
  {:else if file}
    <div class="fd-body">
      <!-- Left: metadata + tags -->
      <main class="fd-main">
        <!-- Filename + tags edit -->
        <div class="fd-filename-wrap">
          <h1 class="fd-filename">{file.name}</h1>
        </div>

        <div class="fd-tag-row">
          <label class="fd-label" for="fd-tags">Tags</label>
          <input
            id="fd-tags"
            class="fd-tag-input"
            type="text"
            bind:value={tagInput}
            onblur={saveTags}
            onkeydown={handleTagKeydown}
            placeholder="tag1, tag2, …"
            aria-label="File tags, comma separated"
            autocomplete="off"
          />
          {#if $tagsMut.isPending}
            <span class="fd-saving">Saving…</span>
          {/if}
        </div>

        <!-- Metadata grid -->
        <dl class="fd-meta-list">
          <dt class="fd-meta-key">Path</dt>
          <dd class="fd-meta-val fd-mono">{file.path}</dd>

          <dt class="fd-meta-key">Size</dt>
          <dd class="fd-meta-val fd-mono">{formatBytes(file.sizeBytes)}</dd>

          <dt class="fd-meta-key">MIME type</dt>
          <dd class="fd-meta-val fd-mono">{file.mimeType ?? '—'}</dd>

          <dt class="fd-meta-key">Extension</dt>
          <dd class="fd-meta-val fd-mono">{file.extension ?? '—'}</dd>

          <dt class="fd-meta-key">SHA-256</dt>
          <dd class="fd-meta-val fd-mono fd-sha">{file.sha256 ?? '—'}</dd>

          <dt class="fd-meta-key">Owner</dt>
          <dd class="fd-meta-val">
            <div class="fd-owner-row">
              <ActorAvatar
                actor={{
                  type: file.ownerType === 'user' ? 'human' : 'agent',
                  id: file.ownerId ?? file.ownerType,
                  name: file.ownerId ?? file.ownerType,
                }}
                size="sm"
              />
              <span class="fd-mono">{file.ownerId ?? file.ownerType}</span>
            </div>
          </dd>

          <dt class="fd-meta-key">Last indexed</dt>
          <dd class="fd-meta-val fd-mono">{formatDate(file.lastIndexedAt)}</dd>

          <dt class="fd-meta-key">Created</dt>
          <dd class="fd-meta-val fd-mono">{formatDate(file.insertedAt)}</dd>

          <dt class="fd-meta-key">Updated</dt>
          <dd class="fd-meta-val fd-mono">{formatDate(file.updatedAt)}</dd>

          {#if file.archivedAt}
            <dt class="fd-meta-key">Archived</dt>
            <dd class="fd-meta-val fd-mono">{formatDate(file.archivedAt)}</dd>
          {/if}
        </dl>
      </main>

      <!-- Right: activity feed -->
      <aside class="fd-activity" aria-label="File activity">
        <h2 class="fd-activity-title">Activity</h2>

        {#if $activityQ.isLoading}
          <SkeletonList count={4} height="2.5rem" gap="0.375rem" />
        {:else if activities.length === 0}
          <p class="fd-activity-empty">No activity recorded.</p>
        {:else}
          <ul class="fd-activity-list" role="list">
            {#each activities as act (act.id)}
              <li class="fd-activity-row" role="listitem">
                <ActorAvatar
                  actor={{
                    type: act.actorType === 'user' ? 'human' : 'agent',
                    id: act.actorId ?? act.actorType,
                    name: act.actorId ?? act.actorType,
                  }}
                  size="sm"
                />
                <div class="fd-activity-content">
                  <span class="fd-activity-action">{actionLabel(act.action)}</span>
                  <time class="fd-activity-time" datetime={act.occurredAt}>
                    {relativeTime(act.occurredAt)}
                  </time>
                  {#if act.metadata && Object.keys(act.metadata).length > 0}
                    <span class="fd-activity-meta">
                      {JSON.stringify(act.metadata).slice(0, 60)}
                    </span>
                  {/if}
                </div>
              </li>
            {/each}
          </ul>
        {/if}
      </aside>
    </div>
  {/if}
</div>

<style>
  .fd-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .fd-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .fd-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    min-width: 0;
  }

  .fd-breadcrumb-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-decoration: none;
    flex-shrink: 0;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .fd-breadcrumb-link:hover {
    color: var(--fg);
  }

  .fd-breadcrumb-sep {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .fd-breadcrumb-current {
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .fd-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .fd-download {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    text-decoration: none;
  }

  .fd-confirm-btn {
    color: var(--signal-error, red);
  }

  /* Loading / error */
  .fd-skeleton {
    padding: var(--space-5);
  }

  .fd-error {
    margin: var(--space-5);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  /* Body: two columns */
  .fd-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    gap: 0;
  }

  .fd-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    overflow-y: auto;
    padding: var(--space-5);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  /* Filename */
  .fd-filename-wrap {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .fd-filename {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    letter-spacing: var(--tracking-2xl);
    word-break: break-all;
  }

  /* Tags */
  .fd-tag-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .fd-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex-shrink: 0;
  }

  .fd-tag-input {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .fd-tag-input:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .fd-saving {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  /* Metadata */
  .fd-meta-list {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--space-2) var(--space-3);
    margin: 0;
  }

  .fd-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    align-self: start;
    padding-top: 2px;
  }

  .fd-meta-val {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    word-break: break-word;
  }

  .fd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .fd-sha {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 200px;
    display: block;
  }

  .fd-owner-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* Activity feed */
  .fd-activity {
    width: 300px;
    flex-shrink: 0;
    border-left: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }

  .fd-activity-title {
    margin: 0;
    padding: var(--space-4) var(--space-4) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .fd-activity-empty {
    margin: var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .fd-activity-list {
    flex: 1;
    overflow-y: auto;
    list-style: none;
    margin: 0;
    padding: var(--space-2);
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .fd-activity-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-2);
    border-radius: var(--radius-md);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .fd-activity-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent 96%);
  }

  .fd-activity-content {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .fd-activity-action {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg);
  }

  .fd-activity-time {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .fd-activity-meta {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
</style>
