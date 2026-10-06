<script lang="ts">
  import { goto } from '$app/navigation';

  interface Props {
    class?: string;
    onWakeAll?: () => void;
  }

  let { class: className = '', onWakeAll }: Props = $props();

  interface Action {
    label: string;
    ariaLabel: string;
    iconPath: string;
    onclick: () => void;
  }

  const actions: Action[] = [
    {
      label: 'New Signal',
      ariaLabel: 'Go to signals',
      iconPath: 'M12 5v14M5 12h14',
      onclick: () => goto('/app/signals'),
    },
    {
      label: 'Wake All',
      ariaLabel: 'Wake all sleeping agents',
      iconPath: 'M13 2L3 14h9l-1 8 10-12h-9l1-8z',
      onclick: () => onWakeAll?.(),
    },
    {
      label: 'Deploy Agent',
      ariaLabel: 'Deploy a new agent',
      iconPath: 'M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09zm12-12a3 3 0 0 0-4.24 0L3 13.72V21h7.28l9.22-9.26a3 3 0 0 0 0-4.24l-3-3z',
      onclick: () => goto('/app/agents?hire=1'),
    },
    {
      label: 'View Org',
      ariaLabel: 'View organization office',
      iconPath: 'M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2zM9 22V12h6v10',
      onclick: () => goto('/app/office'),
    },
  ];
</script>

<nav class="qa-row {className}" aria-label="Quick actions">
  {#each actions as action (action.label)}
    <button
      class="qa-btn"
      onclick={action.onclick}
      aria-label={action.ariaLabel}
      type="button"
    >
      <svg
        class="qa-icon"
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="1.75"
        stroke-linecap="round"
        stroke-linejoin="round"
        aria-hidden="true"
      >
        <path d={action.iconPath} />
      </svg>
      <span class="qa-label">{action.label}</span>
    </button>
  {/each}
</nav>

<style>
  .qa-row {
    display: flex;
    flex-direction: row;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .qa-btn {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    padding: var(--space-3) var(--space-4);
    min-width: 80px;
    border-radius: var(--radius-md);
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    color: var(--text-secondary);
    cursor: pointer;
    transition:
      background var(--transition-fast) ease,
      border-color var(--transition-fast) ease,
      color var(--transition-fast) ease,
      transform var(--transition-fast) ease;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .qa-btn:hover {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
    transform: scale(1.03);
  }

  .qa-btn:active {
    transform: scale(0.98);
  }

  .qa-btn:focus-visible {
    outline: 2px solid var(--accent-primary);
    outline-offset: 2px;
  }

  .qa-icon {
    flex-shrink: 0;
  }

  .qa-label {
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 500;
    white-space: nowrap;
    line-height: 1;
  }
</style>
