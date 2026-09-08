<script lang="ts">
/**
 * Skill detail — /skills/:slug (Wave A #111 completion).
 * Left: content markdown (read mode) or textarea (edit mode, ⌘S save).
 * Right: PushPanel with metadata.
 * CSS prefix: skd- (SkillDetail)
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { AlertCircle } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { beforeNavigate, goto } from '$app/navigation';
import { page } from '$app/state';
import { skillQuery, updateSkillMutation } from '$lib/api/queries/skills.js';
import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb';
import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import PushPanel from '$lib/design/patterns/PushPanel.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { CreateSkillBody, Skill } from '$lib/domain/skills/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { renderMarkdown } from '$lib/utils/markdown.js';

const queryClient = useQueryClient();

const slug = $derived(page.params.slug ?? '');

const skillOptsStore = writable(untrack(() => skillQuery(slug) as CreateQueryOptions<Skill>));

$effect(() => {
  skillOptsStore.set(skillQuery(slug) as CreateQueryOptions<Skill>);
});

const skillQ = createQuery<Skill>(skillOptsStore);

const skill = $derived(($skillQ.data ?? null) as Skill | null);

// ── Meta panel ───────────────────────────────────────────────────────────────

let metaPanelOpen = $state(true);

// ── Edit mode ────────────────────────────────────────────────────────────────

let editMode = $state(false);
let editText = $state('');
const isDirty = $derived(editMode && editText !== (skill?.content ?? ''));

function enterEditMode() {
  editText = skill?.content ?? '';
  editMode = true;
}

function cancelEdit() {
  editMode = false;
  editText = '';
}

const updateMut = createMutation<Skill, Error, { slug: string; body: Partial<CreateSkillBody> }>(
  updateSkillMutation() as CreateMutationOptions<
    Skill,
    Error,
    { slug: string; body: Partial<CreateSkillBody> }
  >
);

function saveContent() {
  if (!isDirty || $updateMut.isPending) return;
  $updateMut.mutate(
    { slug, body: { content: editText } },
    {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['skills', slug] });
        toasts.success('Saved');
        editMode = false;
        editText = '';
      },
      onError: (err: Error) => {
        toasts.error(err.message ?? 'Save failed');
      },
    }
  );
}

function handleTextareaKeydown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key === 's') {
    e.preventDefault();
    saveContent();
  }
}

// Unsaved-changes guard
let guardOpen = $state(false);
let bypassGuard = $state(false);
let pendingNavigation: (() => void) | null = null;

beforeNavigate(({ cancel, to }) => {
  if (isDirty && !bypassGuard) {
    cancel();
    pendingNavigation = () => {
      bypassGuard = true;
      if (to?.url) window.location.assign(to.url.href);
    };
    guardOpen = true;
  }
});

// Rendered HTML (read mode only)
const renderedHtml = $derived(!editMode && skill?.content ? renderMarkdown(skill.content) : '');

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

function sourceLabel(source: string): string {
  switch (source) {
    case 'clawhub':
      return 'Clawhub';
    case 'skills_sh':
      return 'Skills.sh';
    case 'local':
      return 'Local';
    case 'user':
      return 'User';
    default:
      return source;
  }
}
</script>

<div class="skd-page">
  {#if $skillQ.isLoading}
    <div class="skd-loading" aria-label="Loading skill" aria-live="polite">
      <div class="sk sk--title"></div>
      <div class="sk sk--body"></div>
      <div class="sk sk--body sk--short"></div>
    </div>
  {:else if $skillQ.isError || !skill}
    <EmptyState
      icon={AlertCircle as never}
      title="Skill not found"
      body="This skill doesn't exist or couldn't be loaded."
      action="Back to skills"
      onAction={() => goto('/skills')}
    />
  {:else}
    <!-- Top bar -->
    <header class="skd-topbar">
      <Breadcrumb>
        <BreadcrumbItem href="/skills">Skills</BreadcrumbItem>
        <BreadcrumbItem>{skill.name}</BreadcrumbItem>
      </Breadcrumb>

      <div class="skd-topbar-actions">
        <span class="skd-source-badge">{sourceLabel(skill.source)}</span>
        <StatusDot
          color={skill.enabled ? 'green' : 'grey'}
          label={skill.enabled ? 'Enabled' : 'Disabled'}
        />

        {#if editMode}
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            onclick={cancelEdit}
            disabled={$updateMut.isPending}
            aria-label="Cancel edit"
          >
            Cancel
          </button>
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={saveContent}
            disabled={!isDirty || $updateMut.isPending}
            aria-label="Save skill content"
          >
            {$updateMut.isPending ? 'Saving…' : 'Save'}
          </button>
        {:else}
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            onclick={enterEditMode}
            aria-label="Edit skill content"
          >
            Edit
          </button>
          <button
            class="btn-compact btn-compact-ghost btn-compact-sm"
            onclick={() => { metaPanelOpen = !metaPanelOpen; }}
            aria-label={metaPanelOpen ? 'Hide info' : 'Show info'}
            aria-pressed={metaPanelOpen}
          >
            {metaPanelOpen ? '→' : '←'} Info
          </button>
        {/if}
      </div>
    </header>

    <!-- Body -->
    <div class="skd-body">
      <!-- Left: content -->
      <article class="skd-content">
        <div class="skd-content-header">
          <h1 class="skd-name">{skill.name}</h1>
          {#if skill.description}
            <p class="skd-desc">{skill.description}</p>
          {/if}
        </div>

        <div class="skd-markdown">
          {#if editMode}
            <textarea
              class="skd-editor"
              bind:value={editText}
              onkeydown={handleTextareaKeydown}
              aria-label="Skill content editor"
              spellcheck="false"
            ></textarea>
          {:else}
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            {@html renderedHtml}
          {/if}
        </div>
      </article>

      <!-- Right: metadata PushPanel -->
      <PushPanel open={metaPanelOpen} title="Skill info" onClose={() => { metaPanelOpen = false; }}>
        <dl class="skd-meta">
          <div class="skd-meta-row">
            <dt>Slug</dt>
            <dd class="skd-mono">{skill.slug}</dd>
          </div>
          <div class="skd-meta-row">
            <dt>Source</dt>
            <dd>{sourceLabel(skill.source)}</dd>
          </div>
          <div class="skd-meta-row">
            <dt>Format</dt>
            <dd>{skill.provider_format}</dd>
          </div>
          {#if skill.source_url}
            <div class="skd-meta-row skd-meta-row--stack">
              <dt>Source URL</dt>
              <dd class="skd-mono skd-url">{skill.source_url}</dd>
            </div>
          {/if}
          {#if skill.content_hash}
            <div class="skd-meta-row skd-meta-row--stack">
              <dt>Content hash</dt>
              <dd class="skd-mono">{skill.content_hash.slice(0, 16)}…</dd>
            </div>
          {/if}
          {#if skill.tags.length > 0}
            <div class="skd-meta-row skd-meta-row--stack">
              <dt>Tags</dt>
              <dd class="skd-chips">
                {#each skill.tags as tag (tag)}
                  <span class="skd-chip">{tag}</span>
                {/each}
              </dd>
            </div>
          {/if}
          {#if skill.imported_at}
            <div class="skd-meta-row">
              <dt>Imported</dt>
              <dd>{formatDate(skill.imported_at)}</dd>
            </div>
          {/if}
          <div class="skd-meta-row">
            <dt>Updated</dt>
            <dd>{formatDate(skill.updated_at)}</dd>
          </div>
          <div class="skd-meta-row">
            <dt>Created</dt>
            <dd>{formatDate(skill.inserted_at)}</dd>
          </div>
        </dl>
      </PushPanel>
    </div>
  {/if}
</div>

<DirtyGuardModal
  open={guardOpen}
  onCancel={() => { guardOpen = false; pendingNavigation = null; }}
  onDiscard={() => { guardOpen = false; pendingNavigation?.(); pendingNavigation = null; }}
/>

<style>
  .skd-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* ── Top bar ── */

  .skd-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .skd-topbar-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .skd-source-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    padding: 2px 8px;
    border: 1px solid var(--border);
    border-radius: 9999px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  /* ── Body layout ── */

  .skd-body {
    display: flex;
    flex: 1;
    overflow: hidden;
    gap: 0;
  }

  .skd-content {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-6);
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    min-width: 0;
  }

  .skd-content-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .skd-name {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .skd-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .skd-markdown {
    flex: 1;
  }

  /* Markdown typography (mirrors agent detail) */
  .skd-markdown :global(.fv-h1) {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-5) 0 var(--space-2);
  }
  .skd-markdown :global(.fv-h2) {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-4) 0 var(--space-2);
  }
  .skd-markdown :global(.fv-h3) {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-3) 0 var(--space-1);
  }
  .skd-markdown :global(.fv-p) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.7;
    margin: 0 0 var(--space-2);
  }
  .skd-markdown :global(.fv-ul),
  .skd-markdown :global(.fv-ol) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.7;
    margin: 0 0 var(--space-2);
    padding-left: var(--space-5);
  }
  .skd-markdown :global(.fv-code-block) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3) var(--space-4);
    overflow-x: auto;
    margin: 0 0 var(--space-3);
  }
  .skd-markdown :global(.fv-inline-code) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: var(--radius-sm);
    padding: 1px 4px;
  }
  .skd-markdown :global(.fv-link) {
    color: var(--fg);
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  /* ── Editor ── */

  .skd-editor {
    width: 100%;
    min-height: 400px;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    line-height: 1.7;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-5);
    resize: vertical;
    outline: none;
    box-sizing: border-box;
  }

  .skd-editor:focus {
    border-color: var(--fg-subtle);
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--fg) 10%, transparent 90%);
  }

  /* ── Metadata ── */

  .skd-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin: 0;
    padding: 0;
  }

  .skd-meta-row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-3);
  }

  .skd-meta-row--stack {
    flex-direction: column;
    gap: var(--space-1);
  }

  .skd-meta dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .skd-meta dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-align: right;
    word-break: break-all;
  }

  .skd-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-variant-numeric: tabular-nums;
  }

  .skd-url {
    text-align: left;
    word-break: break-all;
    font-size: 10px;
  }

  .skd-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    text-align: left;
  }

  .skd-chip {
    display: inline-flex;
    padding: 2px 8px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    border: 1px solid var(--border);
  }

  /* ── Skeletons ── */

  .skd-loading {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-8);
    max-width: 600px;
  }

  .sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: sk-pulse 1.5s ease-in-out infinite;
  }

  .sk--title { height: 28px; width: 50%; }
  .sk--body { height: 14px; width: 90%; }
  .sk--short { width: 70%; }

  @keyframes sk-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
