<script lang="ts">
  /**
   * /docs/[id] — Document detail: textarea editor + markdown preview + metadata panel.
   * CSS prefix: dd- (DocDetail)
   */
  import {
    type CreateMutationOptions,
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from '@tanstack/svelte-query';
  import { page } from '$app/state';
  import { Eye, Pencil } from 'lucide-svelte';
  import { untrack } from 'svelte';
  import { writable } from 'svelte/store';
  import { beforeNavigate, goto } from '$app/navigation';
  import {
    archiveDocumentMutation,
    bodyJsonFromText,
    bodyTextFromJson,
    deleteDocumentMutation,
    documentQuery,
    publishDocumentMutation,
    unpublishDocumentMutation,
    updateDocumentMutation,
  } from '$lib/api/queries/docs.js';
  import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
  import PushPanel from '$lib/design/patterns/PushPanel.svelte';
  import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
  import type { Document, UpdateDocumentBody } from '$lib/domain/docs/types.js';
  import { toasts } from '$lib/stores/toasts.svelte.js';
  import { renderMarkdown } from '$lib/utils/markdown.js';

  const docId = $derived(page.params.id ?? '');
  const queryClient = useQueryClient();

  // ── Query ────────────────────────────────────────────────────────────────────

  const queryOptsStore = writable(
    untrack(() => documentQuery(docId) as CreateQueryOptions<Document>),
  );
  $effect(() => {
    queryOptsStore.set(documentQuery(docId) as CreateQueryOptions<Document>);
  });
  const query = createQuery<Document>(queryOptsStore);
  const doc = $derived($query.data as Document | undefined);

  // ── Local state ───────────────────────────────────────────────────────────────

  let localTitle = $state('');
  let localBody = $state('');
  let titleDirty = $state(false);
  let bodyDirty = $state(false);
  let preview = $state(false);
  let panelOpen = $state(true);

  $effect(() => {
    if (doc && !titleDirty && !bodyDirty) {
      localTitle = doc.title ?? '';
      localBody = bodyTextFromJson(doc.bodyJson ?? null);
    }
  });

  const isDirty = $derived(titleDirty || bodyDirty);

  // ── Dirty guard ───────────────────────────────────────────────────────────────

  let guardOpen = $state(false);
  let pendingUrl = $state('');
  let allowNavigation = $state(false);

  beforeNavigate(({ to, cancel }) => {
    if (isDirty && !allowNavigation) {
      cancel();
      pendingUrl = to?.url.pathname ?? '/docs';
      guardOpen = true;
    }
  });

  function handleGuardCancel(): void {
    guardOpen = false;
    pendingUrl = '';
  }

  function handleGuardDiscard(): void {
    allowNavigation = true;
    guardOpen = false;
    goto(pendingUrl || '/docs');
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  const updateMut = createMutation<Document, Error, { id: string; body: UpdateDocumentBody }>(
    updateDocumentMutation() as CreateMutationOptions<Document, Error, { id: string; body: UpdateDocumentBody }>,
  );

  const publishMut = createMutation<Document, Error, string>(
    publishDocumentMutation() as CreateMutationOptions<Document, Error, string>,
  );

  const unpublishMut = createMutation<Document, Error, string>(
    unpublishDocumentMutation() as CreateMutationOptions<Document, Error, string>,
  );

  const archiveMut = createMutation<Document, Error, string>(
    archiveDocumentMutation() as CreateMutationOptions<Document, Error, string>,
  );

  const deleteMut = createMutation<void, Error, string>(
    deleteDocumentMutation() as CreateMutationOptions<void, Error, string>,
  );

  function invalidate(): void {
    queryClient.invalidateQueries({ queryKey: ['docs', docId] });
    queryClient.invalidateQueries({ queryKey: ['docs'] });
  }

  function save(): void {
    if (!doc || (!titleDirty && !bodyDirty)) return;
    const body: UpdateDocumentBody = {};
    if (titleDirty) body.title = localTitle.trim();
    if (bodyDirty) {
      body.bodyJson = bodyJsonFromText(localBody);
      body.bodyText = localBody;
    }
    $updateMut.mutate(
      { id: docId, body },
      {
        onSuccess: () => {
          titleDirty = false;
          bodyDirty = false;
          invalidate();
          toasts.success('Document saved');
        },
        onError: (err: Error) => {
          toasts.error(`Save failed: ${err.message}`);
        },
      },
    );
  }

  function handleKeydown(e: KeyboardEvent): void {
    if ((e.metaKey || e.ctrlKey) && e.key === 's') {
      e.preventDefault();
      save();
    }
  }

  function handlePublishToggle(): void {
    if (!doc) return;
    if (doc.published) {
      $unpublishMut.mutate(docId, { onSuccess: () => { invalidate(); toasts.success('Unpublished'); } });
    } else {
      $publishMut.mutate(docId, { onSuccess: () => { invalidate(); toasts.success('Published'); } });
    }
  }

  let archiveConfirm = $state(false);
  let deleteConfirm = $state(false);

  function handleArchive(): void {
    $archiveMut.mutate(docId, {
      onSuccess: () => {
        invalidate();
        toasts.success('Archived');
        archiveConfirm = false;
      },
      onError: (err: Error) => {
        toasts.error(`Archive failed: ${err.message}`);
        archiveConfirm = false;
      },
    });
  }

  function handleDelete(): void {
    $deleteMut.mutate(docId, {
      onSuccess: () => {
        allowNavigation = true;
        toasts.success('Document deleted');
        goto('/docs');
      },
      onError: (err: Error) => {
        toasts.error(`Delete failed: ${err.message}`);
        deleteConfirm = false;
      },
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  function formatDate(iso: string | null | undefined): string {
    if (!iso) return '—';
    return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
  }

  const renderedMarkdown = $derived(preview ? renderMarkdown(localBody) : '');
</script>

<svelte:window onkeydown={handleKeydown} />

<DirtyGuardModal open={guardOpen} onCancel={handleGuardCancel} onDiscard={handleGuardDiscard} />

<div class="dd-shell">
  <!-- Header -->
  <header class="dd-header">
    <nav class="dd-breadcrumb" aria-label="Breadcrumb">
      <a class="dd-breadcrumb-link" href="/docs">Docs</a>
      <span class="dd-breadcrumb-sep" aria-hidden="true">/</span>
      <span class="dd-breadcrumb-current" aria-current="page">{doc?.title ?? '…'}</span>
    </nav>

    {#if doc}
      <div class="dd-actions">
        <button
          class="btn-compact btn-compact-secondary dd-preview-btn"
          onclick={() => { preview = !preview; }}
          aria-label={preview ? 'Switch to edit mode' : 'Switch to preview mode'}
          aria-pressed={preview}
        >
          {#if preview}
            <Pencil size={12} aria-hidden="true" />
            Edit
          {:else}
            <Eye size={12} aria-hidden="true" />
            Preview
          {/if}
        </button>

        <button
          class="btn-pill btn-pill-secondary btn-pill-sm"
          onclick={handlePublishToggle}
          disabled={$publishMut.isPending || $unpublishMut.isPending}
          aria-label={doc.published ? 'Unpublish document' : 'Publish document'}
        >
          {doc.published ? 'Unpublish' : 'Publish'}
        </button>

        {#if isDirty}
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={save}
            disabled={$updateMut.isPending}
            aria-label="Save document"
          >
            {$updateMut.isPending ? 'Saving…' : 'Save'}
          </button>
        {/if}

        {#if !archiveConfirm}
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { archiveConfirm = true; }}
            aria-label="Archive document"
          >
            Archive
          </button>
        {:else}
          <button
            class="btn-compact btn-compact-ghost dd-confirm-btn"
            onclick={handleArchive}
            disabled={$archiveMut.isPending}
            aria-label="Confirm archive"
          >
            Confirm archive
          </button>
          <button
            class="btn-compact btn-compact-ghost"
            onclick={() => { archiveConfirm = false; }}
            aria-label="Cancel archive"
          >
            Cancel
          </button>
        {/if}

        {#if !deleteConfirm}
          <button
            class="btn-compact btn-compact-ghost dd-delete-btn"
            onclick={() => { deleteConfirm = true; }}
            aria-label="Delete document"
          >
            Delete
          </button>
        {:else}
          <button
            class="btn-compact btn-compact-ghost dd-confirm-btn dd-confirm-btn--danger"
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

  <!-- Body -->
  <div class="dd-body">
    <main class="dd-main">
      {#if $query.isLoading}
        <div class="dd-skeleton">
          <SkeletonList count={6} height="1.25rem" gap="0.5rem" />
        </div>
      {:else if $query.isError}
        <p class="dd-error" role="alert">
          {($query.error as Error).message ?? 'Failed to load document.'}
        </p>
      {:else if doc}
        <!-- Editable title -->
        <input
          class="dd-title-input"
          type="text"
          bind:value={localTitle}
          oninput={() => { titleDirty = true; }}
          aria-label="Document title"
          placeholder="Untitled"
          autocomplete="off"
        />

        {#if !preview}
          <textarea
            class="dd-editor"
            bind:value={localBody}
            oninput={() => { bodyDirty = true; }}
            placeholder="Start writing…"
            aria-label="Document body"
            spellcheck="true"
          ></textarea>
          {#if isDirty}
            <p class="dd-hint">⌘S to save</p>
          {/if}
        {:else}
          <!-- svelte-ignore -->
          <div class="dd-preview" role="article" aria-label="Document preview">
            {@html renderedMarkdown || '<p class="dd-preview-empty">Nothing to preview.</p>'}
          </div>
        {/if}
      {/if}
    </main>

    <!-- Metadata panel -->
    <PushPanel open={panelOpen} title="Metadata" onClose={() => { panelOpen = false; }}>
      {#if doc}
        <dl class="dd-meta-list">
          <dt class="dd-meta-key">Status</dt>
          <dd class="dd-meta-val">
            {#if doc.archivedAt}
              <span class="dd-badge dd-badge--archived">Archived</span>
            {:else if doc.published}
              <span class="dd-badge dd-badge--pub">Published</span>
            {:else}
              <span class="dd-badge dd-badge--draft">Draft</span>
            {/if}
          </dd>

          <dt class="dd-meta-key">Author</dt>
          <dd class="dd-meta-val dd-mono">{doc.authorId}</dd>

          <dt class="dd-meta-key">Last editor</dt>
          <dd class="dd-meta-val dd-mono">{doc.lastEditorId ?? '—'}</dd>

          <dt class="dd-meta-key">Tags</dt>
          <dd class="dd-meta-val">
            {#if doc.tags.length > 0}
              <div class="dd-tags">
                {#each doc.tags as tag (tag)}
                  <span class="dd-tag">{tag}</span>
                {/each}
              </div>
            {:else}
              —
            {/if}
          </dd>

          <dt class="dd-meta-key">Created</dt>
          <dd class="dd-meta-val dd-mono">{formatDate(doc.insertedAt)}</dd>

          <dt class="dd-meta-key">Updated</dt>
          <dd class="dd-meta-val dd-mono">{formatDate(doc.updatedAt)}</dd>
        </dl>
      {/if}
    </PushPanel>
  </div>
</div>

<style>
  .dd-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .dd-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    flex-wrap: wrap;
  }

  .dd-breadcrumb {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .dd-breadcrumb-link {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    text-decoration: none;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .dd-breadcrumb-link:hover {
    color: var(--fg);
  }

  .dd-breadcrumb-sep {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .dd-breadcrumb-current {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    max-width: 240px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .dd-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-wrap: wrap;
  }

  .dd-preview-btn {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .dd-delete-btn {
    color: var(--signal-error, red);
  }

  .dd-confirm-btn {
    color: var(--fg-muted);
  }

  .dd-confirm-btn--danger {
    color: var(--signal-error, red);
  }

  /* Body */
  .dd-body {
    flex: 1;
    display: flex;
    overflow: hidden;
    gap: var(--space-2);
    padding: 0 var(--space-2) var(--space-2);
  }

  .dd-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    overflow-y: auto;
    padding: var(--space-5);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .dd-skeleton,
  .dd-error {
    padding: var(--space-4);
  }

  .dd-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
    margin: 0;
  }

  /* Title */
  .dd-title-input {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    border-bottom: 2px solid transparent;
    padding: var(--space-1) 0;
    width: 100%;
    letter-spacing: var(--tracking-2xl);
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .dd-title-input:focus {
    border-bottom-color: color-mix(in oklch, var(--fg) 25%, transparent);
  }

  /* Editor */
  .dd-editor {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: 1.75;
    color: var(--fg);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-4);
    resize: none;
    outline: none;
    min-height: 400px;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .dd-editor:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .dd-hint {
    margin: 0;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* Preview */
  .dd-preview {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    line-height: 1.75;
    color: var(--fg);
    padding: var(--space-2) 0;
  }

  :global(.dd-preview .fv-p) {
    margin: 0 0 var(--space-3);
  }

  :global(.dd-preview .fv-h1, .dd-preview .fv-h2, .dd-preview .fv-h3) {
    font-weight: 600;
    margin: var(--space-4) 0 var(--space-2);
    color: var(--fg);
  }

  :global(.dd-preview .fv-code-block) {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    overflow-x: auto;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  :global(.dd-preview-empty) {
    font-style: italic;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }

  /* Panel metadata */
  .dd-meta-list {
    display: grid;
    grid-template-columns: auto 1fr;
    gap: var(--space-2) var(--space-3);
    margin: 0;
  }

  .dd-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    align-self: start;
    padding-top: 2px;
  }

  .dd-meta-val {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    word-break: break-word;
  }

  .dd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  .dd-badge {
    display: inline-block;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: var(--radius-sm);
  }

  .dd-badge--pub {
    background: color-mix(in oklch, green 20%, transparent 80%);
    color: color-mix(in oklch, green 80%, var(--fg) 20%);
    border: 1px solid color-mix(in oklch, green 30%, transparent 70%);
  }

  .dd-badge--draft {
    background: var(--bg-inset);
    color: var(--fg-subtle);
    border: 1px solid var(--border);
  }

  .dd-badge--archived {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg-muted);
    border: 1px solid var(--border);
  }

  .dd-tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .dd-tag {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 5px;
  }
</style>
