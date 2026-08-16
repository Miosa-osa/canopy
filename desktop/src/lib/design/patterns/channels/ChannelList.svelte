<script lang="ts">
  /**
   * ChannelList — left pane channel navigator.
   * CSS prefix: cl- (ChannelList)
   * LOC target: ≤180
   */
  import { Hash, Lock, Plus, Search } from 'lucide-svelte';
  import type { Channel } from '$lib/domain/channels/types.js';

  interface Props {
    channels: Channel[];
    activeId?: string;
    isLoading?: boolean;
    onSelect: (channel: Channel) => void;
    onNew: () => void;
  }

  let { channels, activeId, isLoading = false, onSelect, onNew }: Props = $props();

  let filterText = $state('');

  const filtered = $derived(
    filterText.trim()
      ? channels.filter((c) =>
          c.name.toLowerCase().includes(filterText.trim().toLowerCase()) ||
          c.slug.toLowerCase().includes(filterText.trim().toLowerCase()),
        )
      : channels,
  );

  const pinned = $derived(filtered.filter((c) => c.color === 'pinned'));
  const rest = $derived(filtered.filter((c) => c.color !== 'pinned'));
</script>

<div class="cl-shell">
  <!-- Search -->
  <div class="cl-search-row">
    <Search size={11} class="cl-search-icon" aria-hidden="true" />
    <input
      class="cl-search"
      type="search"
      placeholder="Filter channels…"
      bind:value={filterText}
      aria-label="Filter channels"
      spellcheck={false}
      autocomplete="off"
    />
  </div>

  <!-- Channel groups -->
  <nav class="cl-nav" aria-label="Channels">
    {#if isLoading}
      {#each { length: 6 } as _, i (i)}
        <div class="cl-skeleton" aria-hidden="true">
          <div class="cl-sk cl-sk--icon"></div>
          <div class="cl-sk cl-sk--name" style="width: {50 + (i % 3) * 15}%"></div>
        </div>
      {/each}
    {:else}
      {#if pinned.length > 0}
        <p class="cl-group-label">Pinned</p>
        {#each pinned as ch (ch.id)}
          {@render channelRow(ch)}
        {/each}
      {/if}

      <p class="cl-group-label">All channels</p>
      {#if rest.length === 0}
        <p class="cl-empty">
          {filterText ? 'No match' : 'No channels yet'}
        </p>
      {:else}
        {#each rest as ch (ch.id)}
          {@render channelRow(ch)}
        {/each}
      {/if}
    {/if}
  </nav>

  <!-- New channel -->
  <div class="cl-footer">
    <button class="cl-new-btn" onclick={onNew} aria-label="Create new channel">
      <Plus size={12} aria-hidden="true" />
      New channel
    </button>
  </div>
</div>

{#snippet channelRow(ch: Channel)}
  <button
    class="cl-row"
    class:cl-row--active={ch.id === activeId}
    onclick={() => onSelect(ch)}
    aria-label="Open channel {ch.name}"
    aria-current={ch.id === activeId ? 'page' : undefined}
  >
    <span class="cl-row__icon" aria-hidden="true">
      {#if ch.visibility === 'private'}
        <Lock size={11} />
      {:else}
        <Hash size={11} />
      {/if}
    </span>
    <span class="cl-row__name">{ch.name}</span>
  </button>
{/snippet}

<style>
  .cl-shell {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .cl-search-row {
    position: relative;
    display: flex;
    align-items: center;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  :global(.cl-search-icon) {
    position: absolute;
    left: calc(var(--space-3) + 8px);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .cl-search {
    width: 100%;
    background: transparent;
    border: none;
    outline: none;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg);
    padding: 4px 6px 4px 22px;
  }

  .cl-search::placeholder {
    color: var(--fg-subtle);
  }

  .cl-nav {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding: var(--space-2) var(--space-2) var(--space-1);
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .cl-group-label {
    margin: var(--space-2) 0 2px var(--space-2);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .cl-row {
    display: flex;
    align-items: center;
    gap: 6px;
    width: 100%;
    padding: 0 var(--space-2);
    height: 28px;
    background: transparent;
    border: none;
    border-left: 2px solid transparent;
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
    cursor: pointer;
    text-align: left;
    color: var(--fg-muted);
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .cl-row:hover {
    background: color-mix(in oklch, var(--fg) 5%, transparent);
    color: var(--fg);
  }

  .cl-row--active {
    border-left-color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 8%, transparent);
    color: var(--fg);
    font-weight: 500;
  }

  .cl-row__icon {
    display: inline-flex;
    align-items: center;
    flex-shrink: 0;
    color: var(--fg-subtle);
  }

  .cl-row--active .cl-row__icon {
    color: var(--cnp-accent);
  }

  .cl-row__name {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex: 1;
  }

  .cl-empty {
    margin: var(--space-2) var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .cl-footer {
    flex-shrink: 0;
    border-top: 1px solid var(--border);
    padding: var(--space-2) var(--space-3);
  }

  .cl-new-btn {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    background: transparent;
    border: none;
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    padding: 4px var(--space-1);
    border-radius: var(--radius-sm);
    width: 100%;
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .cl-new-btn:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 5%, transparent);
  }

  /* Skeletons */
  .cl-skeleton {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 var(--space-2);
  }

  .cl-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: cl-pulse 1.5s ease-in-out infinite;
  }

  .cl-sk--icon {
    width: 11px;
    height: 11px;
    flex-shrink: 0;
  }

  .cl-sk--name {
    height: 10px;
  }

  @keyframes cl-pulse {
    0%,
    100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
