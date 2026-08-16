/**
 * code-editor query helpers — thin selectors + ONE save mutation that fixes
 * the field-name contract for the workspace-scoped write endpoint.
 *
 * No new fetch logic is added beyond the save mutation. We reuse:
 *   - workspaceFileQuery(slug, path) (queries/workspaces.ts) — read text content
 *   - fileQuery(id) (queries/files.ts) — read row metadata
 *   - GET /api/v1/files/:id/content — raw bytes (handled by file-viewer.ts)
 *
 * Why a thin save wrapper instead of reusing writeFileMutation():
 *   The existing `writeFileMutation` (queries/workspaces.ts) sends `{contents}`
 *   but `CanopyWeb.WorkspaceFilesController.write/2` reads `params["content"]`
 *   (singular). Until that gets reconciled, the code-editor pane uses its own
 *   wrapper that sends the singular field that the backend actually accepts.
 *   See wiring/code-editor-wiring.md → "Backend gap" for the upstream fix.
 *
 *   The PATCH /files/:id endpoint can NOT be used to update content — it's
 *   tag-only today. All saves flow through the workspace-scoped PUT.
 */

import { apiPut } from "$lib/api/client.js";
import { fileQuery as filesFileQuery } from "$lib/api/queries/files.js";
import { workspaceFileQuery as wsFileQuery } from "$lib/api/queries/workspaces.js";
import type {
  CodeEditorPaneConfig,
  CodeEditorSaveBody,
  CodeEditorSaveResult,
} from "$lib/domain/code-editor/types.js";

/**
 * Splat-path encoding — each segment URI-encoded, slashes preserved.
 * Mirrors the helper inside queries/workspaces.ts but copied locally to keep
 * this module self-contained. (LOC < 6 — duplicating a 4-line function is
 * cheaper than introducing an import cycle.)
 */
function encodePath(path: string): string {
  return path
    .split("/")
    .filter((seg) => seg.length > 0)
    .map(encodeURIComponent)
    .join("/");
}

// ── Raw save call ────────────────────────────────────────────────────────────

/**
 * Save a file's text content via PUT /api/v1/workspaces/:slug/files/*path.
 * Returns the just-saved content so the caller can reset its dirty baseline.
 */
export async function saveCodeFile(
  slug: string,
  path: string,
  body: CodeEditorSaveBody,
): Promise<CodeEditorSaveResult> {
  // Note: backend reads `params["content"]` (singular). apiPut runs camelCase
  // → snake_case, but `content` has no caps so it survives unchanged.
  await apiPut<{ path: string; written: boolean }>(
    `/workspaces/${slug}/files/${encodePath(path)}`,
    { content: body.content },
  );
  return { path, written: true, savedContent: body.content };
}

// ── TanStack Query factories (re-exports for a single import surface) ────────

/** Re-export — file metadata when addressed by id. Keeps cache shared with files.ts. */
export const codeEditorMetadataQuery = filesFileQuery;

/** Re-export — file text content when addressed by (slug, path). */
export const codeEditorContentQuery = wsFileQuery;

/**
 * Mutation options for saving the editor buffer. Caller is responsible for
 * optimistic UI + rollback on failure (handled in CodeEditorPane).
 */
export function saveCodeFileMutation(slug: string) {
  return {
    mutationKey: ["code-editor", slug, "save"] as const,
    mutationFn: ({ path, content }: { path: string; content: string }) =>
      saveCodeFile(slug, path, { content }),
  };
}

/** Validate a pane config has enough info to fetch + save. */
export function isResolvable(cfg: CodeEditorPaneConfig): boolean {
  if (
    cfg.workspaceSlug &&
    cfg.workspaceSlug.length > 0 &&
    typeof cfg.path === "string" &&
    cfg.path.length > 0
  ) {
    return true;
  }
  // fileId-only is resolvable for READ but not for SAVE — the pane has to
  // resolve workspaceSlug + path from the FileRecord before write is allowed.
  if (cfg.fileId && cfg.fileId.length > 0) return true;
  return false;
}

/** Validate a pane config has enough info to SAVE specifically. */
export function isSaveable(cfg: CodeEditorPaneConfig): boolean {
  return Boolean(
    cfg.workspaceSlug &&
    cfg.workspaceSlug.length > 0 &&
    cfg.path &&
    cfg.path.length > 0,
  );
}
