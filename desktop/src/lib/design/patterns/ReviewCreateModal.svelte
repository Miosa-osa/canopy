<script lang="ts">
import type { ArtifactType, CreateReviewBody, ReviewKind } from '$lib/domain/reviews/types.js';

interface Props {
  isPending?: boolean;
  onCreate: (body: CreateReviewBody) => void;
  onClose: () => void;
}

let { isPending = false, onCreate, onClose }: Props = $props();

let kind = $state<Exclude<ReviewKind, 'hire_agent'>>('artifact');
let workspaceSlug = $state('default');
let agentId = $state('');
let artifactType = $state<ArtifactType>('doc');
let artifactId = $state('');
let artifactPreview = $state('');
let toolName = $state('');
let toolArgs = $state('{\n  \n}');
let sessionId = $state('');
let error = $state<string | null>(null);

function closeOnEscape(e: KeyboardEvent): void {
  if (e.key === 'Escape') onClose();
}

function handleBackdropClick(e: MouseEvent): void {
  if ((e.target as HTMLElement).classList.contains('rcm-backdrop')) onClose();
}

function parseToolArgs(): Record<string, unknown> {
  const trimmed = toolArgs.trim();
  if (!trimmed) return {};
  const parsed = JSON.parse(trimmed) as unknown;
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new Error('Tool args must be a JSON object.');
  }
  return parsed as Record<string, unknown>;
}

function submit(): void {
  error = null;

  try {
    if (kind === 'artifact') {
      onCreate({
        kind: 'artifact',
        workspaceSlug: workspaceSlug.trim() || undefined,
        artifactType,
        artifactId: artifactId.trim() || undefined,
        artifactPreview: artifactPreview.trim() || undefined,
        agentId: agentId.trim() || undefined,
      });
      return;
    }

    if (!toolName.trim()) {
      error = 'Tool name is required.';
      return;
    }

    onCreate({
      kind: 'tool_call',
      workspaceSlug: workspaceSlug.trim() || undefined,
      toolName: toolName.trim(),
      toolArgs: parseToolArgs(),
      sessionId: sessionId.trim() || undefined,
      agentId: agentId.trim() || undefined,
    });
  } catch (err) {
    error = err instanceof Error ? err.message : 'Invalid review request.';
  }
}
</script>

<svelte:window onkeydown={closeOnEscape} />

<!-- svelte-ignore a11y_click_events_have_key_events -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="rcm-backdrop" onclick={handleBackdropClick}>
  <div class="rcm-modal glass-panel" role="dialog" aria-modal="true" aria-label="New review">
    <header class="rcm-header">
      <div class="rcm-title-block">
        <h2>New review</h2>
        <p>Creates a pending row in the backend <code>reviews</code> table.</p>
      </div>
      <button class="btn-compact btn-compact-ghost rcm-close" type="button" onclick={onClose} aria-label="Close">&times;</button>
    </header>

    <div class="rcm-body">
      <div class="rcm-segments" role="group" aria-label="Review kind">
        <button type="button" class:rcm-segment--active={kind === 'artifact'} onclick={() => { kind = 'artifact'; }}>
          Artifact
        </button>
        <button type="button" class:rcm-segment--active={kind === 'tool_call'} onclick={() => { kind = 'tool_call'; }}>
          Tool call
        </button>
      </div>

      <div class="rcm-note">
        {#if kind === 'artifact'}
          Artifact reviews are for docs, tasks, issues, PRs, files, or knowledge chunks that need a human decision before publishing or using them.
        {:else}
          Tool-call reviews are for approval-gated actions. Agents normally create these automatically before a risky tool runs.
        {/if}
      </div>

      <div class="rcm-grid">
        <label class="rcm-field">
          <span>Workspace</span>
          <input bind:value={workspaceSlug} placeholder="default" />
        </label>
        <label class="rcm-field">
          <span>Agent</span>
          <input bind:value={agentId} placeholder="agent slug" />
        </label>
      </div>

      {#if kind === 'artifact'}
        <div class="rcm-grid">
          <label class="rcm-field">
            <span>Type</span>
            <select bind:value={artifactType}>
              <option value="doc">Doc</option>
              <option value="task">Task</option>
              <option value="issue">Issue</option>
              <option value="pr">PR</option>
              <option value="file">File</option>
              <option value="kb_chunk">KB chunk</option>
            </select>
          </label>
          <label class="rcm-field">
            <span>Artifact ID</span>
            <input bind:value={artifactId} placeholder="optional" />
          </label>
        </div>
        <label class="rcm-field">
          <span>Preview</span>
          <textarea bind:value={artifactPreview} rows="7" placeholder="Paste the artifact summary or content to review"></textarea>
        </label>
      {:else}
        <div class="rcm-grid">
          <label class="rcm-field">
            <span>Tool name</span>
            <input bind:value={toolName} placeholder="exec_shell" />
          </label>
          <label class="rcm-field">
            <span>Session ID</span>
            <input bind:value={sessionId} placeholder="optional uuid" />
          </label>
        </div>
        <label class="rcm-field">
          <span>Args JSON</span>
          <textarea class="rcm-mono" bind:value={toolArgs} rows="7"></textarea>
        </label>
      {/if}

      {#if error}
        <p class="rcm-error">{error}</p>
      {/if}
    </div>

    <footer class="rcm-footer">
      <button type="button" class="btn-pill btn-pill-secondary btn-pill-sm" onclick={onClose}>Cancel</button>
      <button type="button" class="btn-pill btn-pill-primary btn-pill-sm" onclick={submit} disabled={isPending}>
        {isPending ? 'Creating...' : 'Create'}
      </button>
    </footer>
  </div>
</div>

<style>
  .rcm-backdrop {
    position: fixed;
    inset: 0;
    z-index: 900;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: var(--space-4);
    background: color-mix(in oklch, var(--bg) 42%, transparent);
    backdrop-filter: blur(4px);
  }

  .rcm-modal {
    width: min(640px, 100%);
    max-height: 86vh;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    border-radius: var(--radius-lg, 12px);
  }

  .rcm-header,
  .rcm-footer {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .rcm-footer {
    justify-content: flex-end;
    border-top: 1px solid var(--border);
    border-bottom: none;
  }

  .rcm-title-block {
    flex: 1;
    min-width: 0;
  }

  .rcm-title-block h2 {
    margin: 0;
    color: var(--fg);
    font-size: var(--text-lg);
    font-weight: 600;
  }

  .rcm-title-block p {
    margin: 2px 0 0;
    color: var(--fg-muted);
    font-size: var(--text-xs);
  }

  .rcm-title-block code {
    font-family: var(--font-mono);
    color: var(--fg);
  }

  .rcm-close {
    color: var(--fg-muted);
    font-size: 18px;
    line-height: 1;
  }

  .rcm-body {
    flex: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-5);
  }

  .rcm-segments {
    display: inline-flex;
    width: max-content;
    gap: 2px;
    padding: 2px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
  }

  .rcm-segments button {
    border: 0;
    border-radius: var(--radius-sm);
    background: transparent;
    color: var(--fg-muted);
    cursor: pointer;
    padding: 5px 10px;
    font-size: var(--text-xs);
    font-weight: 600;
  }

  .rcm-segments button:hover,
  .rcm-segment--active {
    background: var(--bg);
    color: var(--fg) !important;
  }

  .rcm-note {
    color: var(--fg-muted);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    font-size: var(--text-xs);
    line-height: 1.5;
  }

  .rcm-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-3);
  }

  .rcm-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rcm-field span {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rcm-field input,
  .rcm-field select,
  .rcm-field textarea {
    width: 100%;
    box-sizing: border-box;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: var(--bg-inset);
    color: var(--fg);
    font: inherit;
    font-size: var(--text-sm);
    padding: 7px 9px;
    outline: none;
  }

  .rcm-field textarea {
    resize: vertical;
    min-height: 120px;
  }

  .rcm-field input:focus,
  .rcm-field select:focus,
  .rcm-field textarea:focus {
    border-color: var(--fg-muted);
  }

  .rcm-mono {
    font-family: var(--font-mono) !important;
    font-size: var(--text-xs) !important;
  }

  .rcm-error {
    margin: 0;
    color: var(--signal-error, oklch(0.65 0.22 25));
    font-size: var(--text-sm);
  }

  @media (max-width: 640px) {
    .rcm-grid {
      grid-template-columns: 1fr;
    }
  }
</style>
