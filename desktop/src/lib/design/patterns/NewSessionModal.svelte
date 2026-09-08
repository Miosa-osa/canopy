<script lang="ts">
/**
 * NewSessionModal — spawn a new session from any entry point.
 *
 * Fields:
 *   1. Runtime picker — authenticated runtimes (installed === true fallback).
 *   2. Workspace picker — with inline "Create default workspace" if empty.
 *   3. Initial prompt (optional textarea).
 *
 * On submit: POST /api/v1/sessions → goto /sessions/:id.
 *
 * CSS prefix: nsm-
 */

import {
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { X } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { createSession, listRuntimes, listWorkspaces } from '$lib/api/queries/sessions-modal.js';
import { createWorkspace } from '$lib/api/queries/workspaces.js';
import type { Runtime } from '$lib/domain/runtimes/types.js';
import type { Workspace } from '$lib/domain/workspaces/types.js';

interface Props {
  open: boolean;
  onClose: () => void;
}

let { open, onClose }: Props = $props();

const queryClient = useQueryClient();

// ── Queries ──────────────────────────────────────────────────────────────────

const runtimeOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['runtimes'] as const,
        queryFn: listRuntimes,
        staleTime: 30_000,
        enabled: open,
      }) as CreateQueryOptions<Runtime[]>
  )
);

$effect(() => {
  runtimeOptsStore.set({
    queryKey: ['runtimes'] as const,
    queryFn: listRuntimes,
    staleTime: 30_000,
    enabled: open,
  } as CreateQueryOptions<Runtime[]>);
});

const runtimesQuery = createQuery<Runtime[]>(runtimeOptsStore);

const workspaceOptsStore = writable(
  untrack(
    () =>
      ({
        queryKey: ['workspaces', {}] as const,
        queryFn: () => listWorkspaces(),
        staleTime: 30_000,
        enabled: open,
      }) as CreateQueryOptions<Workspace[]>
  )
);

$effect(() => {
  workspaceOptsStore.set({
    queryKey: ['workspaces', {}] as const,
    queryFn: () => listWorkspaces(),
    staleTime: 30_000,
    enabled: open,
  } as CreateQueryOptions<Workspace[]>);
});

const workspacesQuery = createQuery<Workspace[]>(workspaceOptsStore);

// ── Active runtimes — credentials.status === "active" OR installed fallback ──

const activeRuntimes = $derived(
  ($runtimesQuery.data ?? []).filter((r: Runtime) => {
    // Accept any runtime that is installed (binary detected on disk) or is
    // an API-type runtime (no binary needed). The status field from the
    // backend is "installed" | "not_installed"; the legacy `installed`
    // boolean may also be present on the raw API response.
    const raw = r as Runtime & { installed?: boolean };
    if (raw.installed === true) return true;
    if (r.status === 'installed') return true;
    if (r.kind === 'api') return true;
    return false;
  })
);

const workspaces = $derived($workspacesQuery.data ?? []);

// ── Form state ───────────────────────────────────────────────────────────────

let runtimeType = $state('');
let workspaceSlug = $state('');
let initialPrompt = $state('');
let creatingDefault = $state(false);
let formError = $state<string | null>(null);

// Auto-select first available runtime when list loads.
$effect(() => {
  if (runtimeType === '' && activeRuntimes.length > 0) {
    runtimeType = activeRuntimes[0].type;
  }
});

// Auto-select first workspace when list loads.
$effect(() => {
  if (workspaceSlug === '' && workspaces.length > 0) {
    workspaceSlug = workspaces[0].slug;
  }
});

// ── Mutations ────────────────────────────────────────────────────────────────

const createMut = createMutation({
  mutationFn: (body: Parameters<typeof createSession>[0]) => createSession(body),
  onSuccess: (session) => {
    // Backend's interactive-mode response has `session_id` → `sessionId` after
    // camelCase conversion; legacy non-interactive returns `id`. Accept either.
    const s = session as unknown as { id?: string; sessionId?: string };
    const id = s.sessionId ?? s.id;
    queryClient.invalidateQueries({ queryKey: ['sessions'] });
    onClose();
    if (id) void goto(`/sessions/${id}`);
  },
  onError: (err: Error) => {
    formError = err.message ?? 'Failed to create session.';
  },
});

async function handleCreateDefault(): Promise<void> {
  creatingDefault = true;
  formError = null;
  try {
    const ws = await createWorkspace({
      slug: 'default',
      name: 'Default',
      rootPath: '~',
    });
    await queryClient.invalidateQueries({ queryKey: ['workspaces'] });
    workspaceSlug = ws.slug;
  } catch (err) {
    formError = err instanceof Error ? err.message : 'Failed to create workspace.';
  } finally {
    creatingDefault = false;
  }
}

function handleSubmit(): void {
  formError = null;
  if (!runtimeType) {
    formError = 'Select a runtime to continue.';
    return;
  }
  $createMut.mutate({
    runtimeType,
    cwd: '~',
    workspaceSlug: workspaceSlug || undefined,
    prompt: initialPrompt.trim() || undefined,
  });
}

function handleKeydown(e: KeyboardEvent): void {
  if (!open) return;
  if (e.key === 'Escape') {
    e.preventDefault();
    onClose();
  }
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    handleSubmit();
  }
}

function reset(): void {
  runtimeType = '';
  workspaceSlug = '';
  initialPrompt = '';
  formError = null;
}

$effect(() => {
  if (open) return;
  reset();
});
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="nsm-backdrop" onclick={onClose} aria-hidden="true"></div>

  <div
    class="nsm-dialog"
    role="dialog"
    aria-modal="true"
    aria-labelledby="nsm-title"
  >
    <header class="nsm-header">
      <h2 class="nsm-title" id="nsm-title">New session</h2>
      <button class="nsm-close btn-compact btn-compact-ghost" onclick={onClose} aria-label="Close">
        <X size={14} aria-hidden="true" />
      </button>
    </header>

    <div class="nsm-body">
      <!-- Runtime picker -->
      <div class="nsm-field">
        <label class="nsm-label" for="nsm-runtime">Runtime</label>
        {#if $runtimesQuery.isLoading}
          <div class="nsm-select nsm-placeholder">Loading runtimes…</div>
        {:else if activeRuntimes.length === 0}
          <div class="nsm-select nsm-placeholder nsm-placeholder--warn">
            No authenticated runtimes — configure one in Settings.
          </div>
        {:else}
          <select
            id="nsm-runtime"
            class="nsm-select"
            bind:value={runtimeType}
            aria-label="Select runtime"
          >
            {#each activeRuntimes as r (r.type)}
              <option value={r.type}>{r.name} {r.version ? `(${r.version})` : ''}</option>
            {/each}
          </select>
        {/if}
      </div>

      <!-- Workspace picker -->
      <div class="nsm-field">
        <label class="nsm-label" for="nsm-workspace">Workspace</label>
        {#if $workspacesQuery.isLoading}
          <div class="nsm-select nsm-placeholder">Loading workspaces…</div>
        {:else if workspaces.length === 0}
          <div class="nsm-workspace-empty">
            <span class="nsm-placeholder">No workspaces yet.</span>
            <button
              class="nsm-inline-action"
              onclick={handleCreateDefault}
              disabled={creatingDefault}
              aria-label="Create default workspace"
            >
              {creatingDefault ? 'Creating…' : '+ Create default'}
            </button>
          </div>
        {:else}
          <select
            id="nsm-workspace"
            class="nsm-select"
            bind:value={workspaceSlug}
            aria-label="Select workspace"
          >
            <option value="">No workspace</option>
            {#each workspaces as w (w.slug)}
              <option value={w.slug}>{w.name}</option>
            {/each}
          </select>
        {/if}
      </div>

      <!-- Initial prompt -->
      <div class="nsm-field">
        <label class="nsm-label" for="nsm-prompt">Initial prompt <span class="nsm-optional">(optional)</span></label>
        <textarea
          id="nsm-prompt"
          class="nsm-textarea"
          rows="3"
          placeholder="What should the agent do first?"
          bind:value={initialPrompt}
        ></textarea>
      </div>

      {#if formError}
        <p class="nsm-error" role="alert">{formError}</p>
      {/if}
    </div>

    <footer class="nsm-footer">
      <button class="nsm-btn nsm-btn--cancel" onclick={onClose}>Cancel</button>
      <button
        class="nsm-btn nsm-btn--submit"
        onclick={handleSubmit}
        disabled={$createMut.isPending || activeRuntimes.length === 0}
        aria-label="Spawn session (Cmd+Enter)"
      >
        {#if $createMut.isPending}
          <span class="nsm-spinner" aria-hidden="true"></span>
          Spawning…
        {:else}
          Spawn terminal
        {/if}
      </button>
    </footer>
  </div>
{/if}

<style>
  .nsm-backdrop {
    position: fixed;
    inset: 0;
    z-index: 49;
    background: color-mix(in oklch, black 60%, transparent);
  }

  .nsm-dialog {
    position: fixed;
    left: 50%;
    top: 50%;
    z-index: 50;
    transform: translate(-50%, -50%);
    width: min(440px, calc(100vw - 2rem));
    background: var(--bg-elevated, #111);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg, 12px);
    display: flex;
    flex-direction: column;
    box-shadow: 0 12px 40px color-mix(in oklch, black 50%, transparent);
  }

  .nsm-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
  }

  .nsm-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  .nsm-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-md);
    flex-shrink: 0;
  }

  .nsm-body {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-5);
  }

  .nsm-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .nsm-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .nsm-optional {
    font-weight: 400;
    color: var(--fg-subtle);
    text-transform: none;
    letter-spacing: normal;
  }

  .nsm-select {
    width: 100%;
    padding: 7px 10px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    appearance: none;
    cursor: pointer;
    transition: border-color 0.12s ease;
  }

  .nsm-select:focus-visible {
    outline: none;
    border-color: var(--cnp-accent, var(--fg-muted));
  }

  .nsm-placeholder {
    display: flex;
    align-items: center;
    height: 34px;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
    border: 1px dashed var(--border);
    border-radius: var(--radius-md);
    padding: 0 var(--space-3);
    pointer-events: none;
  }

  .nsm-placeholder--warn {
    color: var(--signal-warn, oklch(0.75 0.15 80));
    border-color: color-mix(in oklch, var(--signal-warn, oklch(0.75 0.15 80)) 30%, var(--border));
  }

  .nsm-workspace-empty {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .nsm-workspace-empty .nsm-placeholder {
    flex: 1;
  }

  .nsm-inline-action {
    flex-shrink: 0;
    padding: 5px 10px;
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    transition: background 0.12s ease, color 0.12s ease;
  }

  .nsm-inline-action:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  .nsm-inline-action:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .nsm-textarea {
    width: 100%;
    padding: 8px 10px;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    resize: vertical;
    min-height: 72px;
    line-height: 1.5;
    transition: border-color 0.12s ease;
    box-sizing: border-box;
  }

  .nsm-textarea:focus-visible {
    outline: none;
    border-color: var(--cnp-accent, var(--fg-muted));
  }

  .nsm-textarea::placeholder {
    color: var(--fg-subtle);
    font-style: italic;
  }

  .nsm-error {
    margin: 0;
    padding: 6px 10px;
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--signal-error, oklch(0.65 0.22 25));
    background: color-mix(in oklch, var(--signal-error, oklch(0.65 0.22 25)) 8%, transparent);
    border: 1px solid color-mix(in oklch, var(--signal-error, oklch(0.65 0.22 25)) 25%, var(--border));
  }

  .nsm-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-top: 1px solid var(--border);
  }

  .nsm-btn {
    padding: 6px 14px;
    border-radius: var(--radius-md);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    cursor: pointer;
    border: 1px solid var(--border);
    transition: background 0.12s ease, color 0.12s ease;
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .nsm-btn--cancel {
    background: transparent;
    color: var(--fg-muted);
  }

  .nsm-btn--cancel:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
  }

  .nsm-btn--submit {
    background: var(--fg);
    color: var(--bg);
    border-color: transparent;
  }

  .nsm-btn--submit:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 85%, transparent);
  }

  .nsm-btn--submit:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }

  .nsm-btn:focus-visible {
    outline: 2px solid var(--cnp-accent, var(--fg));
    outline-offset: 2px;
  }

  .nsm-spinner {
    display: inline-block;
    width: 10px;
    height: 10px;
    border: 1.5px solid color-mix(in oklch, var(--bg) 40%, transparent);
    border-top-color: var(--bg);
    border-radius: 50%;
    animation: nsm-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes nsm-spin {
    to { transform: rotate(360deg); }
  }
</style>
