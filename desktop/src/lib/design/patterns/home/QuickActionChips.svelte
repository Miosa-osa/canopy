<script lang="ts">
import {
  Bug,
  CircleAlert,
  Code,
  FileSearch,
  FileText,
  FlaskConical,
  Plus,
  RefreshCw,
} from 'lucide-svelte';

interface Props {
  onSelect: (prompt: string) => void;
}

let { onSelect }: Props = $props();

const CHIPS = [
  {
    label: 'Review code',
    prompt: 'Review my code for bugs, security issues, and improvements',
    icon: 'code',
  },
  {
    label: 'Write tests',
    prompt: 'Write comprehensive tests for the current module',
    icon: 'flask',
  },
  { label: 'Fix failing CI', prompt: 'Investigate and fix the failing CI pipeline', icon: 'alert' },
  {
    label: 'Explain codebase',
    prompt: 'Explain this codebase architecture and key patterns',
    icon: 'search',
  },
  { label: 'New feature', prompt: 'Create a new feature', icon: 'plus' },
  {
    label: 'Refactor',
    prompt: 'Refactor this file for clarity and maintainability',
    icon: 'refresh',
  },
  { label: 'Debug issue', prompt: 'Debug this issue systematically', icon: 'bug' },
  { label: 'Write docs', prompt: 'Write clear documentation for this module', icon: 'file' },
] as const;
</script>

<div class="qac-row" role="list" aria-label="Quick actions">
  {#each CHIPS as chip, i (chip.label)}
    <button
      class="qac-chip"
      style="animation-delay: {i * 40}ms"
      onclick={() => onSelect(chip.prompt)}
      role="listitem"
      aria-label="Quick action: {chip.label}"
    >
      {#if chip.icon === 'code'}<Code size={13} aria-hidden="true" />
      {:else if chip.icon === 'flask'}<FlaskConical size={13} aria-hidden="true" />
      {:else if chip.icon === 'alert'}<CircleAlert size={13} aria-hidden="true" />
      {:else if chip.icon === 'search'}<FileSearch size={13} aria-hidden="true" />
      {:else if chip.icon === 'plus'}<Plus size={13} aria-hidden="true" />
      {:else if chip.icon === 'refresh'}<RefreshCw size={13} aria-hidden="true" />
      {:else if chip.icon === 'bug'}<Bug size={13} aria-hidden="true" />
      {:else if chip.icon === 'file'}<FileText size={13} aria-hidden="true" />
      {/if}
      {chip.label}
    </button>
  {/each}
</div>

<style>
  .qac-row {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
    justify-content: center;
  }

  .qac-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-family: var(--font-sans);
    font-size: 12px;
    color: var(--fg-muted);
    background: transparent;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm, 6px);
    padding: 5px 10px;
    cursor: pointer;
    white-space: nowrap;
    opacity: 0;
    animation: qac-fade 180ms ease-out forwards;
    transition: border-color 100ms, color 100ms, background 100ms;
  }

  .qac-chip:hover {
    border-color: var(--fg-subtle);
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  .qac-chip:focus-visible {
    outline: 2px solid var(--cnp-accent, #6366f1);
    outline-offset: 2px;
  }

  @keyframes qac-fade {
    from { opacity: 0; transform: translateY(3px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  @media (prefers-reduced-motion: reduce) {
    .qac-chip { animation: none; opacity: 1; }
  }
</style>
