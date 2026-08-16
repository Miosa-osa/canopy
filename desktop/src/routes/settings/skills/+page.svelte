<script lang="ts">
  /**
   * Settings › Skills — Skill Curator runtime configuration.
   *
   * Three sections:
   *  1. Atlas (Skill Curator agent) status card
   *  2. Lockfile management — pinned skills with version + content hash
   *  3. Unverified-source gating policy + registry connections
   *
   * Reads /api/v1/skill-curator/* endpoints. Does NOT modify the existing
   * /skills route — that one stays as the catalog browse page.
   */
  import {
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { Lock, Plus, RefreshCw, ShieldCheck, ShieldOff } from "lucide-svelte";
  import {
    addSource,
    lockfileQuery,
    refreshSources,
    sourcesQuery,
    unlockSkill,
    unverifiedQuery,
    verifySkill,
  } from "$lib/api/queries/skill_curator.js";
  import type {
    LockfileEntry,
    RegistrySource,
    UnverifiedPolicy,
  } from "$lib/domain/skill_curator/types.js";

  const qc = useQueryClient();

  // ── Queries ────────────────────────────────────────────────────────────────

  const lockfileResult = createQuery(lockfileQuery());
  const unverifiedResult = createQuery(unverifiedQuery(50));
  const sourcesResult = createQuery(sourcesQuery());

  const lockfile = $derived<LockfileEntry[]>($lockfileResult.data ?? []);
  const unverifiedSlugs = $derived<string[]>(
    $unverifiedResult.data?.data ?? [],
  );
  const sources = $derived<RegistrySource[]>($sourcesResult.data ?? []);

  // ── Policy state (local-only for v0.1) ─────────────────────────────────────

  let unverifiedPolicy = $state<UnverifiedPolicy>("prompt");
  let policyError = $state<string | null>(null);

  function setPolicy(p: UnverifiedPolicy) {
    unverifiedPolicy = p;
    policyError = null;
  }

  // ── Add-source form ────────────────────────────────────────────────────────

  let addingSource = $state(false);
  let formName = $state("");
  let formUrl = $state("");
  let formKind = $state("generic");
  let formError = $state<string | null>(null);

  function resetSourceForm() {
    formName = "";
    formUrl = "";
    formKind = "generic";
    formError = null;
  }

  const addSourceMut = createMutation({
    mutationFn: () =>
      addSource({
        name: formName.trim(),
        url: formUrl.trim(),
        kind: formKind.trim() || undefined,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["skill_curator", "sources"] });
      addingSource = false;
      resetSourceForm();
    },
    onError: (err: Error) => {
      formError = err.message;
    },
  });

  function submitAddSource(e: Event) {
    e.preventDefault();
    formError = null;
    if (!formName.trim() || !formUrl.trim()) {
      formError = "Name and URL are required.";
      return;
    }
    $addSourceMut.mutate();
  }

  // ── Refresh sources ────────────────────────────────────────────────────────

  const refreshMut = createMutation({
    mutationFn: () => refreshSources(),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["skill_curator", "sources"] });
    },
  });

  // ── Verify ─────────────────────────────────────────────────────────────────

  const verifyMut = createMutation({
    mutationFn: (slug: string) => verifySkill(slug, "user"),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["skill_curator", "unverified"] });
    },
  });

  // ── Unlock ─────────────────────────────────────────────────────────────────

  const unlockMut = createMutation({
    mutationFn: ({
      workspaceSlug,
      skillSlug,
    }: {
      workspaceSlug: string;
      skillSlug: string;
    }) => unlockSkill(workspaceSlug, skillSlug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["skill_curator", "lockfile"] });
    },
  });

  function shortHash(h: string | null): string {
    if (!h) return "";
    return h.length > 12 ? `${h.slice(0, 12)}…` : h;
  }
</script>

<div class="sk-page">
  <header class="sk-header">
    <div>
      <h1 class="sk-title">Skills</h1>
      <p class="sk-sub">Atlas (Skill Curator) configuration · lockfile · sources</p>
    </div>
  </header>

  <!-- Atlas status card -->
  <section class="sk-card sk-atlas">
    <div class="sk-atlas-row">
      <span class="sk-atlas-emoji" aria-hidden="true">🧰</span>
      <div class="sk-atlas-body">
        <div class="sk-atlas-name">Atlas</div>
        <div class="sk-atlas-meta">
          Heartbeat every 4h · Pins versions · Gates unverified sources
        </div>
      </div>
      <a href="/agents/skill-curator" class="sk-atlas-link">View persona</a>
    </div>
  </section>

  <!-- Unverified policy -->
  <section class="sk-card">
    <header class="sk-card-header">
      <h2 class="sk-card-title">
        <ShieldCheck size={14} aria-hidden="true" />
        Unverified-source policy
      </h2>
      <span class="sk-local-badge">local only — backend endpoint coming soon</span>
    </header>

    <p class="sk-help">
      How should Atlas handle install requests for skills coming from sources
      it has not yet verified?
    </p>

    <div class="sk-policy">
      <button
        type="button"
        class="sk-policy-opt"
        class:active={unverifiedPolicy === "block"}
        onclick={() => setPolicy("block")}
      >
        <strong>Block</strong>
        <span>Reject all unverified-source installs</span>
      </button>
      <button
        type="button"
        class="sk-policy-opt"
        class:active={unverifiedPolicy === "prompt"}
        onclick={() => setPolicy("prompt")}
      >
        <strong>Prompt</strong>
        <span>Require explicit approval (recommended)</span>
      </button>
      <button
        type="button"
        class="sk-policy-opt"
        class:active={unverifiedPolicy === "allow"}
        onclick={() => setPolicy("allow")}
      >
        <strong>Allow</strong>
        <span>Trust all sources (not recommended)</span>
      </button>
    </div>

    {#if policyError}
      <p class="sk-error">{policyError}</p>
    {/if}
  </section>

  <!-- Unverified queue -->
  <section class="sk-card">
    <header class="sk-card-header">
      <h2 class="sk-card-title">
        <ShieldOff size={14} aria-hidden="true" />
        Unverified skills
      </h2>
      <span class="sk-card-meta">{unverifiedSlugs.length} pending</span>
    </header>

    {#if $unverifiedResult.isLoading}
      <p class="sk-empty">Loading…</p>
    {:else if unverifiedSlugs.length === 0}
      <p class="sk-empty">All installed skills are verified.</p>
    {:else}
      <ul class="sk-list">
        {#each unverifiedSlugs as slug (slug)}
          <li class="sk-row">
            <code class="sk-row-slug">{slug}</code>
            <button
              type="button"
              class="sk-btn sk-btn-primary"
              onclick={() => $verifyMut.mutate(slug)}
              disabled={$verifyMut.isPending}
            >
              Mark verified
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  </section>

  <!-- Lockfile -->
  <section class="sk-card">
    <header class="sk-card-header">
      <h2 class="sk-card-title">
        <Lock size={14} aria-hidden="true" />
        Lockfile
      </h2>
      <span class="sk-card-meta">{lockfile.length} pinned</span>
    </header>

    {#if $lockfileResult.isLoading}
      <p class="sk-empty">Loading…</p>
    {:else if lockfile.length === 0}
      <p class="sk-empty">
        No skills pinned yet. Atlas writes a lockfile entry per install.
      </p>
    {:else}
      <table class="sk-table">
        <thead>
          <tr>
            <th>Skill</th>
            <th>Version</th>
            <th>Content hash</th>
            <th>Source</th>
            <th>Locked at</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {#each lockfile as entry (entry.id)}
            <tr>
              <td>
                <div class="sk-row-name">{entry.skillSlug}</div>
                <div class="sk-row-meta">{entry.workspaceSlug}</div>
              </td>
              <td><code>{entry.lockedVersion}</code></td>
              <td><code title={entry.contentHash}>{shortHash(entry.contentHash)}</code></td>
              <td>{entry.source ?? "—"}</td>
              <td>{entry.lockedAt ?? "—"}</td>
              <td>
                <button
                  type="button"
                  class="sk-btn sk-btn-ghost"
                  onclick={() =>
                    $unlockMut.mutate({
                      workspaceSlug: entry.workspaceSlug,
                      skillSlug: entry.skillSlug,
                    })}
                  disabled={$unlockMut.isPending}
                >
                  Unlock
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>

  <!-- Sources -->
  <section class="sk-card">
    <header class="sk-card-header">
      <h2 class="sk-card-title">
        <RefreshCw size={14} aria-hidden="true" />
        Registry sources
      </h2>
      <div class="sk-card-actions">
        <button
          type="button"
          class="sk-btn"
          onclick={() => $refreshMut.mutate()}
          disabled={$refreshMut.isPending}
        >
          {$refreshMut.isPending ? "Refreshing…" : "Refresh all"}
        </button>
        {#if !addingSource}
          <button
            type="button"
            class="sk-btn sk-btn-primary"
            onclick={() => {
              resetSourceForm();
              addingSource = true;
            }}
          >
            <Plus size={14} aria-hidden="true" />
            Add source
          </button>
        {/if}
      </div>
    </header>

    {#if addingSource}
      <form class="sk-form" onsubmit={submitAddSource}>
        <div class="sk-grid">
          <label class="sk-field">
            <span class="sk-label">Name</span>
            <input
              type="text"
              class="sk-input"
              bind:value={formName}
              placeholder="my-registry"
              required
            />
          </label>
          <label class="sk-field">
            <span class="sk-label">URL</span>
            <input
              type="url"
              class="sk-input"
              bind:value={formUrl}
              placeholder="https://example.com/registry.json"
              required
            />
          </label>
          <label class="sk-field">
            <span class="sk-label">Kind</span>
            <input
              type="text"
              class="sk-input"
              bind:value={formKind}
              placeholder="generic"
            />
          </label>
        </div>

        {#if formError}
          <p class="sk-error">{formError}</p>
        {/if}

        <div class="sk-actions">
          <button
            type="button"
            class="sk-btn"
            onclick={() => {
              addingSource = false;
              resetSourceForm();
            }}
            disabled={$addSourceMut.isPending}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="sk-btn sk-btn-primary"
            disabled={$addSourceMut.isPending}
          >
            {$addSourceMut.isPending ? "Adding…" : "Add source"}
          </button>
        </div>
      </form>
    {/if}

    {#if $sourcesResult.isLoading}
      <p class="sk-empty">Loading…</p>
    {:else if sources.length === 0}
      <p class="sk-empty">
        No registry sources configured. Add one to let Atlas discover skills.
      </p>
    {:else}
      <ul class="sk-list">
        {#each sources as src (src.name)}
          <li class="sk-row">
            <div>
              <div class="sk-row-name">{src.name}</div>
              <div class="sk-row-meta">{src.url ?? "—"} · {src.kind}</div>
            </div>
            <span class="sk-row-meta">
              {src.lastSyncedAt ? `Synced ${src.lastSyncedAt}` : "Never synced"}
            </span>
          </li>
        {/each}
      </ul>
    {/if}
  </section>
</div>

<style>
  .sk-page {
    padding: 1rem 2rem;
    max-width: 1000px;
    color: var(--cnp-fg);
  }

  .sk-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 1.5rem;
  }

  .sk-title {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0;
  }

  .sk-sub {
    font-size: 0.85rem;
    color: var(--fg-muted);
    margin: 0.25rem 0 0;
  }

  .sk-card {
    background: var(--bg);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: 1rem 1.25rem;
    margin-bottom: 1rem;
  }

  .sk-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .sk-card-title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.95rem;
    font-weight: 600;
    margin: 0;
  }

  .sk-card-meta {
    font-size: 0.8rem;
    color: var(--fg-muted);
  }

  .sk-card-actions {
    display: flex;
    gap: 0.5rem;
  }

  .sk-atlas {
    background: color-mix(in oklch, oklch(0.72 0.14 80) 8%, transparent 92%);
    border-color: color-mix(in oklch, oklch(0.72 0.14 80) 30%, var(--border) 70%);
  }

  .sk-atlas-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .sk-atlas-emoji {
    font-size: 1.5rem;
  }

  .sk-atlas-body {
    flex: 1;
  }

  .sk-atlas-name {
    font-weight: 600;
  }

  .sk-atlas-meta {
    font-size: 0.8rem;
    color: var(--fg-muted);
  }

  .sk-atlas-link {
    font-size: 0.85rem;
    color: var(--cnp-accent);
    text-decoration: none;
  }

  .sk-atlas-link:hover {
    text-decoration: underline;
  }

  .sk-help {
    font-size: 0.85rem;
    color: var(--fg-muted);
    margin: 0 0 0.75rem;
  }

  .sk-policy {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.5rem;
  }

  .sk-policy-opt {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.75rem;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
    cursor: pointer;
    text-align: left;
    color: var(--cnp-fg);
  }

  .sk-policy-opt strong {
    font-size: 0.9rem;
  }

  .sk-policy-opt span {
    font-size: 0.8rem;
    color: var(--fg-muted);
  }

  .sk-policy-opt.active {
    border-color: oklch(0.72 0.14 80);
    background: color-mix(in oklch, oklch(0.72 0.14 80) 10%, var(--bg) 90%);
  }

  .sk-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .sk-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.75rem;
    padding: 0.5rem 0.75rem;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
  }

  .sk-row-name {
    font-weight: 500;
    font-size: 0.9rem;
  }

  .sk-row-meta {
    font-size: 0.8rem;
    color: var(--fg-muted);
  }

  .sk-row-slug {
    font-family: var(--font-mono);
    font-size: 0.85rem;
  }

  .sk-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .sk-table th {
    text-align: left;
    padding: 0.5rem;
    font-weight: 500;
    color: var(--fg-muted);
    border-bottom: 1px solid var(--border);
  }

  .sk-table td {
    padding: 0.5rem;
    border-bottom: 1px solid var(--border);
  }

  .sk-table code {
    font-family: var(--font-mono);
    font-size: 0.8rem;
  }

  .sk-empty {
    font-size: 0.85rem;
    color: var(--fg-muted);
    margin: 0;
  }

  .sk-form {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    padding-top: 0.5rem;
  }

  .sk-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.75rem;
  }

  .sk-field {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .sk-label {
    font-size: 0.75rem;
    color: var(--fg-muted);
  }

  .sk-input {
    padding: 0.4rem 0.5rem;
    font-size: 0.85rem;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
    color: var(--cnp-fg);
  }

  .sk-actions {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }

  .sk-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.75rem;
    font-size: 0.85rem;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
    color: var(--cnp-fg);
    cursor: pointer;
  }

  .sk-btn:hover:not(:disabled) {
    background: var(--bg-inset);
  }

  .sk-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .sk-btn-primary {
    background: oklch(0.72 0.14 80);
    color: oklch(0.15 0.02 80);
    border-color: oklch(0.72 0.14 80);
  }

  .sk-btn-ghost {
    background: transparent;
    color: var(--fg-muted);
  }

  .sk-error {
    color: oklch(0.62 0.18 25);
    font-size: 0.85rem;
    margin: 0;
  }

  .sk-local-badge {
    font-size: 0.7rem;
    font-style: italic;
    color: var(--fg-muted);
    opacity: 0.75;
  }
</style>
