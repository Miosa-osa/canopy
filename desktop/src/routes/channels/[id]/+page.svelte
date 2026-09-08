<script lang="ts">
/**
 * /channels/[id] — Two-pane: channel list (left) + message thread (right).
 * CSS prefix: cv- (ChannelView)
 * LOC target: ≤200
 */
import { type CreateQueryOptions, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  channelMembersQuery,
  channelMessagesQuery,
  channelQuery,
  channelsQuery,
  deleteMessage,
  sendMessage,
} from '$lib/api/queries/channels.js';
import ChannelHeader from '$lib/design/patterns/channels/ChannelHeader.svelte';
import ChannelList from '$lib/design/patterns/channels/ChannelList.svelte';
import ChannelSettingsPanel from '$lib/design/patterns/channels/ChannelSettingsPanel.svelte';
import MessageComposer from '$lib/design/patterns/channels/MessageComposer.svelte';
import MessageRow from '$lib/design/patterns/channels/MessageRow.svelte';
import type {
  Channel,
  ChannelMember,
  ChannelMessage,
  MessagePage,
} from '$lib/domain/channels/types.js';

const queryClient = useQueryClient();
const channelId = $derived(page.params.id ?? '');

// ── Settings panel state ──────────────────────────────────────────────────────
let settingsOpen = $state(false);

// ── All channels (for left pane) ─────────────────────────────────────────────
const allChStore = writable(untrack(() => channelsQuery() as CreateQueryOptions<Channel[]>));
const allChQ = createQuery<Channel[]>(allChStore);
const allChannels = $derived(($allChQ.data ?? []) as Channel[]);

// ── Active channel detail ─────────────────────────────────────────────────────
const chStore = writable(untrack(() => channelQuery(channelId) as CreateQueryOptions<Channel>));
$effect(() => {
  chStore.set(channelQuery(channelId) as CreateQueryOptions<Channel>);
});
const chQ = createQuery<Channel>(chStore);
const channel = $derived($chQ.data as Channel | undefined);

// ── Members (for header count) ────────────────────────────────────────────────
const membersStore = writable(
  untrack(() => channelMembersQuery(channelId) as CreateQueryOptions<ChannelMember[]>)
);
$effect(() => {
  membersStore.set(channelMembersQuery(channelId) as CreateQueryOptions<ChannelMember[]>);
});
const membersQ = createQuery<ChannelMember[]>(membersStore);
const memberCount = $derived(($membersQ.data ?? []).length);

// ── Messages ──────────────────────────────────────────────────────────────────
let pages = $state<ChannelMessage[][]>([]);
let hasMore = $state(false);
let oldestCursor = $state<string | undefined>(undefined);
let loadingMore = $state(false);

const msgStore = writable(
  untrack(() => channelMessagesQuery(channelId, { limit: 50 }) as CreateQueryOptions<MessagePage>)
);
$effect(() => {
  msgStore.set(channelMessagesQuery(channelId, { limit: 50 }) as CreateQueryOptions<MessagePage>);
});
const msgQ = createQuery<MessagePage>(msgStore);

$effect(() => {
  if ($msgQ.data) {
    const p = $msgQ.data as MessagePage;
    pages = [p.data];
    hasMore = p.hasMore;
    oldestCursor = p.data[0]?.insertedAt;
  }
});

const messages = $derived(pages.flat().filter((m) => !m.replyToId));

async function loadOlder(): Promise<void> {
  if (!hasMore || loadingMore || !oldestCursor) return;
  loadingMore = true;
  try {
    const result = await queryClient.fetchQuery(
      channelMessagesQuery(channelId, {
        before: oldestCursor,
        limit: 50,
      }) as CreateQueryOptions<MessagePage>
    );
    const p = result as MessagePage;
    pages = [p.data, ...pages];
    hasMore = p.hasMore;
    if (p.data[0]) oldestCursor = p.data[0].insertedAt;
  } finally {
    loadingMore = false;
  }
}

let scrollEl = $state<HTMLDivElement | null>(null);

function handleScroll(): void {
  if (scrollEl && scrollEl.scrollTop < 80) void loadOlder();
}

function invalidateMessages(): void {
  queryClient.invalidateQueries({ queryKey: ['channels', channelId, 'messages'] });
}

function handleSettingsUpdated(): void {
  queryClient.invalidateQueries({ queryKey: ['channels', channelId] });
  queryClient.invalidateQueries({ queryKey: ['channels'] });
  queryClient.invalidateQueries({ queryKey: ['channels', channelId, 'members'] });
}

function handleSettingsDeleted(): void {
  void goto('/channels');
}

async function handleSend(body: string): Promise<void> {
  await sendMessage(channelId, { bodyMarkdown: body });
  invalidateMessages();
}

async function handleDelete(msgId: string): Promise<void> {
  await deleteMessage(channelId, msgId);
  invalidateMessages();
}

function handleSelectChannel(ch: Channel): void {
  void goto(`/channels/${ch.id}`);
}

// Detect grouped messages (same author, consecutive)
function isGrouped(msg: ChannelMessage, idx: number): boolean {
  if (idx === 0) return false;
  const prev = messages[idx - 1];
  return (
    prev.authorId === msg.authorId &&
    prev.authorType === msg.authorType &&
    new Date(msg.insertedAt).getTime() - new Date(prev.insertedAt).getTime() < 5 * 60 * 1000
  );
}
</script>

<div class="cv-shell">
  <!-- Left: channel navigator -->
  <aside class="cv-sidebar" aria-label="Channels">
    <ChannelList
      channels={allChannels}
      activeId={channelId}
      isLoading={$allChQ.isLoading}
      onSelect={handleSelectChannel}
      onNew={() => goto('/channels')}
    />
  </aside>

  <!-- Right: message pane -->
  <div class="cv-pane">
    {#if channel}
      <ChannelHeader
        {channel}
        {memberCount}
        onSettings={() => (settingsOpen = true)}
        onMembers={() => (settingsOpen = true)}
      />
    {:else}
      <div class="cv-header-skeleton" aria-hidden="true"></div>
    {/if}

    <!-- Load older button -->
    {#if hasMore}
      <div class="cv-load-more">
        <button
          class="btn-compact btn-compact-ghost"
          onclick={() => void loadOlder()}
          disabled={loadingMore}
          aria-label="Load older messages"
        >
          {loadingMore ? 'Loading…' : 'Load older'}
        </button>
      </div>
    {/if}

    <!-- Message list -->
    <div
      class="cv-messages"
      bind:this={scrollEl}
      onscroll={handleScroll}
      role="log"
      aria-label="Messages"
      aria-live="polite"
    >
      {#if $msgQ.isLoading}
        {#each { length: 5 } as _, i (i)}
          <div class="cv-msg-skeleton" aria-hidden="true">
            <div class="cv-sk cv-sk--avatar"></div>
            <div class="cv-sk-lines">
              <div class="cv-sk cv-sk--name"></div>
              <div class="cv-sk cv-sk--body"></div>
            </div>
          </div>
        {/each}
      {:else if messages.length === 0}
        <div class="cv-empty">No messages yet. Start the conversation.</div>
      {:else}
        {#each messages as msg, i (msg.id)}
          <MessageRow
            message={msg}
            grouped={isGrouped(msg, i)}
            isDeleted={Boolean(msg.deletedAt)}
          />
        {/each}
      {/if}
    </div>

    <!-- Composer -->
    <MessageComposer
      placeholder="Message #{channel?.name ?? '…'}"
      onSend={handleSend}
    />
  </div>
</div>

{#if channel}
  <ChannelSettingsPanel
    {channel}
    open={settingsOpen}
    onClose={() => (settingsOpen = false)}
    onUpdated={handleSettingsUpdated}
    onDeleted={handleSettingsDeleted}
  />
{/if}

<style>
  .cv-shell {
    display: flex;
    height: 100%;
    overflow: hidden;
  }

  /* Left sidebar */
  .cv-sidebar {
    width: 240px;
    flex-shrink: 0;
    border-right: 1px solid var(--border);
    background: var(--bg-inset);
  }

  /* Right pane */
  .cv-pane {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
    background: var(--bg);
  }

  .cv-header-skeleton {
    height: 44px;
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: var(--bg-inset);
    animation: cv-pulse 1.5s ease-in-out infinite;
  }

  .cv-load-more {
    display: flex;
    justify-content: center;
    padding: var(--space-2) 0;
    flex-shrink: 0;
    border-bottom: 1px solid var(--border);
  }

  .cv-messages {
    flex: 1;
    overflow-y: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding: var(--space-2) 0;
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .cv-empty {
    display: flex;
    flex: 1;
    align-items: center;
    justify-content: center;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
    padding: var(--space-8);
  }

  /* Skeletons */
  .cv-msg-skeleton {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
  }

  .cv-sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: cv-pulse 1.5s ease-in-out infinite;
  }

  .cv-sk--avatar {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .cv-sk-lines {
    display: flex;
    flex-direction: column;
    gap: 6px;
    flex: 1;
    padding-top: 2px;
  }

  .cv-sk--name {
    height: 11px;
    width: 22%;
  }

  .cv-sk--body {
    height: 14px;
    width: 60%;
  }

  @keyframes cv-pulse {
    0%,
    100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
