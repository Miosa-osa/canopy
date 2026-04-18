/**
 * Channel domain types — matches Elixir backend at /api/v1/channels.
 * See backend/lib/canopy_web/schemas/channels_schema.ex for source contracts.
 */

// ---------------------------------------------------------------------------
// Channel
// ---------------------------------------------------------------------------

export type ChannelVisibility = "public" | "private";

/** Summary row from GET /channels. */
export interface Channel {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  visibility: ChannelVisibility;
  workspaceSlug: string | null;
  icon: string | null;
  color: string | null;
  createdByUserId: string | null;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** Filters for GET /channels. */
export interface ChannelFilters {
  workspaceSlug?: string;
  visibility?: ChannelVisibility;
  includeArchived?: boolean;
}

/** Request body for POST /channels. */
export interface CreateChannelBody {
  slug: string;
  name: string;
  description?: string | null;
  visibility?: ChannelVisibility;
  workspaceSlug?: string | null;
  icon?: string | null;
  color?: string | null;
}

/** Request body for PATCH /channels/:id. */
export interface UpdateChannelBody {
  name?: string;
  description?: string | null;
  visibility?: ChannelVisibility;
  icon?: string | null;
  color?: string | null;
}

// ---------------------------------------------------------------------------
// Member
// ---------------------------------------------------------------------------

export type ActorType = "user" | "agent";
export type MemberRole = "member" | "admin";

export interface ChannelMember {
  id: string;
  channelId: string;
  actorType: ActorType;
  actorId: string;
  role: MemberRole;
  notificationsEnabled: boolean;
  lastReadAt: string | null;
  joinedAt: string;
  insertedAt: string;
  updatedAt: string;
}

/** Request body for POST /channels/:id/members. */
export interface AddMemberBody {
  actorType: ActorType;
  actorId: string;
  role?: MemberRole;
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

export type MessageAuthorType = "user" | "agent" | "system";

export interface ChannelMessage {
  id: string;
  channelId: string;
  authorType: MessageAuthorType;
  authorId: string | null;
  bodyMarkdown: string;
  bodyRenderedHtml: string | null;
  replyToId: string | null;
  threadCount: number;
  editedAt: string | null;
  deletedAt: string | null;
  mentions: string[];
  attachments: Record<string, unknown>;
  insertedAt: string;
  updatedAt: string;
}

/** Request body for POST /channels/:id/messages. */
export interface SendMessageBody {
  bodyMarkdown: string;
  replyToId?: string | null;
  attachments?: Record<string, unknown> | null;
}

/** Request body for PATCH /channels/:id/messages/:message_id. */
export interface EditMessageBody {
  bodyMarkdown: string;
}

/** Cursor-paginated message list response. */
export interface MessagePage {
  data: ChannelMessage[];
  hasMore: boolean;
}

/** Options for cursor pagination. */
export interface MessageListOpts {
  before?: string;
  limit?: number;
}

// ---------------------------------------------------------------------------
// Reaction
// ---------------------------------------------------------------------------

export interface ChannelReaction {
  id: string;
  messageId: string;
  actorType: ActorType;
  actorId: string;
  emoji: string;
  insertedAt: string;
}

/** Request body for POST /channels/:id/messages/:message_id/reactions. */
export interface AddReactionBody {
  emoji: string;
}

// ---------------------------------------------------------------------------
// Pin
// ---------------------------------------------------------------------------

export interface ChannelPin {
  id: string;
  channelId: string;
  messageId: string;
  pinnedByUserId: string;
  pinnedAt: string;
  insertedAt: string;
}

// ---------------------------------------------------------------------------
// Unread
// ---------------------------------------------------------------------------

export interface UnreadCount {
  count: number;
}
