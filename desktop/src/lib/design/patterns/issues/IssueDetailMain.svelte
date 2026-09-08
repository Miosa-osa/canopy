<script lang="ts">
/**
 * IssueDetailMain — left pane of the issue detail page.
 * Renders title (inline edit), description textarea, and activity feed.
 * CSS prefix: id- (shared with /issues/[short_id] page).
 */
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import type { Issue } from '$lib/domain/issues/types.js';

interface Props {
  issue: Issue | undefined;
  isLoading: boolean;
  isError: boolean;
  backendUnavailable: boolean;
  errorMessage: string;
  localTitle: string;
  localDesc: string;
  titleDirty: boolean;
  descDirty: boolean;
  isSaving: boolean;
  onTitleInput: (value: string) => void;
  onTitleBlur: () => void;
  onTitleKeydown: (e: KeyboardEvent) => void;
  onSaveTitle: () => void;
  onDescInput: (value: string) => void;
  onDescKeydown: (e: KeyboardEvent) => void;
  onSaveDesc: () => void;
  onDiscardDesc: () => void;
}

let {
  issue,
  isLoading,
  isError,
  backendUnavailable,
  errorMessage,
  localTitle,
  localDesc,
  titleDirty,
  descDirty,
  isSaving,
  onTitleInput,
  onTitleBlur,
  onTitleKeydown,
  onSaveTitle,
  onDescInput,
  onDescKeydown,
  onSaveDesc,
  onDiscardDesc,
}: Props = $props();

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}
</script>

<main class="id-main">
  {#if isLoading}
    <div class="id-skeleton">
      <SkeletonList count={5} height="1.5rem" gap="0.5rem" />
    </div>

  {:else if backendUnavailable}
    <div class="id-banner" role="status">
      Backend not ready — retry later. Issues endpoint returning 404.
    </div>

  {:else if isError && !backendUnavailable}
    <p class="id-error" role="alert">{errorMessage}</p>

  {:else if issue}
    <!-- Inline title edit -->
    <div class="id-title-wrap">
      <input
        class="id-title-input"
        type="text"
        value={localTitle}
        oninput={(e) => onTitleInput((e.currentTarget as HTMLInputElement).value)}
        onblur={onTitleBlur}
        onkeydown={onTitleKeydown}
        aria-label="Issue title"
        autocomplete="off"
      />
      {#if titleDirty}
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={onSaveTitle}
          disabled={isSaving}
          aria-label="Save title"
        >Save</button>
      {/if}
    </div>

    <!-- Description -->
    <label class="id-label" for="id-desc">Description</label>
    <textarea
      id="id-desc"
      class="id-desc"
      value={localDesc}
      oninput={(e) => onDescInput((e.currentTarget as HTMLTextAreaElement).value)}
      onkeydown={onDescKeydown}
      placeholder="Add a description…"
      rows={8}
      aria-label="Issue description"
    ></textarea>

    {#if descDirty}
      <div class="id-desc-actions">
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={onSaveDesc}
          disabled={isSaving}
        >
          {isSaving ? 'Saving…' : 'Save'}
        </button>
        <button
          class="btn-compact btn-compact-ghost"
          onclick={onDiscardDesc}
        >Discard</button>
        <span class="id-hint">or ⌘S</span>
      </div>
    {/if}

    <!-- Activity feed -->
    <div class="id-activity">
      <p class="id-activity-label">Activity</p>
      <div class="id-activity-item">
        <span class="id-activity-dot"></span>
        <span class="id-activity-text">
          Issue created {formatDate(issue.insertedAt)}
        </span>
      </div>
      {#if issue.insertedAt !== issue.updatedAt}
        <div class="id-activity-item">
          <span class="id-activity-dot"></span>
          <span class="id-activity-text">
            Last updated {formatDate(issue.updatedAt)}
          </span>
        </div>
      {/if}
    </div>
  {/if}
</main>

<style>
  .id-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    overflow-y: auto;
    padding: var(--space-5);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .id-skeleton { width: 100%; }

  .id-banner {
    padding: var(--space-2) var(--space-3);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .id-error {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--signal-error, red);
  }

  /* Title */
  .id-title-wrap {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .id-title-input {
    flex: 1;
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    background: transparent;
    border: none;
    outline: none;
    border-bottom: 2px solid transparent;
    padding: var(--space-1) 0;
    transition: border-color 0.12s ease;
    letter-spacing: -0.025em;
  }

  .id-title-input:focus {
    border-bottom-color: color-mix(in oklch, var(--fg) 30%, transparent);
  }

  /* Description */
  .id-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .id-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    resize: vertical;
    outline: none;
    line-height: 1.6;
    min-height: 160px;
    transition: border-color 0.12s ease;
  }

  .id-desc:focus {
    border-color: color-mix(in oklch, var(--fg) 40%, transparent);
  }

  .id-desc-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .id-hint {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* Activity feed */
  .id-activity {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    margin-top: var(--space-2);
  }

  .id-activity-label {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .id-activity-item {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .id-activity-dot {
    width: 6px;
    height: 6px;
    border-radius: 9999px;
    background: var(--border-strong, var(--fg-subtle));
    flex-shrink: 0;
  }

  .id-activity-text {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }
</style>
