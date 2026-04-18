/**
 * Files domain types — mirrors the Elixir backend at /api/v1/files.
 * See backend/lib/canopy_web/schemas/files_schema.ex for the source contracts.
 * All fields are camelCase; the client.ts fetch wrapper unwraps {data: ...} envelopes.
 */

/** Actor types for ownership attribution. */
export type ActorType = "user" | "agent" | "system";

/** Activity action types recorded per file event. */
export type FileActivityAction =
  | "created"
  | "updated"
  | "read"
  | "deleted"
  | "renamed"
  | "tagged";

/** File metadata record — one row from the `files` index table. */
export interface FileRecord {
  id: string;
  workspaceId: string;
  /** Relative path within the workspace root. */
  path: string;
  name: string;
  extension: string | null;
  mimeType: string | null;
  sizeBytes: number;
  sha256: string | null;
  ownerType: ActorType;
  ownerId: string | null;
  tags: string[];
  lastIndexedAt: string | null;
  archivedAt: string | null;
  insertedAt: string;
  updatedAt: string;
}

/** One entry in the file activity log. */
export interface FileActivity {
  id: string;
  fileId: string;
  actorType: ActorType;
  actorId: string | null;
  action: FileActivityAction;
  /** JSON object with action-specific details. */
  metadata: Record<string, unknown> | null;
  occurredAt: string;
  insertedAt: string;
}

/** Filter params accepted by GET /files. */
export interface FileFilters {
  workspace?: string;
  tag?: string;
  q?: string;
  extension?: string;
}

/** Body for multipart POST /files (constructed as FormData by caller). */
export interface UploadBody {
  workspaceSlug: string;
  path: string;
  file: File;
}

/** Body for PATCH /files/:id — update tags. */
export interface UpdateTagsBody {
  tags: string[];
}
