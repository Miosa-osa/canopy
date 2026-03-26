// src/lib/stores/conversations.svelte.ts
// Chat conversation store — manages conversation list, active conversation, and messages

import type { Conversation, ConversationMessage } from "$api/types";
import { conversations as conversationsApi } from "$api/client";
import { toastStore } from "./toasts.svelte";

class ConversationsStore {
  // ── List state ─────────────────────────────────────────────────────────────
  conversations = $state<Conversation[]>([]);
  loading = $state(false);
  error = $state<string | null>(null);

  // ── Active conversation ─────────────────────────────────────────────────────
  activeConversation = $state<Conversation | null>(null);

  // ── Messages for active conversation ───────────────────────────────────────
  messages = $state<ConversationMessage[]>([]);

  // ── Interaction state ───────────────────────────────────────────────────────
  sending = $state(false);

  // ── Derived ────────────────────────────────────────────────────────────────
  activeCount = $derived(
    this.conversations.filter((c) => c.status === "active").length,
  );

  totalCount = $derived(this.conversations.length);

  // Simple unread approximation: conversations with messages we haven't viewed
  // (In production this would come from a read-receipt system)
  unreadCount = $derived(0);

  // ── List operations ────────────────────────────────────────────────────────

  async fetchConversations(
    workspaceId?: string,
    filters?: { agent_id?: string; status?: string },
  ): Promise<void> {
    this.loading = true;
    this.error = null;
    try {
      const mergedFilters = workspaceId
        ? { ...filters, workspace_id: workspaceId }
        : filters;
      this.conversations = await conversationsApi.list(mergedFilters);
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load conversations", msg);
    } finally {
      this.loading = false;
    }
  }

  async fetchConversation(id: string): Promise<void> {
    this.loading = true;
    this.error = null;
    try {
      const result = await conversationsApi.get(id);
      this.activeConversation = result.conversation;
      this.messages = result.messages ?? [];

      // Sync into list
      const idx = this.conversations.findIndex((c) => c.id === id);
      if (idx >= 0) {
        this.conversations = this.conversations.map((c) =>
          c.id === id ? result.conversation : c,
        );
      }
    } catch (e) {
      const msg = (e as Error).message;
      this.error = msg;
      toastStore.error("Failed to load conversation", msg);
    } finally {
      this.loading = false;
    }
  }

  async createConversation(
    agentId: string,
    title?: string,
  ): Promise<Conversation | null> {
    try {
      const result = await conversationsApi.create(agentId, title);
      const conv = result.conversation;
      this.conversations = [conv, ...this.conversations];
      this.activeConversation = conv;
      this.messages = [];
      return conv;
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to create conversation", msg);
      return null;
    }
  }

  async fetchMessages(
    id: string,
    params?: { limit?: number; before?: string },
  ): Promise<void> {
    try {
      const msgs = await conversationsApi.messages(id, params);
      if (params?.before) {
        // Prepend older messages for pagination
        this.messages = [...msgs, ...this.messages];
      } else {
        this.messages = msgs;
      }
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to load messages", msg);
    }
  }

  async sendMessage(id: string, content: string): Promise<void> {
    if (!content.trim()) return;
    this.sending = true;
    try {
      const result = await conversationsApi.sendMessage(id, content);
      this.messages = [
        ...this.messages,
        result.user_message,
        result.agent_message,
      ];

      // Update conversation counters in list
      this.conversations = this.conversations.map((c) =>
        c.id === id
          ? {
              ...c,
              message_count: c.message_count + 2,
              last_message_at: result.agent_message.inserted_at,
            }
          : c,
      );

      if (this.activeConversation?.id === id) {
        this.activeConversation = {
          ...this.activeConversation,
          message_count: this.activeConversation.message_count + 2,
          last_message_at: result.agent_message.inserted_at,
        };
      }
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to send message", msg);
    } finally {
      this.sending = false;
    }
  }

  async archiveConversation(id: string): Promise<void> {
    try {
      const result = await conversationsApi.archive(id);
      const updated = result.conversation;
      this.conversations = this.conversations.map((c) =>
        c.id === id ? updated : c,
      );
      if (this.activeConversation?.id === id) {
        this.activeConversation = updated;
      }
      toastStore.success("Conversation archived");
    } catch (e) {
      const msg = (e as Error).message;
      toastStore.error("Failed to archive conversation", msg);
    }
  }

  setActiveConversation(conv: Conversation | null): void {
    this.activeConversation = conv;
    if (!conv) {
      this.messages = [];
    }
  }
}

export const conversationsStore = new ConversationsStore();
