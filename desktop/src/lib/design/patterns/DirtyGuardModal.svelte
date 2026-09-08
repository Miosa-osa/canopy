<script lang="ts">
/**
 * DirtyGuardModal — styled confirmation dialog for unsaved-changes guard.
 *
 * Replaces native window.confirm() in beforeNavigate handlers.
 * Two actions: "Keep editing" (cancel) / "Discard changes" (discard).
 *
 * Props:
 *   open      — controls dialog visibility (bindable)
 *   onCancel  — called when user chooses to keep editing
 *   onDiscard — called when user chooses to discard and navigate
 *
 * LOC target: ≤ 100.
 */

interface Props {
  open: boolean;
  onCancel: () => void;
  onDiscard: () => void;
}

let { open, onCancel, onDiscard }: Props = $props();

function handleKeydown(e: KeyboardEvent): void {
  if (!open) return;
  if (e.key === 'Escape') {
    e.preventDefault();
    onCancel();
  }
}
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- Backdrop -->
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
  <div class="dgm-backdrop" onclick={onCancel} aria-hidden="true"></div>

  <!-- Dialog -->
  <div
    class="dgm-dialog"
    role="alertdialog"
    aria-modal="true"
    aria-labelledby="dgm-title"
    aria-describedby="dgm-desc"
  >
    <h2 class="dgm-title" id="dgm-title">Unsaved changes</h2>
    <p class="dgm-desc" id="dgm-desc">
      You have unsaved changes. If you leave now, they will be lost.
    </p>
    <div class="dgm-actions">
      <button class="dgm-btn dgm-btn--cancel" onclick={onCancel}>
        Keep editing
      </button>
      <button class="dgm-btn dgm-btn--discard" onclick={onDiscard}>
        Discard changes
      </button>
    </div>
  </div>
{/if}

<style>
  .dgm-backdrop {
    position: fixed;
    inset: 0;
    z-index: 49;
    background: color-mix(in oklch, black 60%, transparent);
  }

  .dgm-dialog {
    position: fixed;
    left: 50%;
    top: 50%;
    z-index: 50;
    transform: translate(-50%, -50%);
    width: min(400px, calc(100vw - 2rem));
    background: var(--dbg2, var(--bg-elevated, #1a1a1a));
    border: 1px solid var(--dbd, var(--border));
    border-radius: var(--radius-lg, 12px);
    padding: var(--space-6, 1.5rem);
    display: flex;
    flex-direction: column;
    gap: var(--space-4, 1rem);
    box-shadow: 0 8px 32px color-mix(in oklch, black 40%, transparent);
  }

  .dgm-title {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base, 1rem);
    font-weight: 600;
    color: var(--dt, var(--fg));
    line-height: 1.3;
  }

  .dgm-desc {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm, 0.875rem);
    color: var(--dt2, var(--fg-muted));
    line-height: 1.5;
  }

  .dgm-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--space-2, 0.5rem);
    flex-wrap: wrap;
  }

  .dgm-btn {
    padding: 6px 14px;
    border-radius: var(--radius-md, 8px);
    font-family: var(--font-sans);
    font-size: var(--text-sm, 0.875rem);
    font-weight: 500;
    cursor: pointer;
    border: 1px solid var(--dbd, var(--border));
    transition: background 0.12s ease, color 0.12s ease;
  }

  .dgm-btn--cancel {
    background: transparent;
    color: var(--dt2, var(--fg-muted));
  }

  .dgm-btn--cancel:hover {
    background: color-mix(in oklch, var(--dt, currentColor) 8%, transparent);
    color: var(--dt, var(--fg));
  }

  .dgm-btn--discard {
    background: color-mix(in oklch, red 80%, transparent 20%);
    color: white;
    border-color: transparent;
  }

  .dgm-btn--discard:hover {
    background: color-mix(in oklch, red 90%, transparent 10%);
  }

  .dgm-btn:focus-visible {
    outline: 2px solid var(--dt, currentColor);
    outline-offset: 2px;
  }
</style>
