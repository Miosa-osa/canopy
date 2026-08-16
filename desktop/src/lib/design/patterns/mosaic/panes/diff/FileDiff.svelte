<script lang="ts">
  /**
   * FileDiff — per-file diff renderer for the Diff pane.
   *
   * Reuses the Phase-5 `DiffViewer` (patterns/diff/DiffViewer.svelte) for the
   * line-by-line rendering — no duplication of hunk parsing, no parallel
   * shiki instance. We add a per-hunk action strip (Keep / Discard / Stage)
   * above the DiffViewer using `Hunk.svelte`.
   *
   * Mutations call into queries/diff.ts which hit Canopy.Sessions.WorktreeManager
   * via the existing /worktree/discard-hunk and /worktree/stage endpoints.
   *
   * CSS prefix: fd-
   * LOC target: ≤ 200.
   */
  import {
    type CreateMutationOptions,
    createMutation,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import DiffViewer from "$lib/design/patterns/diff/DiffViewer.svelte";
  import {
    discardHunkMutation,
    stageFileMutation,
  } from "$lib/api/queries/diff.js";
  import type {
    DiffFile,
    DiffHunk,
    DiscardHunkRequest,
    DiscardHunkResult,
    StageRequest,
    StageResult,
  } from "$lib/domain/diff/types.js";
  import { toasts } from "$lib/stores/toasts.svelte.js";
  import Hunk from "./Hunk.svelte";
  import { buildHunkContent } from "./parse-hunks.js";

  interface Props {
    file: DiffFile;
    /** Required for mutations. When absent (ref-mode diff), Discard/Stage are hidden. */
    sessionId?: string;
    /** Hide hunk-level actions entirely (e.g. read-only ref diffs). */
    readOnly?: boolean;
  }

  let { file, sessionId, readOnly = false }: Props = $props();

  const queryClient = useQueryClient();

  const canMutate = $derived(Boolean(sessionId) && !readOnly);

  // ── Mutations ────────────────────────────────────────────────────────────────
  // Mutations are created once with a no-op fallback when sessionId is absent.
  // The wrapper helpers (handleDiscard / handleStage) bail out before calling
  // .mutate when sessionId is missing, so the no-op fn is never reached.

  const discardMut = createMutation<DiscardHunkResult, Error, DiscardHunkRequest>(
    writable(
      untrack(
        () =>
          (sessionId
            ? discardHunkMutation(sessionId)
            : {
                mutationKey: ["diff", "noop", "discard"] as const,
                mutationFn: async () => ({ ok: true }),
              }) as CreateMutationOptions<DiscardHunkResult, Error, DiscardHunkRequest>,
      ),
    ),
  );

  const stageMut = createMutation<StageResult, Error, StageRequest>(
    writable(
      untrack(
        () =>
          (sessionId
            ? stageFileMutation(sessionId)
            : {
                mutationKey: ["diff", "noop", "stage"] as const,
                mutationFn: async () => ({ ok: true, staged: [] }),
              }) as CreateMutationOptions<StageResult, Error, StageRequest>,
      ),
    ),
  );

  // ── UI state — per-hunk loading + kept set ───────────────────────────────────

  let discardingHeader = $state<string | null>(null);
  let stagingHeader = $state<string | null>(null);
  let keptHeaders = $state<Set<string>>(new Set());

  function handleKeep(hunk: DiffHunk): void {
    const next = new Set(keptHeaders);
    if (next.has(hunk.header)) next.delete(hunk.header);
    else next.add(hunk.header);
    keptHeaders = next;
  }

  function handleDiscard(hunk: DiffHunk): void {
    if (!sessionId) return;
    discardingHeader = hunk.header;
    $discardMut.mutate(
      {
        filePath: file.path,
        hunkHeader: hunk.header,
        hunkContent: buildHunkContent(hunk),
      },
      {
        onSuccess: () => {
          toasts.success(`Discarded hunk in ${file.path}`);
          void queryClient.invalidateQueries({
            queryKey: ["sessions", sessionId, "worktree"],
          });
        },
        onError: (err) => {
          toasts.error(
            err instanceof Error ? err.message : "Failed to discard hunk",
          );
        },
        onSettled: () => {
          discardingHeader = null;
        },
      },
    );
  }

  function handleStage(hunk: DiffHunk): void {
    if (!sessionId) return;
    stagingHeader = hunk.header;
    // Per-hunk staging is approximated by staging the file. Hunk-level
    // index editing would require `git apply --cached` round-trips; out of
    // scope for the first ship. The action label ("Stage") still maps to
    // the receiver's expectation of "this hunk's file is staged".
    $stageMut.mutate(
      { files: [file.path] },
      {
        onSuccess: () => {
          toasts.success(`Staged ${file.path}`);
          void queryClient.invalidateQueries({
            queryKey: ["sessions", sessionId, "worktree"],
          });
        },
        onError: (err) => {
          toasts.error(
            err instanceof Error ? err.message : "Failed to stage file",
          );
        },
        onSettled: () => {
          stagingHeader = null;
        },
      },
    );
  }
</script>

<div class="fd-root">
  {#if canMutate && file.hunks.length > 0 && !file.binary}
    <ul class="fd-hunk-strip" aria-label="Hunk actions">
      {#each file.hunks as h (h.header)}
        <li>
          <Hunk
            hunk={h}
            isDiscarding={discardingHeader === h.header}
            isStaging={stagingHeader === h.header}
            isKept={keptHeaders.has(h.header)}
            onKeep={handleKeep}
            onDiscard={handleDiscard}
            onStage={handleStage}
          />
        </li>
      {/each}
    </ul>
  {/if}

  <div class="fd-viewer">
    <DiffViewer {file} />
  </div>
</div>

<style>
  .fd-root {
    display: flex;
    flex-direction: column;
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }

  .fd-hunk-strip {
    list-style: none;
    margin: 0;
    padding: 0;
    flex-shrink: 0;
    max-height: 30%;
    overflow-y: auto;
    border-bottom: 1px solid var(--border);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .fd-viewer {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    overflow: hidden;
  }
</style>
