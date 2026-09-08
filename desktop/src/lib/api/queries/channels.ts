/**
 * TanStack Query factories for the /channels resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { API_BASE, apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  AddMemberBody,
  AddReactionBody,
  Channel,
  ChannelFilters,
  ChannelMember,
  ChannelMessage,
  CreateChannelBody,
  EditMessageBody,
  MessageListOpts,
  MessagePage,
  SendMessageBody,
  UnreadCount,
  UpdateChannelBody,
} from '$lib/domain/channels/types.js';

// ---------------------------------------------------------------------------
// Raw API calls
// ---------------------------------------------------------------------------

export function listChannels(filters?: ChannelFilters): Promise<Channel[]> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug) params.set('workspace_slug', filters.workspaceSlug);
  if (filters?.visibility) params.set('visibility', filters.visibility);
  if (filters?.includeArchived) params.set('include_archived', 'true');
  const qs = params.toString();
  return apiGet<Channel[]>(`/channels${qs ? `?${qs}` : ''}`);
}

export function getChannel(id: string): Promise<Channel> {
  return apiGet<Channel>(`/channels/${id}`);
}

export function createChannel(body: CreateChannelBody): Promise<Channel> {
  return apiPost<Channel>('/channels', body);
}

export function updateChannel(id: string, body: UpdateChannelBody): Promise<Channel> {
  return apiPatch<Channel>(`/channels/${id}`, body);
}

export function deleteChannel(id: string): Promise<void> {
  return apiDelete<void>(`/channels/${id}`);
}

export function listMembers(channelId: string): Promise<ChannelMember[]> {
  return apiGet<ChannelMember[]>(`/channels/${channelId}/members`);
}

export function addMember(channelId: string, body: AddMemberBody): Promise<ChannelMember> {
  return apiPost<ChannelMember>(`/channels/${channelId}/members`, body);
}

export function removeMember(channelId: string, actorType: string, actorId: string): Promise<void> {
  return apiDelete<void>(`/channels/${channelId}/members/${actorType}/${actorId}`);
}

export async function listMessages(
  channelId: string,
  opts?: MessageListOpts
): Promise<MessagePage> {
  const params = new URLSearchParams();
  if (opts?.before) params.set('before', opts.before);
  if (opts?.limit !== undefined) params.set('limit', String(opts.limit));
  const qs = params.toString();
  // Manual fetch: the auto-unwrap in apiGet strips has_more from the envelope
  const res = await fetch(`${API_BASE}/channels/${channelId}/messages${qs ? `?${qs}` : ''}`, {
    headers: { 'Content-Type': 'application/json' },
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const json = (await res.json()) as {
    data: Record<string, unknown>[];
    has_more: boolean;
  };
  const messages = (json.data ?? []).map((m) => ({
    id: m.id as string,
    channelId: m.channel_id as string,
    authorType: m.author_type as string,
    authorId: (m.author_id as string) ?? null,
    bodyMarkdown: m.body_markdown as string,
    bodyRenderedHtml: (m.body_rendered_html as string) ?? null,
    replyToId: (m.reply_to_id as string) ?? null,
    threadCount: (m.thread_count as number) ?? 0,
    editedAt: (m.edited_at as string) ?? null,
    deletedAt: (m.deleted_at as string) ?? null,
    mentions: (m.mentions as string[]) ?? [],
    attachments: (m.attachments as Record<string, unknown>) ?? {},
    insertedAt: m.inserted_at as string,
    updatedAt: m.updated_at as string,
  })) as ChannelMessage[];
  return { data: messages, hasMore: json.has_more ?? false };
}

export function sendMessage(channelId: string, body: SendMessageBody): Promise<ChannelMessage> {
  return apiPost<ChannelMessage>(`/channels/${channelId}/messages`, body);
}

export function editMessage(
  channelId: string,
  messageId: string,
  body: EditMessageBody
): Promise<ChannelMessage> {
  return apiPatch<ChannelMessage>(`/channels/${channelId}/messages/${messageId}`, body);
}

export function deleteMessage(channelId: string, messageId: string): Promise<void> {
  return apiDelete<void>(`/channels/${channelId}/messages/${messageId}`);
}

export function addReaction(
  channelId: string,
  messageId: string,
  body: AddReactionBody
): Promise<void> {
  return apiPost<void>(`/channels/${channelId}/messages/${messageId}/reactions`, body);
}

export function removeReaction(channelId: string, messageId: string, emoji: string): Promise<void> {
  return apiDelete<void>(`/channels/${channelId}/messages/${messageId}/reactions/${emoji}`);
}

export function pinMessage(channelId: string, messageId: string): Promise<void> {
  return apiPost<void>(`/channels/${channelId}/messages/${messageId}/pin`);
}

export function unpinMessage(channelId: string, messageId: string): Promise<void> {
  return apiDelete<void>(`/channels/${channelId}/messages/${messageId}/pin`);
}

export function markRead(channelId: string): Promise<void> {
  return apiPost<void>(`/channels/${channelId}/read`);
}

export function getUnreadCount(channelId: string): Promise<UnreadCount> {
  return apiGet<UnreadCount>(`/channels/${channelId}/unread`);
}

// ---------------------------------------------------------------------------
// TanStack Query option factories
// ---------------------------------------------------------------------------

/** Query options for the channel list with optional filters. */
export function channelsQuery(filters?: ChannelFilters) {
  return {
    queryKey: ['channels', filters ?? {}] as const,
    queryFn: () => listChannels(filters),
    staleTime: 30_000,
  };
}

/** Query options for a single channel. */
export function channelQuery(id: string) {
  return {
    queryKey: ['channels', id] as const,
    queryFn: () => getChannel(id),
    staleTime: 30_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to create a channel. */
export function createChannelMutation() {
  return {
    mutationKey: ['channels', 'create'] as const,
    mutationFn: (body: CreateChannelBody) => createChannel(body),
  };
}

/** Mutation options to update a channel. */
export function updateChannelMutation() {
  return {
    mutationKey: ['channels', 'update'] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateChannelBody }) => updateChannel(id, body),
  };
}

/** Mutation options to archive (delete) a channel. */
export function deleteChannelMutation() {
  return {
    mutationKey: ['channels', 'delete'] as const,
    mutationFn: (id: string) => deleteChannel(id),
  };
}

/** Query options for channel members. */
export function channelMembersQuery(channelId: string) {
  return {
    queryKey: ['channels', channelId, 'members'] as const,
    queryFn: () => listMembers(channelId),
    staleTime: 30_000,
    enabled: Boolean(channelId),
  };
}

/** Mutation options to add a member to a channel. */
export function addMemberMutation() {
  return {
    mutationKey: ['channels', 'members', 'add'] as const,
    mutationFn: ({ channelId, body }: { channelId: string; body: AddMemberBody }) =>
      addMember(channelId, body),
  };
}

/** Mutation options to remove a member from a channel. */
export function removeMemberMutation() {
  return {
    mutationKey: ['channels', 'members', 'remove'] as const,
    mutationFn: ({
      channelId,
      actorType,
      actorId,
    }: {
      channelId: string;
      actorType: string;
      actorId: string;
    }) => removeMember(channelId, actorType, actorId),
  };
}

/** Query options for cursor-paginated channel messages. */
export function channelMessagesQuery(channelId: string, opts?: MessageListOpts) {
  return {
    queryKey: ['channels', channelId, 'messages', opts ?? {}] as const,
    queryFn: () => listMessages(channelId, opts),
    staleTime: 0,
    enabled: Boolean(channelId),
  };
}

/** Mutation options to send a message. */
export function sendMessageMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'messages', 'send'] as const,
    mutationFn: (body: SendMessageBody) => sendMessage(channelId, body),
  };
}

/** Mutation options to edit a message. */
export function editMessageMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'messages', 'edit'] as const,
    mutationFn: ({ messageId, body }: { messageId: string; body: EditMessageBody }) =>
      editMessage(channelId, messageId, body),
  };
}

/** Mutation options to delete a message. */
export function deleteMessageMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'messages', 'delete'] as const,
    mutationFn: (messageId: string) => deleteMessage(channelId, messageId),
  };
}

/** Mutation options to add a reaction. */
export function addReactionMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'reactions', 'add'] as const,
    mutationFn: ({ messageId, emoji }: { messageId: string; emoji: string }) =>
      addReaction(channelId, messageId, { emoji }),
  };
}

/** Mutation options to remove a reaction. */
export function removeReactionMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'reactions', 'remove'] as const,
    mutationFn: ({ messageId, emoji }: { messageId: string; emoji: string }) =>
      removeReaction(channelId, messageId, emoji),
  };
}

/** Mutation options to pin a message. */
export function pinMessageMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'messages', 'pin'] as const,
    mutationFn: (messageId: string) => pinMessage(channelId, messageId),
  };
}

/** Mutation options to unpin a message. */
export function unpinMessageMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'messages', 'unpin'] as const,
    mutationFn: (messageId: string) => unpinMessage(channelId, messageId),
  };
}

/** Mutation options to mark a channel as read. */
export function markReadMutation(channelId: string) {
  return {
    mutationKey: ['channels', channelId, 'read'] as const,
    mutationFn: () => markRead(channelId),
  };
}

/** Query options for unread count in a channel. */
export function unreadCountQuery(channelId: string) {
  return {
    queryKey: ['channels', channelId, 'unread'] as const,
    queryFn: () => getUnreadCount(channelId),
    staleTime: 10_000,
    enabled: Boolean(channelId),
  };
}
