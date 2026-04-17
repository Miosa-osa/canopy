<script lang="ts">
/**
 * EmptyState — consistent empty/zero-data screen.
 * Always shows icon + headline + body + primary CTA (docs/02-frontend-design.md §9).
 * Accepts any Lucide icon via the icon prop (typed as SvelteComponent for compatibility).
 * LOC target: ≤ 80.
 */
import type { Snippet } from 'svelte';

// lucide-svelte v1 exports Svelte 4 class-based components. Use unknown
// for the icon type and cast at the svelte:component call site.
type AnyIcon = unknown;

interface Props {
  /** Lucide icon component — pass the component class/function itself. */
  icon?: AnyIcon;
  /** Heading text. */
  title: string;
  /** 1–2 sentence body text. */
  body?: string;
  /** CTA label. */
  action?: string;
  /** CTA click handler. */
  onAction?: () => void;
  /** Optional snippet for a custom icon rendering. */
  children?: Snippet;
  class?: string;
}

let {
  icon: Icon,
  title,
  body,
  action,
  onAction,
  children,
  class: className = '',
}: Props = $props();
</script>

<div class="cnp-empty {className}" role="status">
  <div class="cnp-empty__icon" aria-hidden="true">
    {#if children}
      {@render children()}
    {:else if Icon}
      <!-- svelte-ignore svelte_component_deprecated -->
      <svelte:component
        this={Icon as unknown as typeof import('svelte').SvelteComponent}
        size={48}
      />
    {/if}
  </div>
  <h2 class="cnp-empty__title">{title}</h2>
  {#if body}
    <p class="cnp-empty__body">{body}</p>
  {/if}
  {#if action && onAction}
    <button class="btn-pill btn-pill-primary btn-pill-sm cnp-empty__cta" onclick={onAction}>
      {action}
    </button>
  {/if}
</div>

<style>
  .cnp-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-3);
    padding: var(--space-12) var(--space-8);
    text-align: center;
  }

  .cnp-empty__icon {
    color: var(--fg-subtle);
    opacity: 0.6;
  }

  .cnp-empty__title {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    line-height: var(--lh-xl);
    letter-spacing: var(--tracking-xl);
  }

  .cnp-empty__body {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    max-width: 320px;
    line-height: 1.6;
  }

  .cnp-empty__cta {
    margin-top: var(--space-1);
  }
</style>
