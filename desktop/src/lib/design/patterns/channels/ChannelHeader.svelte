<script lang="ts">
/**
 * ChannelHeader — right-pane top bar for a channel.
 * CSS prefix: ch2- (ChannelHeader)
 * LOC target: ≤100
 */
import { Hash, Lock, Settings, Users } from 'lucide-svelte';
import type { Channel } from '$lib/domain/channels/types.js';

interface Props {
  channel: Channel;
  memberCount?: number;
  onSettings?: () => void;
  onMembers?: () => void;
}

let { channel, memberCount = 0, onSettings, onMembers }: Props = $props();
</script>

<header class="ch2-header" aria-label="Channel {channel.name}">
  <div class="ch2-left">
    <span class="ch2-icon" aria-hidden="true">
      {#if channel.visibility === 'private'}
        <Lock size={14} />
      {:else}
        <Hash size={14} />
      {/if}
    </span>
    <div class="ch2-meta">
      <h1 class="ch2-name">{channel.name}</h1>
      {#if channel.description}
        <p class="ch2-desc">{channel.description}</p>
      {/if}
    </div>
  </div>

  <div class="ch2-actions">
    {#if memberCount > 0}
      <button
        class="ch2-action-btn"
        onclick={onMembers}
        aria-label="{memberCount} members"
        title="Members"
      >
        <Users size={13} aria-hidden="true" />
        <span class="ch2-member-count">{memberCount}</span>
      </button>
    {/if}
    {#if onSettings}
      <button
        class="ch2-action-btn"
        onclick={onSettings}
        aria-label="Channel settings"
        title="Settings"
      >
        <Settings size={13} aria-hidden="true" />
      </button>
    {/if}
  </div>
</header>

<style>
  .ch2-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 var(--space-4);
    height: 44px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-3);
  }

  .ch2-left {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    min-width: 0;
  }

  .ch2-icon {
    display: inline-flex;
    align-items: center;
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  .ch2-meta {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
    min-width: 0;
  }

  .ch2-name {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ch2-desc {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ch2-actions {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    flex-shrink: 0;
  }

  .ch2-action-btn {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    padding: 4px var(--space-2);
    cursor: pointer;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    transition: color var(--dur-instant) var(--ease-out), background var(--dur-instant) var(--ease-out);
  }

  .ch2-action-btn:hover {
    color: var(--fg);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .ch2-member-count {
    font-size: var(--text-xs);
  }
</style>
