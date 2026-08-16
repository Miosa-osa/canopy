<script lang="ts">
/**
 * NewWorkspaceDialog — modal that creates a new Canopy workspace bound to
 * a directory the user picks via Tauri's native folder dialog.
 *
 * Flow:
 *   1. User enters a workspace name (slug is derived automatically).
 *   2. User clicks "Choose folder…" — opens Tauri's `open({ directory: true })`.
 *   3. The selected absolute path is shown in the form.
 *   4. On submit: POST /api/v1/workspaces with name + root_path.
 *   5. On success: setActive(new_slug), close, toast confirmation.
 *
 * CSS prefix: nwd- (NewWorkspaceDialog)
 *
 * Tauri integration: uses `@tauri-apps/plugin-dialog` (already declared in
 * `desktop/package.json`). Dynamic import keeps the dialog testable from
 * Vitest (which runs without a Tauri runtime).
 */

import { createMutation, useQueryClient } from "@tanstack/svelte-query";
import { X } from "lucide-svelte";
import { createWorkspace } from "$lib/api/queries/workspaces.js";
import { activeWorkspace } from "$lib/stores/active-workspace.svelte.js";
import { toasts } from "$lib/stores/toasts.svelte.js";
import type {
  CreateWorkspaceBody,
  Workspace,
} from "$lib/domain/workspaces/types.js";

interface Props {
  open: boolean;
  onClose: () => void;
}

let { open, onClose }: Props = $props();

const queryClient = useQueryClient();

// ── Form state ──────────────────────────────────────────────────────────────

let workspaceName = $state("");
let selectedPath = $state<string | null>(null);
let pickError = $state<string | null>(null);
let formError = $state<string | null>(null);

const slug = $derived(slugify(workspaceName));

// ── Slug derivation ─────────────────────────────────────────────────────────

function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 128);
}

// ── Tauri folder picker ─────────────────────────────────────────────────────

async function pickFolder(): Promise<void> {
  pickError = null;
  try {
    // Dynamic import: keeps the component testable in environments without
    // a Tauri runtime (Vitest / SvelteKit dev SSR).
    const { open: openDialog } = await import("@tauri-apps/plugin-dialog");
    const result = await openDialog({
      directory: true,
      multiple: false,
      title: "Choose workspace folder",
    });

    if (typeof result === "string" && result.length > 0) {
      selectedPath = result;
    }
  } catch (err) {
    pickError =
      err instanceof Error
        ? err.message
        : "Could not open the folder picker.";
  }
}

// ── Create mutation ─────────────────────────────────────────────────────────

const createMut = createMutation({
  mutationFn: (body: CreateWorkspaceBody) => createWorkspace(body),
  onSuccess: async (workspace: Workspace) => {
    await queryClient.invalidateQueries({ queryKey: ["workspaces"] });
    // Sync the active-workspace store with the freshly-fetched pool so
    // setActive() can resolve the new slug.
    const pool = (queryClient.getQueryData<Workspace[]>(["workspaces", {}]) ??
      [workspace]) as Workspace[];
    activeWorkspace.syncPool(pool);
    activeWorkspace.setActive(workspace.slug);
    toasts.success(`Workspace ${workspace.name} created.`);
    reset();
    onClose();
  },
  onError: (err: Error) => {
    formError = err.message ?? "Failed to create workspace.";
  },
});

function handleSubmit(): void {
  formError = null;

  if (workspaceName.trim().length === 0) {
    formError = "Workspace name is required.";
    return;
  }
  if (slug.length === 0) {
    formError = "Workspace name must contain at least one letter or digit.";
    return;
  }
  if (selectedPath === null || selectedPath.trim().length === 0) {
    formError = "Choose a folder to bind this workspace to.";
    return;
  }

  $createMut.mutate({
    slug,
    name: workspaceName.trim(),
    rootPath: selectedPath,
  });
}

function reset(): void {
  workspaceName = "";
  selectedPath = null;
  pickError = null;
  formError = null;
}

function handleKeydown(e: KeyboardEvent): void {
  if (!open) return;
  if (e.key === "Escape") {
    e.preventDefault();
    onClose();
  }
  if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
    e.preventDefault();
    handleSubmit();
  }
}

$effect(() => {
  if (!open) reset();
});
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="nwd-backdrop" onclick={onClose} aria-hidden="true"></div>

  <div
    class="nwd-dialog glass-panel"
    role="dialog"
    aria-modal="true"
    aria-labelledby="nwd-title"
  >
    <header class="nwd-header">
      <h2 id="nwd-title" class="nwd-title">New workspace</h2>
      <button
        type="button"
        class="nwd-close"
        aria-label="Close"
        onclick={onClose}
      >
        <X size={14} aria-hidden="true" />
      </button>
    </header>

    <div class="nwd-body">
      <!-- Name -->
      <label class="nwd-field">
        <span class="nwd-label">Name</span>
        <input
          class="nwd-input"
          type="text"
          bind:value={workspaceName}
          placeholder="My workspace"
          autocomplete="off"
          spellcheck={false}
        />
        {#if slug !== ""}
          <span class="nwd-hint">slug: <code>{slug}</code></span>
        {/if}
      </label>

      <!-- Folder picker -->
      <div class="nwd-field">
        <span class="nwd-label">Folder</span>
        <div class="nwd-folder-row">
          <button
            type="button"
            class="nwd-btn nwd-btn-secondary"
            onclick={pickFolder}
          >
            Choose folder…
          </button>
          {#if selectedPath}
            <span class="nwd-folder-path" title={selectedPath}>
              {selectedPath}
            </span>
          {:else}
            <span class="nwd-folder-empty">No folder selected.</span>
          {/if}
        </div>
        {#if pickError}
          <span class="nwd-error">{pickError}</span>
        {/if}
      </div>

      {#if formError}
        <div class="nwd-error" role="alert">{formError}</div>
      {/if}
    </div>

    <footer class="nwd-footer">
      <button
        type="button"
        class="nwd-btn nwd-btn-secondary"
        onclick={onClose}
      >
        Cancel
      </button>
      <button
        type="button"
        class="nwd-btn nwd-btn-primary"
        onclick={handleSubmit}
        disabled={$createMut.isPending}
      >
        {$createMut.isPending ? "Creating…" : "Create workspace"}
      </button>
    </footer>
  </div>
{/if}

<style>
  .nwd-backdrop {
    position: fixed;
    inset: 0;
    z-index: 60;
    background: color-mix(in oklch, var(--bg) 60%, transparent 40%);
  }

  .nwd-dialog {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 61;
    width: min(480px, calc(100vw - var(--space-4)));
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-lg);
    overflow: hidden;
    box-shadow:
      0 20px 60px color-mix(in oklch, var(--bg) 50%, transparent 50%),
      0 4px 12px color-mix(in oklch, var(--bg) 30%, transparent 70%);
  }

  .nwd-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3);
    border-bottom: 1px solid var(--border);
  }

  .nwd-title {
    font-family: var(--font-sans);
    font-size: var(--text-md);
    font-weight: 500;
    color: var(--fg);
    margin: 0;
  }

  .nwd-close {
    background: transparent;
    border: none;
    color: var(--fg-muted);
    cursor: pointer;
    padding: var(--space-1);
    border-radius: var(--radius-sm);
  }

  .nwd-close:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .nwd-body {
    padding: var(--space-3);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .nwd-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .nwd-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .nwd-input {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-1) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    box-sizing: border-box;
  }

  .nwd-input:focus {
    border-color: var(--border-strong);
  }

  .nwd-hint {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .nwd-hint code {
    color: var(--fg-muted);
  }

  .nwd-folder-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .nwd-folder-path {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  .nwd-folder-empty {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .nwd-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--danger, #e54a4a);
  }

  .nwd-footer {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-3);
    border-top: 1px solid var(--border);
  }

  .nwd-btn {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    padding: var(--space-1) var(--space-3);
    border-radius: var(--radius-md);
    cursor: pointer;
    border: 1px solid transparent;
    min-height: 28px;
  }

  .nwd-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .nwd-btn-secondary {
    background: transparent;
    color: var(--fg-muted);
    border-color: var(--border);
  }

  .nwd-btn-secondary:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .nwd-btn-primary {
    background: var(--accent, var(--fg));
    color: var(--bg);
    border-color: var(--accent, var(--fg));
  }

  .nwd-btn-primary:hover:not(:disabled) {
    opacity: 0.9;
  }
</style>
