<script lang="ts">
/**
 * /channels/[id] — Channel detail: message list + composer + members panel.
 * Cursor pagination: load older on scroll-to-top (scroll up → fetch before=<oldest>).
 * Hover actions: 6-emoji palette, pin, edit, delete inline.
 * Right PushPanel: members list + add member form.
 * Reuses: ActorAvatar, Composer, renderMarkdown, PushPanel.
 * LOC target: ≤ 400 (script+template). CSS is separate budget.
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { page } from '$app/state';
import { Users } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  addMemberMutation,
  channelMessagesQuery,
  channelQuery,
  unreadCountQuery,
  addReaction,
  deleteMessage,
  editMessage,
  pinMessage,
  sendMessage,
} from '$lib/api/queries/channels.js';
import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
import Composer from '$lib/design/patterns/Composer.svelte';
import PushPanel from '$lib/design/patterns/PushPanel.svelte';
import { renderMarkdown } from '$lib/utils/markdown.js';
import type {
  AddMemberBody,
  Channel,
  ChannelMember,
  ChannelMessage,
  MessagePage,
} from '$lib/domain/channels/types.js';

// ── Route param ──────────────────────────────────────────────────────────────
const channelId = $derived(page.params.id ?? '');

const queryClient = useQueryClient();

// ── Channel detail ───────────────────────────────────────────────────────────
const chOptsStore = writable(
  untrack(() => channelQuery(channelId) as CreateQueryOptions<Channel>)
);
$effect(() => { chOptsStore.set(channelQuery(channelId) as CreateQueryOptions<Channel>); });
const chQ = createQuery<Channel>(chOptsStore);
const channel = $derived($chQ.data as Channel | undefined);

// ── Messages — cursor pagination ─────────────────────────────────────────────
let pages = $state<ChannelMessage[][]>([]);
let hasMore = $state(false);
let oldestCursor = $state<string | undefined>(undefined);
let loadingMore = $state(false);

const msgOptsStore = writable(
  untrack(() => channelMessagesQuery(channelId, { limit: 50 }) as CreateQueryOptions<MessagePage>)
);
$effect(() => { msgOptsStore.set(channelMessagesQuery(channelId, { limit: 50 }) as CreateQueryOptions<MessagePage>); });
const msgQ = createQuery<MessagePage>(msgOptsStore);

$effect(() => {
  if ($msgQ.data) {
    const p = $msgQ.data as MessagePage;
    pages = [p.data];
    hasMore = p.hasMore;
    oldestCursor = p.data[0]?.insertedAt;
  }
});

const allMessages = $derived(pages.flat());

const replyMap = $derived(() => {
  const m = new Map<string, ChannelMessage[]>();
  for (const msg of allMessages) {
    if (msg.replyToId) {
      const b = m.get(msg.replyToId) ?? [];
      b.push(msg);
      m.set(msg.replyToId, b);
    }
  }
  return m;
});

const topLevel = $derived(allMessages.filter((m) => !m.replyToId));

async function loadOlder(): Promise<void> {
  if (!hasMore || loadingMore || !oldestCursor) return;
  loadingMore = true;
  try {
    const result = await queryClient.fetchQuery(
      channelMessagesQuery(channelId, { before: oldestCursor, limit: 50 }) as CreateQueryOptions<MessagePage>
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
  if (scrollEl && scrollEl.scrollTop < 60) void loadOlder();
}

// ── Direct API calls for message mutations (avoids store-per-mutation boilerplate) ──
function invalidateMessages(): void {
  queryClient.invalidateQueries({ queryKey: ['channels', channelId, 'messages'] });
}

async function handleSend(prompt: string): Promise<void> {
  await sendMessage(channelId, { bodyMarkdown: prompt });
  invalidateMessages();
}

async function handleDelete(msgId: string): Promise<void> {
  await deleteMessage(channelId, msgId);
  invalidateMessages();
}

async function handlePin(msgId: string): Promise<void> {
  await pinMessage(channelId, msgId);
}

async function handleReaction(messageId: string, emoji: string): Promise<void> {
  await addReaction(channelId, messageId, { emoji });
  invalidateMessages();
}

// ── Inline edit ───────────────────────────────────────────────────────────────
let hoveredMsgId = $state<string | null>(null);
let editingMsgId = $state<string | null>(null);
let editBody = $state('');

function startEdit(msg: ChannelMessage): void {
  editingMsgId = msg.id;
  editBody = msg.bodyMarkdown;
}

async function submitEdit(msgId: string): Promise<void> {
  if (!editBody.trim()) return;
  await editMessage(channelId, msgId, { bodyMarkdown: editBody });
  editingMsgId = null;
  invalidateMessages();
}

// ── Emoji palette ─────────────────────────────────────────────────────────────
const EMOJI_PALETTE = ['👍', '❤️', '😂', '🎉', '🤔', '👀'] as const;

// ── Members panel ─────────────────────────────────────────────────────────────
let panelOpen = $state(false);
let membersList = $state<ChannelMember[]>([]);
let addActorType = $state<'user' | 'agent'>('user');
let addActorId = $state('');

const addMemberMut = createMutation<ChannelMember, Error, { channelId: string; body: AddMemberBody }>(
  addMemberMutation() as CreateMutationOptions<ChannelMember, Error, { channelId: string; body: AddMemberBody }>
);

function handleAddMember(): void {
  if (!addActorId.trim()) return;
  $addMemberMut.mutate(
    { channelId, body: { actorType: addActorType, actorId: addActorId.trim() } },
    { onSuccess: (m) => { membersList = [...membersList, m]; addActorId = ''; } }
  );
}

// ── Unread count ─────────────────────────────────────────────────────────────
const unreadOptsStore = writable(
  untrack(() => unreadCountQuery(channelId) as CreateQueryOptions<{ count: number }>)
);
$effect(() => { unreadOptsStore.set(unreadCountQuery(channelId) as CreateQueryOptions<{ count: number }>); });
const unreadQ = createQuery<{ count: number }>(unreadOptsStore);
const unreadCount = $derived($unreadQ.data?.count ?? 0);

// ── Helpers ───────────────────────────────────────────────────────────────────
function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function displayName(msg: ChannelMessage): string {
  if (msg.authorType === 'system') return 'System';
  return msg.authorId ?? (msg.authorType === 'agent' ? 'Agent' : 'User');
}
</script>

<div class="cd-shell">
  <header class="cd-topbar">
    <div class="cd-topbar__left">
      <span class="cd-icon" aria-hidden="true">{channel?.icon ?? '#'}</span>
      <div class="cd-topbar__meta">
        <h1 class="cd-title">{channel?.name ?? '…'}</h1>
        {#if channel?.description}<p class="cd-desc">{channel.description}</p>{/if}
      </div>
      {#if unreadCount > 0}
        <span class="cd-unread-chip" aria-label="{unreadCount} unread">{unreadCount} unread</span>
      {/if}
    </div>
    <button
      class="btn-compact btn-compact-ghost"
      onclick={() => { panelOpen = !panelOpen; }}
      aria-label="Toggle members panel"
      aria-expanded={panelOpen}
    >
      <Users size={14} aria-hidden="true" />
      <span class="cd-member-count">{membersList.length}</span>
    </button>
  </header>

  <div class="cd-body">
    <div class="cd-messages-wrap">
      {#if hasMore}
        <div class="cd-load-more">
          <button class="btn-compact btn-compact-ghost" onclick={() => loadOlder()} disabled={loadingMore} aria-label="Load older messages">
            {loadingMore ? 'Loading…' : 'Load older messages'}
          </button>
        </div>
      {/if}

      <div class="cd-messages" bind:this={scrollEl} onscroll={handleScroll} role="log" aria-label="Messages" aria-live="polite">
        {#if $msgQ.isLoading}
          {#each Array(5) as _, i (i)}
            <div class="cd-msg-skeleton" aria-hidden="true">
              <div class="cd-sk cd-sk--avatar"></div>
              <div class="cd-sk-lines"><div class="cd-sk cd-sk--name"></div><div class="cd-sk cd-sk--body"></div></div>
            </div>
          {/each}
        {:else if topLevel.length === 0}
          <div class="cd-empty">No messages yet. Say something!</div>
        {:else}
          {#each topLevel as msg (msg.id)}
            <div
              class="cd-msg"
              class:cd-msg--deleted={Boolean(msg.deletedAt)}
              onmouseenter={() => { hoveredMsgId = msg.id; }}
              onmouseleave={() => { hoveredMsgId = null; }}
              role="article"
              aria-label="Message from {displayName(msg)}"
            >
              <ActorAvatar actor={{ type: msg.authorType === 'user' ? 'human' : 'agent', id: msg.authorId ?? msg.authorType, name: displayName(msg) }} size="sm" />
              <div class="cd-msg__body">
                <div class="cd-msg__meta">
                  <span class="cd-msg__author">{displayName(msg)}</span>
                  <time class="cd-msg__time" datetime={msg.insertedAt}>{formatTime(msg.insertedAt)}</time>
                  {#if msg.editedAt}<span class="cd-msg__edited">(edited)</span>{/if}
                </div>

                {#if editingMsgId === msg.id}
                  <div class="cd-edit-form">
                    <textarea class="cd-edit-input" bind:value={editBody} rows={2} aria-label="Edit message"
                      onkeydown={(e) => { if (e.key === 'Enter' && e.metaKey) { e.preventDefault(); void submitEdit(msg.id); } if (e.key === 'Escape') editingMsgId = null; }}
                    ></textarea>
                    <div class="cd-edit-actions">
                      <button class="btn-pill btn-pill-primary btn-pill-sm" onclick={() => void submitEdit(msg.id)}>Save</button>
                      <button class="btn-compact btn-compact-ghost" onclick={() => { editingMsgId = null; }}>Cancel</button>
                    </div>
                  </div>
                {:else if msg.deletedAt}
                  <p class="cd-msg__deleted-text">[deleted]</p>
                {:else}
                  <div class="cd-msg__text" role="presentation">{@html renderMarkdown(msg.bodyMarkdown)}</div>
                {/if}

                {#if hoveredMsgId === msg.id && !msg.deletedAt}
                  <div class="cd-hover-bar" role="toolbar" aria-label="Message actions">
                    {#each EMOJI_PALETTE as emoji (emoji)}
                      <button class="cd-emoji-btn" onclick={() => void handleReaction(msg.id, emoji)} aria-label="React with {emoji}" title={emoji}>{emoji}</button>
                    {/each}
                    <span class="cd-hover-sep" aria-hidden="true"></span>
                    <button class="btn-compact btn-compact-ghost" onclick={() => void handlePin(msg.id)} aria-label="Pin message" title="Pin">📌</button>
                    <button class="btn-compact btn-compact-ghost" onclick={() => startEdit(msg)} aria-label="Edit message" title="Edit">✏️</button>
                    <button class="btn-compact btn-compact-ghost cd-delete-btn" onclick={() => void handleDelete(msg.id)} aria-label="Delete message" title="Delete">🗑</button>
                  </div>
                {/if}
              </div>
            </div>

            {#each replyMap().get(msg.id) ?? [] as reply (reply.id)}
              <div class="cd-msg cd-msg--reply" role="article" aria-label="Reply from {displayName(reply)}">
                <ActorAvatar actor={{ type: reply.authorType === 'user' ? 'human' : 'agent', id: reply.authorId ?? reply.authorType, name: displayName(reply) }} size="sm" />
                <div class="cd-msg__body">
                  <div class="cd-msg__meta">
                    <span class="cd-msg__author">{displayName(reply)}</span>
                    <time class="cd-msg__time" datetime={reply.insertedAt}>{formatTime(reply.insertedAt)}</time>
                  </div>
                  {#if reply.deletedAt}
                    <p class="cd-msg__deleted-text">[deleted]</p>
                  {:else}
                    <div class="cd-msg__text" role="presentation">{@html renderMarkdown(reply.bodyMarkdown)}</div>
                  {/if}
                </div>
              </div>
            {/each}
          {/each}
        {/if}
      </div>

      <div class="cd-composer-wrap">
        <Composer placeholder="Message #{channel?.name ?? '…'}" onSubmit={(p) => void handleSend(p)} />
      </div>
    </div>

    <PushPanel open={panelOpen} title="Members" onClose={() => { panelOpen = false; }}>
      <div class="cd-panel-body">
        {#if membersList.length === 0}
          <p class="cd-panel-empty">No members loaded yet.</p>
        {:else}
          <ul class="cd-member-list" role="list">
            {#each membersList as member (member.id)}
              <li class="cd-member-row" role="listitem">
                <ActorAvatar actor={{ type: member.actorType === 'user' ? 'human' : 'agent', id: member.actorId, name: member.actorId }} size="sm" />
                <span class="cd-member-id">{member.actorId}</span>
                <span class="cd-member-role">{member.role}</span>
              </li>
            {/each}
          </ul>
        {/if}
        <form class="cd-add-member" onsubmit={(e) => { e.preventDefault(); handleAddMember(); }} aria-label="Add member">
          <p class="cd-panel-section-label">Add member</p>
          <select class="cd-panel-select" bind:value={addActorType} aria-label="Actor type">
            <option value="user">User</option>
            <option value="agent">Agent</option>
          </select>
          <input class="cd-panel-input" type="text" placeholder="ID or slug" bind:value={addActorId} aria-label="Actor ID" />
          <button class="btn-pill btn-pill-primary btn-pill-sm" type="submit" disabled={!addActorId.trim()} aria-label="Add member">Add</button>
        </form>
      </div>
    </PushPanel>
  </div>
</div>

<style>
  .cd-shell { display: flex; flex-direction: column; height: 100%; overflow: hidden; }

  .cd-topbar {
    display: flex; align-items: center; justify-content: space-between;
    padding: var(--space-3) var(--space-5); border-bottom: 1px solid var(--border);
    flex-shrink: 0; gap: var(--space-3);
  }
  .cd-topbar__left { display: flex; align-items: center; gap: var(--space-3); min-width: 0; }
  .cd-icon { font-size: 20px; line-height: 1; flex-shrink: 0; }
  .cd-topbar__meta { min-width: 0; }
  .cd-title {
    margin: 0; font-family: var(--font-sans); font-size: var(--text-lg); font-weight: 600;
    color: var(--fg); letter-spacing: -0.015em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .cd-desc {
    margin: 0; font-family: var(--font-sans); font-size: var(--text-xs); color: var(--fg-subtle);
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .cd-unread-chip {
    display: inline-flex; align-items: center; padding: 2px var(--space-2);
    border-radius: 9999px; background: color-mix(in oklch, var(--cnp-accent) 20%, transparent 80%);
    color: var(--cnp-accent); font-family: var(--font-sans); font-size: 10px; font-weight: 600; flex-shrink: 0;
  }
  .cd-member-count { font-family: var(--font-mono); font-size: var(--text-xs); color: var(--fg-muted); margin-left: 2px; }

  .cd-body { flex: 1; display: flex; overflow: hidden; gap: var(--space-2); padding: 0 var(--space-2) var(--space-2); }
  .cd-messages-wrap { flex: 1; display: flex; flex-direction: column; overflow: hidden; min-width: 0; }

  .cd-load-more { display: flex; justify-content: center; padding: var(--space-2) 0; flex-shrink: 0; }

  .cd-messages {
    flex: 1; overflow-y: auto; display: flex; flex-direction: column;
    gap: var(--space-1); padding: var(--space-3) var(--space-2);
    scrollbar-width: thin; scrollbar-color: var(--border) transparent;
  }

  .cd-empty {
    flex: 1; display: flex; align-items: center; justify-content: center;
    font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg-subtle);
    font-style: italic; padding: var(--space-8) 0;
  }

  .cd-msg {
    display: flex; align-items: flex-start; gap: var(--space-3); padding: var(--space-2);
    border-radius: var(--radius-md); transition: background var(--dur-instant) var(--ease-out); position: relative;
  }
  .cd-msg:hover { background: color-mix(in oklch, var(--fg) 4%, transparent 96%); }
  .cd-msg--reply { margin-left: var(--space-8); border-left: 2px solid var(--border); padding-left: var(--space-4); }
  .cd-msg--deleted { opacity: 0.5; }

  .cd-msg__body { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: var(--space-1); }
  .cd-msg__meta { display: flex; align-items: baseline; gap: var(--space-2); }
  .cd-msg__author { font-family: var(--font-sans); font-size: var(--text-sm); font-weight: 600; color: var(--fg); }
  .cd-msg__time { font-family: var(--font-mono); font-size: var(--text-xs); color: var(--fg-subtle); }
  .cd-msg__edited { font-family: var(--font-sans); font-size: var(--text-xs); color: var(--fg-subtle); font-style: italic; }
  .cd-msg__text { font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg); line-height: 1.5; }
  .cd-msg__deleted-text { margin: 0; font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg-subtle); font-style: italic; }

  .cd-edit-form { display: flex; flex-direction: column; gap: var(--space-2); }
  .cd-edit-input {
    font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg); background: var(--bg-inset);
    border: 1px solid var(--border-strong); border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3); resize: vertical; outline: none; min-height: 52px;
  }
  .cd-edit-actions { display: flex; gap: var(--space-2); }

  .cd-hover-bar {
    display: flex; align-items: center; gap: 2px; position: absolute; top: var(--space-1); right: var(--space-2);
    background: var(--bg-elevated); border: 1px solid var(--border); border-radius: var(--radius-md);
    padding: 2px var(--space-1); box-shadow: 0 2px 8px color-mix(in oklch, var(--fg) 8%, transparent 92%); z-index: 10;
  }
  .cd-emoji-btn {
    display: inline-flex; align-items: center; justify-content: center;
    width: 26px; height: 26px; background: transparent; border: none;
    border-radius: var(--radius-sm); cursor: pointer; font-size: 14px;
    transition: background var(--dur-instant) var(--ease-out);
  }
  .cd-emoji-btn:hover { background: color-mix(in oklch, var(--fg) 8%, transparent 92%); }
  .cd-hover-sep { width: 1px; height: 16px; background: var(--border); margin: 0 2px; }
  .cd-delete-btn { color: var(--signal-error); }

  .cd-composer-wrap { padding: var(--space-3) var(--space-2) var(--space-2); flex-shrink: 0; }

  .cd-panel-body { display: flex; flex-direction: column; gap: var(--space-4); }
  .cd-panel-empty { margin: 0; font-family: var(--font-sans); font-size: var(--text-xs); color: var(--fg-subtle); font-style: italic; }
  .cd-member-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: var(--space-2); }
  .cd-member-row { display: flex; align-items: center; gap: var(--space-2); }
  .cd-member-id { flex: 1; font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cd-member-role { font-family: var(--font-mono); font-size: 10px; color: var(--fg-subtle); flex-shrink: 0; }

  .cd-panel-section-label { margin: 0 0 var(--space-2); font-family: var(--font-sans); font-size: 10px; font-weight: 600; color: var(--fg-subtle); text-transform: uppercase; letter-spacing: 0.06em; }
  .cd-add-member { display: flex; flex-direction: column; gap: var(--space-2); }
  .cd-panel-select, .cd-panel-input {
    font-family: var(--font-sans); font-size: var(--text-sm); color: var(--fg); background: var(--bg-inset);
    border: 1px solid var(--border); border-radius: var(--radius-md); padding: var(--space-2) var(--space-3);
    outline: none; transition: border-color var(--dur-instant) var(--ease-out);
  }
  .cd-panel-input:focus { border-color: var(--border-strong); }

  .cd-msg-skeleton { display: flex; align-items: flex-start; gap: var(--space-3); padding: var(--space-2); }
  .cd-sk { animation: cd-pulse 1.5s ease-in-out infinite; background: var(--border); border-radius: var(--radius-sm); }
  .cd-sk--avatar { width: 28px; height: 28px; border-radius: 50%; flex-shrink: 0; }
  .cd-sk-lines { display: flex; flex-direction: column; gap: 6px; flex: 1; }
  .cd-sk--name { height: 11px; width: 25%; }
  .cd-sk--body { height: 14px; width: 65%; }

  @keyframes cd-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.65; }
  }
</style>
