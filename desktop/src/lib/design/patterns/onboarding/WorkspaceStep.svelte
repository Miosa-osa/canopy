<script lang="ts">
/**
 * WorkspaceStep — step 1 of OnboardingWizard.
 * Open existing folder via Tauri dialog OR create from workspace template.
 * CSS prefix: obw-
 */
import { createQuery } from '@tanstack/svelte-query';
import { workspaceTemplatesQuery } from '$lib/api/queries/workspaces.js';
import { isTauri, getTauriDialog } from '$lib/tauri/index.js';

interface Props {
  onNext: () => void;
  onBack: () => void;
  onSkip: () => void;
}

let { onNext, onBack, onSkip }: Props = $props();

let selectedPath = $state<string | null>(null);
let selectedTemplate = $state<string | null>(null);

const templatesQuery = createQuery(workspaceTemplatesQuery());

async function openFolder(): Promise<void> {
  if (!isTauri()) {
    selectedPath = '/my/project';
    return;
  }
  try {
    const { open } = await getTauriDialog();
    const result = await open({ directory: true, multiple: false, title: 'Select workspace folder' });
    if (typeof result === 'string') {
      selectedPath = result;
      selectedTemplate = null;
    }
  } catch {
    // User cancelled — no-op
  }
}

function pickTemplate(slug: string): void {
  selectedTemplate = slug;
  selectedPath = null;
}

const hasSelection = $derived(!!selectedPath || !!selectedTemplate);
</script>

<div class="obw-workspace">
  <p class="obw-workspace__hint">
    Point Canopy at an existing project folder, or start fresh from a template.
  </p>

  <div class="obw-workspace__actions">
    <button class="obw-folder-btn" onclick={openFolder} aria-label="Open existing folder">
      <span aria-hidden="true">📁</span>
      <span>Open existing folder</span>
    </button>
  </div>

  {#if selectedPath}
    <div class="obw-workspace__path" aria-live="polite">
      <span aria-hidden="true">✓</span>
      <code>{selectedPath}</code>
    </div>
  {/if}

  {#if $templatesQuery.data?.length}
    <p class="obw-workspace__or">— or pick a template —</p>
    <div class="obw-workspace__templates">
      {#each $templatesQuery.data as tpl (tpl.slug)}
        <button
          class="obw-tpl-card {selectedTemplate === tpl.slug ? 'obw-tpl-card--selected' : ''}"
          onclick={() => pickTemplate(tpl.slug)}
          aria-pressed={selectedTemplate === tpl.slug}
          aria-label="Use template: {tpl.name}"
        >
          <span class="obw-tpl-name">{tpl.name}</span>
          {#if tpl.description}
            <span class="obw-tpl-desc">{tpl.description}</span>
          {/if}
        </button>
      {/each}
    </div>
  {:else if $templatesQuery.isPending}
    <p class="obw-workspace__or" aria-live="polite">Loading templates…</p>
  {/if}

  <div class="obw-nav">
    <button class="obw-btn-ghost" onclick={onBack}>← Back</button>
    <div class="obw-nav__right">
      <button class="obw-btn-ghost obw-btn-skip" onclick={onSkip}>Skip</button>
      <button class="obw-btn-primary" onclick={onNext} disabled={!hasSelection}>
        Continue →
      </button>
    </div>
  </div>
</div>

<style>
  .obw-workspace {
    display: flex;
    flex-direction: column;
    gap: var(--space-4, 16px);
  }

  .obw-workspace__hint {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .obw-workspace__actions { display: flex; gap: var(--space-2, 8px); }

  .obw-folder-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2, 8px);
    padding: 10px 16px;
    border-radius: 8px;
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    color: var(--fg);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    cursor: pointer;
    transition: border-color 120ms ease;
  }

  .obw-folder-btn:hover { border-color: var(--border-strong); }
  .obw-folder-btn:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }

  .obw-workspace__path {
    display: flex;
    align-items: center;
    gap: var(--space-2, 8px);
    padding: 8px 12px;
    border-radius: 6px;
    background: oklch(from var(--cnp-accent, #6b8cf7) l c h / 0.08);
    font-family: var(--font-mono, monospace);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg);
    word-break: break-all;
  }

  .obw-workspace__or {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-subtle);
    text-align: center;
  }

  .obw-workspace__templates {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-2, 8px);
  }

  .obw-tpl-card {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 12px;
    border-radius: 8px;
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    cursor: pointer;
    text-align: left;
    transition: border-color 120ms ease;
  }

  .obw-tpl-card:hover { border-color: var(--border-strong); }
  .obw-tpl-card--selected { border-color: var(--cnp-accent); }
  .obw-tpl-card:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }

  .obw-tpl-name {
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    font-weight: 600;
    color: var(--fg);
  }

  .obw-tpl-desc {
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-subtle);
  }

  .obw-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: var(--space-4, 16px);
    border-top: 1px solid var(--border);
    margin-top: auto;
  }

  .obw-nav__right { display: flex; gap: var(--space-3, 12px); align-items: center; }

  .obw-btn-ghost {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
    transition: color 120ms ease;
  }

  .obw-btn-ghost:hover { color: var(--fg); }
  .obw-btn-ghost:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
  .obw-btn-skip { font-size: var(--text-xs, 0.75rem); }

  .obw-btn-primary {
    padding: 8px 20px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent);
    color: var(--user-accent-fg, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    font-weight: 600;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .obw-btn-primary:disabled { opacity: 0.4; cursor: not-allowed; }
  .obw-btn-primary:not(:disabled):hover { opacity: 0.88; }
  .obw-btn-primary:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 3px; }
</style>
