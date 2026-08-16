<script lang="ts">
  /**
   * MessageRow — single message in a channel thread.
   * Groups consecutive same-sender messages (no repeat avatar).
   * CSS prefix: mr- (MessageRow)
   * LOC target: ≤120
   */
  import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
  import { renderMarkdown } from '$lib/utils/markdown.js';
  import type { ChannelMessage } from '$lib/domain/channels/types.js';

  interface Props {
    message: ChannelMessage;
    /** True when this message immediately follows one from the same author. */
    grouped?: boolean;
    isDeleted?: boolean;
  }

  let { message, grouped = false, isDeleted = false }: Props = $props();

  function displayName(msg: ChannelMessage): string {
    if (msg.authorType === 'system') return 'System';
    return msg.authorId ?? (msg.authorType === 'agent' ? 'Agent' : 'User');
  }

  function formatTime(iso: string): string {
    return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
</script>

<div
  class="mr-row"
  class:mr-row--grouped={grouped}
  class:mr-row--deleted={isDeleted}
  role="article"
  aria-label="Message from {displayName(message)}"
>
  {#if grouped}
    <!-- Grouped: show timestamp on hover instead of avatar -->
    <div class="mr-gutter" aria-hidden="true">
      <time class="mr-group-time" datetime={message.insertedAt}>{formatTime(message.insertedAt)}</time>
    </div>
  {:else}
    <div class="mr-avatar">
      <ActorAvatar
        actor={{
          type: message.authorType === 'user' ? 'human' : 'agent',
          id: message.authorId ?? message.authorType,
          name: displayName(message),
        }}
        size="sm"
      />
    </div>
  {/if}

  <div class="mr-body">
    {#if !grouped}
      <div class="mr-meta">
        <span class="mr-author">{displayName(message)}</span>
        <time class="mr-time" datetime={message.insertedAt}>{formatTime(message.insertedAt)}</time>
        {#if message.editedAt}
          <span class="mr-edited" aria-label="Edited">(edited)</span>
        {/if}
      </div>
    {/if}

    {#if isDeleted}
      <p class="mr-deleted">[deleted]</p>
    {:else}
      <div class="mr-content" role="presentation">
        {@html renderMarkdown(message.bodyMarkdown)}
      </div>
    {/if}
  </div>
</div>

<style>
  .mr-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: 4px var(--space-3);
    border-radius: var(--radius-sm);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .mr-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, transparent);
  }

  .mr-row--grouped {
    padding-top: 1px;
    padding-bottom: 1px;
  }

  .mr-row--deleted {
    opacity: 0.45;
  }

  /* Left column — fixed 28px wide to align with avatar */
  .mr-avatar {
    width: 28px;
    flex-shrink: 0;
    padding-top: 2px;
  }

  .mr-gutter {
    width: 28px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding-right: 0;
    min-height: 20px;
  }

  .mr-group-time {
    font-family: var(--font-mono);
    font-size: 9px;
    color: var(--fg-subtle);
    opacity: 0;
    white-space: nowrap;
    transition: opacity var(--dur-instant) var(--ease-out);
  }

  .mr-row:hover .mr-group-time {
    opacity: 1;
  }

  .mr-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .mr-meta {
    display: flex;
    align-items: baseline;
    gap: var(--space-2);
  }

  .mr-author {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    line-height: 1;
  }

  .mr-time {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .mr-edited {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    font-style: italic;
  }

  .mr-content {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg);
    line-height: 1.5;
  }

  .mr-deleted {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
