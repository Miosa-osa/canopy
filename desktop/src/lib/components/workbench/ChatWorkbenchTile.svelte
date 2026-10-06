<script lang="ts">
  import { onMount } from "svelte";
  import ChatInput from "$lib/components/chat/ChatInput.svelte";
  import MessageBubble from "$lib/components/chat/MessageBubble.svelte";
  import { chatStore } from "$lib/stores/chat.svelte";
  import { workspaceStore } from "$lib/stores/workspace.svelte";

  let messageListEl = $state<HTMLDivElement | null>(null);

  onMount(() => {
    void chatStore.listSessions(workspaceStore.activeWorkspaceId ?? undefined);
  });

  $effect(() => {
    void chatStore.messages.length;
    void chatStore.pendingUserMessage;
    void chatStore.streaming.textBuffer;
    queueMicrotask(() => {
      if (messageListEl) messageListEl.scrollTop = messageListEl.scrollHeight;
    });
  });

  async function handleSend(text: string): Promise<void> {
    await chatStore.sendMessage(text);
  }
</script>

<div class="chat-tile">
  <div class="chat-meta">
    <span>{chatStore.currentSession?.title ?? "Workbench chat"}</span>
    {#if chatStore.isStreaming}
      <strong>streaming</strong>
    {:else if chatStore.currentSession}
      <strong>{chatStore.currentSession.status}</strong>
    {/if}
  </div>

  <div class="chat-messages" bind:this={messageListEl} aria-label="Workbench chat messages">
    {#if chatStore.isLoadingMessages}
      <div class="chat-empty">Loading messages...</div>
    {:else if chatStore.messages.length === 0 && !chatStore.pendingUserMessage && !chatStore.isStreaming}
      <div class="chat-empty">
        <strong>Agent chat tile</strong>
        <span>Send a request to start a Canopy session from the workbench.</span>
      </div>
    {:else}
      {#each chatStore.messages as message (message.id)}
        <MessageBubble {message} />
      {/each}

      {#if chatStore.pendingUserMessage}
        <MessageBubble message={chatStore.pendingUserMessage} />
      {/if}

      {#if chatStore.isStreaming}
        <MessageBubble
          message={{
            id: "streaming",
            session_id: chatStore.currentSession?.id ?? "pending",
            role: "assistant",
            content: "",
            timestamp: new Date().toISOString(),
            tool_calls: chatStore.streaming.toolCalls,
          }}
          isStreaming
          thinkingText={chatStore.streaming.thinkingBuffer}
          liveText={chatStore.streaming.textBuffer}
        />
      {/if}
    {/if}
  </div>

  {#if chatStore.error}
    <div class="chat-error" role="alert">{chatStore.error}</div>
  {/if}

  <ChatInput
    isStreaming={chatStore.isStreaming}
    onSend={handleSend}
    onCancel={() => chatStore.cancelGeneration()}
    placeholder="Ask an agent to work..."
  />
</div>

<style>
  .chat-tile {
    display: flex;
    height: 100%;
    min-height: 0;
    flex-direction: column;
    background: var(--bg-primary);
  }

  .chat-meta {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    min-height: 32px;
    padding: 0 12px;
    border-bottom: 1px solid var(--border-default);
    color: var(--text-tertiary);
    font-size: 11px;
  }

  .chat-meta span {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .chat-meta strong {
    color: var(--accent-primary);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
  }

  .chat-messages {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: 12px;
  }

  .chat-empty {
    display: flex;
    height: 100%;
    min-height: 120px;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    gap: 6px;
    color: var(--text-tertiary);
    font-size: 12px;
    text-align: center;
  }

  .chat-empty strong {
    color: var(--text-primary);
    font-size: 13px;
  }

  .chat-error {
    padding: 8px 12px;
    border-top: 1px solid color-mix(in srgb, #ef4444 35%, var(--border-default));
    color: #fca5a5;
    font-size: 12px;
  }
</style>

