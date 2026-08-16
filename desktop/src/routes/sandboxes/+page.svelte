<script lang="ts">
/**
 * /sandboxes — MIOSA-provisioned Firecracker VM management.
 *
 * Lists all non-destroyed sandboxes. Each row shows the sandbox ID,
 * owning session link, status dot, provisioned time, and a destroy button.
 *
 * Refreshes every 15 s (staleTime) via TanStack Query. Manual refresh
 * available via the header button.
 */
import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
import { writable } from "svelte/store";
import { untrack } from "svelte";
import { goto } from "$app/navigation";
import { Server } from "lucide-svelte";
import {
  sandboxesQuery,
  deleteSandboxMutation,
} from "$lib/api/queries/sandboxes.js";
import EmptyState from "$lib/design/patterns/EmptyState.svelte";
import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
import StatusDot from "$lib/design/patterns/StatusDot.svelte";
import type { Sandbox, SandboxStatus } from "$lib/domain/sandboxes/types.js";

const queryClient = useQueryClient();

const queryOptsStore = writable(untrack(() => sandboxesQuery()));
const query = createQuery(queryOptsStore);

const sandboxes = $derived(
  (($query.data as { data: Sandbox[] } | undefined)?.data ?? []) as Sandbox[]
);

let destroyingId = $state<string | null>(null);

const destroyMutation = createMutation(
  writable(untrack(() => deleteSandboxMutation()))
);

async function handleDestroy(sandbox: Sandbox): Promise<void> {
  if (destroyingId) return;
  destroyingId = sandbox.sandbox_id;
  try {
    await $destroyMutation.mutateAsync(sandbox.sandbox_id, {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ["sandboxes"] });
      },
    });
  } finally {
    destroyingId = null;
  }
}

function dotColor(status: SandboxStatus): "green" | "amber" | "red" | "grey" {
  switch (status) {
    case "ready":
      return "green";
    case "provisioning":
    case "pending":
      return "amber";
    case "failed":
      return "red";
    default:
      return "grey";
  }
}

function formatRelative(iso: string | null | undefined): string {
  if (!iso) return "—";
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60_000) return "just now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}
</script>

<div class="sb-page">
  <!-- Header -->
  <header class="sb-header">
    <div class="sb-header__text">
      <h1 class="sb-title">Sandboxes</h1>
      <p class="sb-desc">
        MIOSA-provisioned Firecracker VMs for session sandboxing
      </p>
    </div>
    <button
      class="sb-btn-refresh btn-compact btn-compact-ghost"
      onclick={() => queryClient.invalidateQueries({ queryKey: ["sandboxes"] })}
      aria-label="Refresh sandboxes"
      title="Refresh"
    >
      ↻
    </button>
  </header>

  <!-- States -->
  {#if $query.isError}
    <EmptyState
      title="Couldn't load sandboxes"
      body={($query.error as Error).message || "Check your connection and try again."}
      action="Retry"
      onAction={() => $query.refetch()}
    />
  {:else if $query.isLoading}
    <div class="sb-skeleton-wrap">
      <SkeletonList count={5} height="2.75rem" gap="0.375rem" />
    </div>
  {:else if sandboxes.length === 0}
    <EmptyState
      icon={Server as never}
      title="No sandboxes"
      body="Sessions with needs_sandbox: true in their metadata spawn sandboxes automatically."
    />
  {:else}
    <div class="sb-list">
      {#each sandboxes as sandbox (sandbox.sandbox_id)}
        <div class="sb-row">
          <span class="sb-status">
            <StatusDot
              color={dotColor(sandbox.status)}
              pulse={sandbox.status === "provisioning" || sandbox.status === "pending"}
            />
          </span>

          <span class="sb-id sb-mono" title={sandbox.sandbox_id}>
            {sandbox.sandbox_id}
          </span>

          <span class="sb-session">
            {#if sandbox.session_id}
              <button
                class="sb-link"
                onclick={() => goto(`/sessions/${sandbox.session_id}`)}
                title="Open session"
                aria-label="Open session {sandbox.session_id}"
              >
                Session ↗
              </button>
            {:else}
              —
            {/if}
          </span>

          <span class="sb-status-label sb-mono">{sandbox.status}</span>

          <span class="sb-time sb-mono">{formatRelative(sandbox.inserted_at)}</span>

          <span class="sb-actions">
            {#if sandbox.status !== "destroyed"}
              <button
                class="sb-btn-destroy"
                disabled={destroyingId === sandbox.sandbox_id}
                onclick={() => handleDestroy(sandbox)}
                aria-label="Destroy sandbox {sandbox.sandbox_id}"
                title="Destroy sandbox"
              >
                {destroyingId === sandbox.sandbox_id ? "Destroying…" : "Destroy"}
              </button>
            {/if}
          </span>
        </div>
      {/each}
    </div>
  {/if}
</div>

<style>
  .sb-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-6);
    overflow-y: auto;
    height: 100%;
  }

  /* ── Header ────────────────────────────────────────────────────────────────── */

  .sb-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .sb-header__text {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .sb-title {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
  }

  .sb-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .sb-btn-refresh {
    margin-top: var(--space-1);
  }

  /* ── Skeleton ──────────────────────────────────────────────────────────────── */

  .sb-skeleton-wrap {
    padding: var(--space-2) 0;
  }

  /* ── Row list ──────────────────────────────────────────────────────────────── */

  .sb-list {
    display: flex;
    flex-direction: column;
    gap: 0;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .sb-row {
    display: grid;
    grid-template-columns: 1.25rem 1fr 7rem 6rem 5rem 7rem;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-4);
    border-bottom: 1px solid var(--border);
    background: var(--bg-surface);
    transition: background var(--dur-instant) var(--ease-out);
  }

  .sb-row:last-child {
    border-bottom: none;
  }

  .sb-row:hover {
    background: color-mix(in oklch, var(--fg) 3%, var(--bg-surface) 97%);
  }

  .sb-status {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .sb-mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sb-id {
    color: var(--fg);
    font-weight: 500;
  }

  .sb-session {
    display: flex;
    align-items: center;
  }

  .sb-link {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--cnp-accent);
    background: none;
    border: none;
    cursor: pointer;
    padding: 0;
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  .sb-link:hover {
    opacity: 0.8;
  }

  .sb-time {
    text-align: right;
  }

  .sb-actions {
    display: flex;
    justify-content: flex-end;
  }

  /* ── Destroy button ────────────────────────────────────────────────────────── */

  .sb-btn-destroy {
    display: inline-flex;
    align-items: center;
    padding: 2px var(--space-2);
    border-radius: 9999px;
    border: 1px solid color-mix(in oklch, oklch(60% 0.2 25) 40%, var(--border) 60%);
    background: transparent;
    color: oklch(55% 0.2 25);
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    cursor: pointer;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      opacity var(--dur-instant) var(--ease-out);
  }

  .sb-btn-destroy:hover:not(:disabled) {
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
  }

  .sb-btn-destroy:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .sb-btn-destroy:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }
</style>
