<!-- src/routes/app/chat/+page.svelte -->
<!-- Enterprise chat interface for direct agent conversations -->
<script lang="ts">
  import { tick } from 'svelte';
  import { agentsStore } from '$lib/stores/agents.svelte';
  import { conversationsStore } from '$lib/stores/conversations.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import type { Conversation } from '$api/types';

  // ── Local state ──────────────────────────────────────────────────────────
  let messageInput = $state('');
  let messageListEl = $state<HTMLElement | null>(null);
  let textareaEl = $state<HTMLTextAreaElement | null>(null);
  let showNewChatPanel = $state(false);
  let selectedNewAgentId = $state('');

  // ── Derived ──────────────────────────────────────────────────────────────
  let activeConv = $derived(conversationsStore.activeConversation);
  let messages = $derived(conversationsStore.messages);
  let sending = $derived(conversationsStore.sending);

  // Sorted conversations: active first, then archived
  let sortedConversations = $derived(
    [...conversationsStore.conversations].sort((a, b) => {
      if (a.status !== b.status) {
        return a.status === 'active' ? -1 : 1;
      }
      const aTime = a.last_message_at ?? a.inserted_at;
      const bTime = b.last_message_at ?? b.inserted_at;
      return new Date(bTime).getTime() - new Date(aTime).getTime();
    })
  );

  // ── Lifecycle ────────────────────────────────────────────────────────────
  $effect(() => {
    const wsId = workspaceStore.activeWorkspaceId ?? undefined;
    conversationsStore.fetchConversations(wsId).then(() => {
      if (conversationsStore.conversations.length > 0) {
        const first = conversationsStore.conversations[0];
        void conversationsStore.fetchConversation(first.id);
      }
    });
  });

  // Auto-scroll when messages change
  $effect(() => {
    void messages;
    void sending;
    tick().then(() => {
      if (messageListEl) {
        messageListEl.scrollTop = messageListEl.scrollHeight;
      }
    });
  });

  // Auto-resize textarea
  function handleTextareaInput() {
    if (!textareaEl) return;
    textareaEl.style.height = 'auto';
    textareaEl.style.height = Math.min(textareaEl.scrollHeight, 160) + 'px';
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  async function selectConversation(conv: Conversation) {
    conversationsStore.setActiveConversation(conv);
    await conversationsStore.fetchConversation(conv.id);
  }

  async function handleSend() {
    const content = messageInput.trim();
    if (!content || !activeConv || sending) return;
    messageInput = '';
    if (textareaEl) {
      textareaEl.style.height = 'auto';
    }
    await conversationsStore.sendMessage(activeConv.id, content);
  }

  function handleKeyDown(e: KeyboardEvent) {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault();
      void handleSend();
    }
  }

  async function handleNewChat() {
    if (!selectedNewAgentId) return;
    const agent = agentsStore.agents.find(a => a.id === selectedNewAgentId);
    const title = agent ? `Chat with ${agent.display_name || agent.name}` : undefined;
    const conv = await conversationsStore.createConversation(selectedNewAgentId, title);
    if (conv) {
      showNewChatPanel = false;
      selectedNewAgentId = '';
    }
  }

  async function handleArchive() {
    if (!activeConv) return;
    await conversationsStore.archiveConversation(activeConv.id);
  }

  // ── Formatting helpers ───────────────────────────────────────────────────
  function formatTime(iso: string): string {
    const d = new Date(iso);
    const now = new Date();
    const diffMs = now.getTime() - d.getTime();
    const diffMins = Math.floor(diffMs / 60_000);
    const diffHours = Math.floor(diffMs / 3_600_000);
    const diffDays = Math.floor(diffMs / 86_400_000);

    if (diffMins < 1) return 'just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays < 7) return `${diffDays}d ago`;
    return d.toLocaleDateString();
  }

  function formatTimestamp(iso: string): string {
    return new Date(iso).toLocaleTimeString(undefined, {
      hour: '2-digit',
      minute: '2-digit',
    });
  }

  function getLastMessagePreview(conv: Conversation): string {
    if (conv.message_count === 0) return 'No messages yet';
    return `${conv.message_count} message${conv.message_count !== 1 ? 's' : ''}`;
  }

  function roleLabel(role: string): string {
    if (role === 'agent') return 'Agent';
    if (role === 'user') return 'You';
    return 'System';
  }
</script>

<div class="ch-root">
  <!-- LEFT PANEL: Conversation list -->
  <aside class="ch-sidebar">
    <div class="ch-sidebar-header">
      <h2 class="ch-sidebar-title">Chat</h2>
      <button
        class="ch-new-btn"
        onclick={() => (showNewChatPanel = !showNewChatPanel)}
        aria-label="New conversation"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M12 5v14M5 12h14" />
        </svg>
        New Chat
      </button>
    </div>

    <!-- New chat panel -->
    {#if showNewChatPanel}
      <div class="ch-new-panel">
        <label class="ch-new-label" for="ch-agent-select">Select agent</label>
        <select
          id="ch-agent-select"
          class="ch-new-select"
          bind:value={selectedNewAgentId}
        >
          <option value="">Choose an agent...</option>
          {#each agentsStore.agents as agent (agent.id)}
            <option value={agent.id}>{agent.avatar_emoji} {agent.display_name || agent.name}</option>
          {/each}
        </select>
        <div class="ch-new-actions">
          <button
            class="ch-btn ch-btn--primary"
            onclick={handleNewChat}
            disabled={!selectedNewAgentId}
          >
            Start
          </button>
          <button
            class="ch-btn ch-btn--ghost"
            onclick={() => { showNewChatPanel = false; selectedNewAgentId = ''; }}
          >
            Cancel
          </button>
        </div>
      </div>
    {/if}

    <!-- Conversation list -->
    <nav class="ch-conv-list" aria-label="Conversations">
      {#if conversationsStore.loading && conversationsStore.conversations.length === 0}
        <div class="ch-empty">Loading...</div>
      {:else if conversationsStore.conversations.length === 0}
        <div class="ch-empty">No conversations yet. Start a new chat.</div>
      {:else}
        {#each sortedConversations as conv (conv.id)}
          <button
            class="ch-conv-item {activeConv?.id === conv.id ? 'ch-conv-item--active' : ''} {conv.status === 'archived' ? 'ch-conv-item--archived' : ''}"
            onclick={() => selectConversation(conv)}
          >
            <div class="ch-conv-avatar" aria-hidden="true">
              {conv.agent_avatar ?? '🤖'}
            </div>
            <div class="ch-conv-body">
              <div class="ch-conv-row">
                <span class="ch-conv-name">{conv.title ?? conv.agent_name ?? 'Conversation'}</span>
                <span class="ch-conv-time">{formatTime(conv.last_message_at ?? conv.inserted_at)}</span>
              </div>
              <div class="ch-conv-row">
                <span class="ch-conv-preview">{getLastMessagePreview(conv)}</span>
                {#if conv.status === 'archived'}
                  <span class="ch-conv-badge">archived</span>
                {/if}
              </div>
            </div>
          </button>
        {/each}
      {/if}
    </nav>
  </aside>

  <!-- RIGHT PANEL: Chat area -->
  <main class="ch-main" aria-label="Chat area">
    {#if !activeConv}
      <div class="ch-empty-state">
        <div class="ch-empty-icon" aria-hidden="true">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z" />
          </svg>
        </div>
        <p class="ch-empty-text">Select a conversation or start a new chat</p>
      </div>
    {:else}
      <!-- Chat header -->
      <header class="ch-chat-header">
        <div class="ch-chat-agent">
          <span class="ch-chat-agent-avatar" aria-hidden="true">
            {activeConv.agent_avatar ?? '🤖'}
          </span>
          <div class="ch-chat-agent-info">
            <span class="ch-chat-agent-name">{activeConv.agent_name ?? 'Agent'}</span>
            <span class="ch-chat-agent-status {activeConv.status === 'active' ? 'ch-status--active' : 'ch-status--archived'}">
              {activeConv.status}
            </span>
          </div>
        </div>
        <div class="ch-chat-header-actions">
          {#if activeConv.status === 'active'}
            <button
              class="ch-btn ch-btn--ghost ch-btn--sm"
              onclick={handleArchive}
              aria-label="Archive conversation"
              title="Archive"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5m8.25 3v6.75m0 0l-3-3m3 3l3-3M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
              </svg>
              Archive
            </button>
          {/if}
        </div>
      </header>

      <!-- Message list -->
      <div
        class="ch-messages"
        bind:this={messageListEl}
        aria-label="Message history"
        aria-live="polite"
      >
        {#if messages.length === 0}
          <div class="ch-messages-empty">
            No messages yet. Say hello!
          </div>
        {:else}
          {#each messages as msg (msg.id)}
            {#if msg.role === 'system'}
              <!-- Tool result / system — centered gray pill -->
              <div class="ch-msg ch-msg--system">
                <span class="ch-msg-system-label">tool result</span>
                <pre class="ch-msg-system-content">{msg.content}</pre>
              </div>
            {:else if msg.role === 'user'}
              <!-- User — right-aligned blue -->
              <div class="ch-msg ch-msg--user">
                <div class="ch-msg-bubble ch-msg-bubble--user">
                  <p class="ch-msg-text">{msg.content}</p>
                </div>
                <span class="ch-msg-meta">{formatTimestamp(msg.inserted_at)}</span>
              </div>
            {:else}
              <!-- Agent — left-aligned dark -->
              <div class="ch-msg ch-msg--agent">
                <div class="ch-msg-agent-header">
                  <span class="ch-msg-avatar" aria-hidden="true">{activeConv.agent_avatar ?? '🤖'}</span>
                  <span class="ch-msg-agent-name">{roleLabel(msg.role)}</span>
                  <span class="ch-msg-meta">{formatTimestamp(msg.inserted_at)}</span>
                </div>
                <div class="ch-msg-bubble ch-msg-bubble--agent">
                  <p class="ch-msg-text">{msg.content}</p>
                </div>
              </div>
            {/if}
          {/each}

          <!-- Thinking indicator -->
          {#if sending}
            <div class="ch-msg ch-msg--agent">
              <div class="ch-msg-agent-header">
                <span class="ch-msg-avatar" aria-hidden="true">{activeConv.agent_avatar ?? '🤖'}</span>
                <span class="ch-msg-agent-name">{activeConv.agent_name ?? 'Agent'}</span>
              </div>
              <div class="ch-msg-bubble ch-msg-bubble--agent ch-msg-bubble--thinking">
                <span class="ch-thinking-dot"></span>
                <span class="ch-thinking-dot"></span>
                <span class="ch-thinking-dot"></span>
              </div>
            </div>
          {/if}
        {/if}
      </div>

      <!-- Input bar -->
      <div class="ch-input-bar" class:ch-input-bar--disabled={activeConv.status !== 'active'}>
        {#if activeConv.status !== 'active'}
          <p class="ch-archived-notice">This conversation is archived and cannot receive new messages.</p>
        {:else}
          <div class="ch-input-wrap">
            <textarea
              bind:this={textareaEl}
              class="ch-textarea"
              bind:value={messageInput}
              placeholder="Message {activeConv.agent_name ?? 'agent'}... (Cmd+Enter to send)"
              rows="1"
              disabled={sending}
              onkeydown={handleKeyDown}
              oninput={handleTextareaInput}
              aria-label="Message input"
            ></textarea>
            <button
              class="ch-send-btn"
              onclick={handleSend}
              disabled={sending || !messageInput.trim()}
              aria-label="Send message"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" />
              </svg>
            </button>
          </div>
          <p class="ch-input-hint">Cmd+Enter to send</p>
        {/if}
      </div>
    {/if}
  </main>
</div>

<style>
  /* ── Root layout ─────────────────────────────────────────────────────────── */
  .ch-root {
    display: flex;
    height: 100%;
    overflow: hidden;
    background: var(--surface-0, #0f0f10);
    color: var(--text-primary, #e8e8ed);
    font-family: var(--font-sans, system-ui, sans-serif);
  }

  /* ── Left sidebar ────────────────────────────────────────────────────────── */
  .ch-sidebar {
    width: 280px;
    flex-shrink: 0;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border-subtle, rgba(255,255,255,0.06));
    overflow: hidden;
  }

  .ch-sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 16px 12px;
    border-bottom: 1px solid var(--border-subtle, rgba(255,255,255,0.06));
    flex-shrink: 0;
  }

  .ch-sidebar-title {
    font-size: 13px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--text-secondary, rgba(255,255,255,0.45));
    margin: 0;
  }

  .ch-new-btn {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 4px 10px;
    border-radius: 6px;
    border: 1px solid var(--border-subtle, rgba(255,255,255,0.1));
    background: transparent;
    color: var(--text-secondary, rgba(255,255,255,0.55));
    font-size: 12px;
    cursor: pointer;
    transition: color 0.15s, background 0.15s;
  }
  .ch-new-btn:hover {
    color: var(--text-primary, #e8e8ed);
    background: rgba(255,255,255,0.06);
  }

  /* ── New chat panel ──────────────────────────────────────────────────────── */
  .ch-new-panel {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-subtle, rgba(255,255,255,0.06));
    background: rgba(255,255,255,0.03);
    flex-shrink: 0;
  }

  .ch-new-label {
    display: block;
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary, rgba(255,255,255,0.45));
    margin-bottom: 6px;
    letter-spacing: 0.03em;
  }

  .ch-new-select {
    width: 100%;
    padding: 7px 10px;
    border-radius: 6px;
    border: 1px solid var(--border-subtle, rgba(255,255,255,0.12));
    background: var(--surface-1, #1a1a1e);
    color: var(--text-primary, #e8e8ed);
    font-size: 13px;
    outline: none;
    cursor: pointer;
  }

  .ch-new-actions {
    display: flex;
    gap: 8px;
    margin-top: 10px;
  }

  /* ── Conversation list ───────────────────────────────────────────────────── */
  .ch-conv-list {
    flex: 1;
    overflow-y: auto;
    padding: 4px 0;
  }

  .ch-conv-item {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    width: 100%;
    padding: 10px 14px;
    border: none;
    background: transparent;
    color: var(--text-primary, #e8e8ed);
    cursor: pointer;
    text-align: left;
    transition: background 0.12s;
    border-radius: 0;
  }
  .ch-conv-item:hover {
    background: rgba(255,255,255,0.04);
  }
  .ch-conv-item--active {
    background: rgba(99,102,241,0.12);
    border-left: 2px solid var(--accent, #6366f1);
  }
  .ch-conv-item--active:hover {
    background: rgba(99,102,241,0.16);
  }
  .ch-conv-item--archived {
    opacity: 0.55;
  }

  .ch-conv-avatar {
    font-size: 18px;
    line-height: 1;
    flex-shrink: 0;
    padding-top: 1px;
  }

  .ch-conv-body {
    flex: 1;
    min-width: 0;
  }

  .ch-conv-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
  }

  .ch-conv-name {
    font-size: 13px;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ch-conv-time {
    font-size: 11px;
    color: var(--text-secondary, rgba(255,255,255,0.35));
    flex-shrink: 0;
  }

  .ch-conv-preview {
    font-size: 12px;
    color: var(--text-secondary, rgba(255,255,255,0.4));
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .ch-conv-badge {
    font-size: 10px;
    padding: 1px 6px;
    border-radius: 10px;
    background: rgba(255,255,255,0.07);
    color: var(--text-secondary, rgba(255,255,255,0.4));
    flex-shrink: 0;
  }

  /* ── Main chat area ──────────────────────────────────────────────────────── */
  .ch-main {
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    min-width: 0;
  }

  /* ── Empty state ─────────────────────────────────────────────────────────── */
  .ch-empty-state {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    color: var(--text-secondary, rgba(255,255,255,0.35));
  }

  .ch-empty-icon {
    opacity: 0.3;
  }

  .ch-empty-text {
    font-size: 14px;
    margin: 0;
  }

  .ch-empty {
    padding: 20px 16px;
    font-size: 12px;
    color: var(--text-secondary, rgba(255,255,255,0.35));
    text-align: center;
  }

  /* ── Chat header ─────────────────────────────────────────────────────────── */
  .ch-chat-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 20px;
    border-bottom: 1px solid var(--border-subtle, rgba(255,255,255,0.06));
    flex-shrink: 0;
  }

  .ch-chat-agent {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .ch-chat-agent-avatar {
    font-size: 22px;
    line-height: 1;
  }

  .ch-chat-agent-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ch-chat-agent-name {
    font-size: 14px;
    font-weight: 600;
  }

  .ch-chat-agent-status {
    font-size: 11px;
    text-transform: capitalize;
  }
  .ch-status--active { color: #22c55e; }
  .ch-status--archived { color: rgba(255,255,255,0.35); }

  .ch-chat-header-actions {
    display: flex;
    gap: 8px;
  }

  /* ── Message list ────────────────────────────────────────────────────────── */
  .ch-messages {
    flex: 1;
    overflow-y: auto;
    padding: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .ch-messages-empty {
    text-align: center;
    color: var(--text-secondary, rgba(255,255,255,0.35));
    font-size: 13px;
    margin-top: 40px;
  }

  /* ── Individual messages ─────────────────────────────────────────────────── */
  .ch-msg {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-width: 75%;
  }

  .ch-msg--user {
    align-self: flex-end;
    align-items: flex-end;
  }

  .ch-msg--agent {
    align-self: flex-start;
    align-items: flex-start;
  }

  .ch-msg--system {
    align-self: center;
    align-items: center;
    max-width: 90%;
  }

  .ch-msg-agent-header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding-left: 2px;
  }

  .ch-msg-avatar {
    font-size: 14px;
    line-height: 1;
  }

  .ch-msg-agent-name {
    font-size: 11px;
    font-weight: 600;
    color: var(--text-secondary, rgba(255,255,255,0.5));
  }

  .ch-msg-meta {
    font-size: 11px;
    color: var(--text-secondary, rgba(255,255,255,0.3));
  }

  .ch-msg-bubble {
    padding: 10px 14px;
    border-radius: 12px;
    font-size: 14px;
    line-height: 1.55;
  }

  .ch-msg-bubble--user {
    background: var(--accent, #6366f1);
    color: #fff;
    border-bottom-right-radius: 4px;
  }

  .ch-msg-bubble--agent {
    background: var(--surface-1, #1e1e24);
    border: 1px solid var(--border-subtle, rgba(255,255,255,0.07));
    border-bottom-left-radius: 4px;
  }

  .ch-msg-text {
    margin: 0;
    white-space: pre-wrap;
    word-break: break-word;
  }

  /* ── System messages ─────────────────────────────────────────────────────── */
  .ch-msg-system-label {
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: rgba(255,255,255,0.25);
    margin-bottom: 2px;
  }

  .ch-msg-system-content {
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 12px;
    font-family: var(--font-mono, monospace);
    color: rgba(255,255,255,0.45);
    margin: 0;
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 100px;
    overflow-y: auto;
  }

  /* ── Thinking indicator ──────────────────────────────────────────────────── */
  .ch-msg-bubble--thinking {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 12px 16px;
  }

  .ch-thinking-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: rgba(255,255,255,0.35);
    animation: ch-pulse 1.2s ease-in-out infinite;
  }
  .ch-thinking-dot:nth-child(2) { animation-delay: 0.2s; }
  .ch-thinking-dot:nth-child(3) { animation-delay: 0.4s; }

  @keyframes ch-pulse {
    0%, 80%, 100% { opacity: 0.3; transform: scale(0.85); }
    40% { opacity: 1; transform: scale(1); }
  }

  /* ── Input bar ───────────────────────────────────────────────────────────── */
  .ch-input-bar {
    padding: 12px 20px 16px;
    border-top: 1px solid var(--border-subtle, rgba(255,255,255,0.06));
    flex-shrink: 0;
  }

  .ch-input-bar--disabled {
    background: rgba(0,0,0,0.1);
  }

  .ch-archived-notice {
    font-size: 13px;
    color: var(--text-secondary, rgba(255,255,255,0.35));
    text-align: center;
    margin: 8px 0;
  }

  .ch-input-wrap {
    display: flex;
    gap: 10px;
    align-items: flex-end;
    background: var(--surface-1, #1e1e24);
    border: 1px solid var(--border-subtle, rgba(255,255,255,0.1));
    border-radius: 12px;
    padding: 8px 8px 8px 14px;
    transition: border-color 0.15s;
  }
  .ch-input-wrap:focus-within {
    border-color: var(--accent, #6366f1);
  }

  .ch-textarea {
    flex: 1;
    background: transparent;
    border: none;
    outline: none;
    color: var(--text-primary, #e8e8ed);
    font-size: 14px;
    font-family: inherit;
    line-height: 1.55;
    resize: none;
    min-height: 22px;
    max-height: 160px;
    overflow-y: auto;
  }
  .ch-textarea::placeholder {
    color: rgba(255,255,255,0.25);
  }
  .ch-textarea:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .ch-send-btn {
    flex-shrink: 0;
    width: 34px;
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    border: none;
    background: var(--accent, #6366f1);
    color: #fff;
    cursor: pointer;
    transition: background 0.15s, opacity 0.15s;
  }
  .ch-send-btn:hover:not(:disabled) {
    background: #5558e8;
  }
  .ch-send-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .ch-input-hint {
    font-size: 11px;
    color: rgba(255,255,255,0.2);
    text-align: right;
    margin: 5px 0 0;
  }

  /* ── Shared buttons ──────────────────────────────────────────────────────── */
  .ch-btn {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 6px 12px;
    border-radius: 6px;
    border: 1px solid transparent;
    font-size: 13px;
    font-family: inherit;
    cursor: pointer;
    transition: all 0.15s;
    line-height: 1;
  }

  .ch-btn--primary {
    background: var(--accent, #6366f1);
    color: #fff;
    border-color: var(--accent, #6366f1);
  }
  .ch-btn--primary:hover:not(:disabled) { background: #5558e8; }
  .ch-btn--primary:disabled { opacity: 0.45; cursor: not-allowed; }

  .ch-btn--ghost {
    background: transparent;
    color: var(--text-secondary, rgba(255,255,255,0.5));
    border-color: var(--border-subtle, rgba(255,255,255,0.1));
  }
  .ch-btn--ghost:hover { color: var(--text-primary, #e8e8ed); background: rgba(255,255,255,0.05); }

  .ch-btn--sm {
    padding: 4px 10px;
    font-size: 12px;
  }
</style>
