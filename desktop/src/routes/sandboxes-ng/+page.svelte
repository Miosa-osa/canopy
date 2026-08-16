<script lang="ts">
  /**
   * /sandboxes-ng — Sandboxes super-module dashboard.
   * Powered by the Sandbox Operator agent via /api/v1/sandboxes-ng/*.
   *
   * Sections:
   *   1. 8-state lifecycle status grid (count per state)
   *   2. Sandbox cards — current state of every sandbox
   *   3. Ports tab — port forwards with visibility tier + URL
   *   4. Snapshot timeline — kind, retention, lineage
   *   5. Operator activity feed — recent lifecycle events
   *
   * CSS prefix: sn-
   */
  import {
    type CreateQueryOptions,
    createQuery,
  } from "@tanstack/svelte-query";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import {
    Activity,
    Box,
    Camera,
    Globe,
    Lock,
    Network,
    Pause,
    Play,
    PowerOff,
    Settings,
    ShieldAlert,
    Snowflake,
  } from "lucide-svelte";
  import {
    eventsQuery,
    portsQuery,
    sandboxStatesQuery,
    snapshotsQuery,
  } from "$lib/api/queries/sandboxes_ng.js";
  import {
    SANDBOX_STATE_ORDER,
    type LifecycleEvent,
    type PortForward,
    type PortVisibility,
    type SandboxState,
    type SandboxStateRow,
    type Snapshot,
  } from "$lib/domain/sandboxes_ng/types.js";

  // ── Queries ────────────────────────────────────────────────────────────────

  const statesStore = writable(
    untrack(
      () =>
        sandboxStatesQuery() as CreateQueryOptions<SandboxStateRow[]>,
    ),
  );
  const statesQ = createQuery<SandboxStateRow[]>(statesStore);

  const portsStore = writable(
    untrack(
      () =>
        portsQuery({ openOnly: true, limit: 200 }) as CreateQueryOptions<
          PortForward[]
        >,
    ),
  );
  const portsQ = createQuery<PortForward[]>(portsStore);

  const snapshotsStore = writable(
    untrack(
      () =>
        snapshotsQuery({
          activeOnly: true,
          limit: 50,
        }) as CreateQueryOptions<Snapshot[]>,
    ),
  );
  const snapshotsQ = createQuery<Snapshot[]>(snapshotsStore);

  const eventsStore = writable(
    untrack(
      () =>
        eventsQuery({ limit: 25 }) as CreateQueryOptions<LifecycleEvent[]>,
    ),
  );
  const eventsQ = createQuery<LifecycleEvent[]>(eventsStore);

  // ── Tabs ───────────────────────────────────────────────────────────────────

  type TabKey = "overview" | "ports" | "snapshots" | "events";
  let activeTab = $state<TabKey>("overview");

  // ── Derived: state grid ────────────────────────────────────────────────────

  const states = $derived($statesQ.data ?? []);
  const liveStates = $derived(
    states.filter((s) => s.state !== "destroyed"),
  );

  const stateCounts = $derived.by(() => {
    const counts: Record<SandboxState, number> = {
      provisioning: 0,
      running: 0,
      paused: 0,
      snapshotting: 0,
      resizing: 0,
      archived: 0,
      error: 0,
      destroyed: 0,
    };
    for (const row of states) {
      counts[row.state] += 1;
    }
    return counts;
  });

  // ── Derived: ports ─────────────────────────────────────────────────────────

  const ports = $derived($portsQ.data ?? []);
  const publicPorts = $derived(
    ports.filter((p) => p.visibility === "public"),
  );

  // ── Derived: snapshots ─────────────────────────────────────────────────────

  const snapshots = $derived($snapshotsQ.data ?? []);

  // ── Derived: events ────────────────────────────────────────────────────────

  const events = $derived($eventsQ.data ?? []);

  // ── Helpers ────────────────────────────────────────────────────────────────

  const STATE_ICON: Record<SandboxState, typeof Box> = {
    provisioning: Box,
    running: Play,
    paused: Pause,
    snapshotting: Camera,
    resizing: Settings,
    archived: Snowflake,
    error: ShieldAlert,
    destroyed: PowerOff,
  };

  function fmtRelative(iso: string): string {
    const ms = Date.now() - new Date(iso).getTime();
    const s = Math.floor(ms / 1000);
    if (s < 60) return `${s}s ago`;
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  }

  function fmtBytes(n: number | null): string {
    if (n === null) return "—";
    if (n < 1024) return `${n} B`;
    if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KiB`;
    if (n < 1024 * 1024 * 1024) return `${(n / 1024 / 1024).toFixed(1)} MiB`;
    return `${(n / 1024 / 1024 / 1024).toFixed(2)} GiB`;
  }

  function visibilityIcon(v: PortVisibility) {
    if (v === "public") return Globe;
    if (v === "token") return Network;
    return Lock;
  }

  const isLoading = $derived(
    $statesQ.isLoading || $portsQ.isLoading || $snapshotsQ.isLoading,
  );
</script>

<div class="sn-page">
  <header class="sn-header">
    <div class="sn-header-left">
      <h1 class="sn-title">Sandboxes</h1>
      <span class="sn-subtitle">
        Powered by the Sandbox Operator
        {#if liveStates.length > 0}
          · {liveStates.length} active
        {/if}
        {#if publicPorts.length > 0}
          · <span class="sn-badge sn-badge-warn">{publicPorts.length} public ports</span>
        {/if}
      </span>
    </div>
    <a href="/settings/sandboxes" class="sn-settings-link">
      <Settings size={14} aria-hidden="true" />
      Settings
    </a>
  </header>

  <!-- 8-state status grid -->
  <section class="sn-status-grid" aria-label="Lifecycle state distribution">
    {#each SANDBOX_STATE_ORDER as state (state)}
      {@const Icon = STATE_ICON[state]}
      <div class="sn-status-tile" data-state={state}>
        <div class="sn-status-tile__icon">
          <Icon size={14} aria-hidden="true" />
        </div>
        <div class="sn-status-tile__body">
          <span class="sn-status-tile__label">{state}</span>
          <span class="sn-status-tile__value">{stateCounts[state]}</span>
        </div>
      </div>
    {/each}
  </section>

  <!-- Tab switcher -->
  <nav class="sn-tabs" aria-label="Sandbox sections">
    <button
      type="button"
      class="sn-tab"
      class:sn-tab--active={activeTab === "overview"}
      onclick={() => (activeTab = "overview")}
    >
      Overview
    </button>
    <button
      type="button"
      class="sn-tab"
      class:sn-tab--active={activeTab === "ports"}
      onclick={() => (activeTab = "ports")}
    >
      Ports ({ports.length})
    </button>
    <button
      type="button"
      class="sn-tab"
      class:sn-tab--active={activeTab === "snapshots"}
      onclick={() => (activeTab = "snapshots")}
    >
      Snapshots ({snapshots.length})
    </button>
    <button
      type="button"
      class="sn-tab"
      class:sn-tab--active={activeTab === "events"}
      onclick={() => (activeTab = "events")}
    >
      Operator activity
    </button>
  </nav>

  {#if isLoading}
    <div class="sn-loading">Loading sandbox data…</div>
  {:else if activeTab === "overview"}
    <!-- Sandbox cards -->
    <section class="sn-section" aria-labelledby="sn-overview-label">
      <header class="sn-section-header">
        <h2 class="sn-section-title" id="sn-overview-label">
          <Box size={14} aria-hidden="true" />
          Sandboxes
        </h2>
        <span class="sn-section-meta">{liveStates.length} live</span>
      </header>

      {#if liveStates.length === 0}
        <p class="sn-empty">
          No live sandboxes. The Sandbox Operator provisions VMs on agent
          request — none have been requested yet.
        </p>
      {:else}
        <ul class="sn-card-list" role="list">
          {#each liveStates as row (row.sandboxId)}
            {@const Icon = STATE_ICON[row.state]}
            <li class="sn-card" data-state={row.state}>
              <div class="sn-card-row">
                <div class="sn-card-state">
                  <Icon size={14} aria-hidden="true" />
                  <span>{row.state}</span>
                </div>
                <span class="sn-card-time">{fmtRelative(row.ts)}</span>
              </div>
              <div class="sn-card-id">{row.sandboxId}</div>
              {#if row.workspaceSlug}
                <div class="sn-card-meta">workspace: {row.workspaceSlug}</div>
              {/if}
              {#if row.ownerAgentId}
                <div class="sn-card-meta">owner: {row.ownerAgentId}</div>
              {/if}
              {#if row.reason}
                <div class="sn-card-reason">{row.reason}</div>
              {/if}
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {:else if activeTab === "ports"}
    <!-- Ports tab -->
    <section class="sn-section" aria-labelledby="sn-ports-label">
      <header class="sn-section-header">
        <h2 class="sn-section-title" id="sn-ports-label">
          <Network size={14} aria-hidden="true" />
          Port forwards
        </h2>
        <span class="sn-section-meta">{ports.length} open</span>
      </header>

      {#if ports.length === 0}
        <p class="sn-empty">
          No open port forwards. Agents call <code>sandbox.expose_port</code> to
          surface ports; public exposure requires explicit confirmation.
        </p>
      {:else}
        <table class="sn-port-table">
          <thead>
            <tr>
              <th>Port</th>
              <th>Sandbox</th>
              <th>Protocol</th>
              <th>Visibility</th>
              <th>URL</th>
              <th>Process</th>
              <th>Opened by</th>
            </tr>
          </thead>
          <tbody>
            {#each ports as p (p.id)}
              {@const VIcon = visibilityIcon(p.visibility)}
              <tr>
                <td class="sn-port-num">{p.internalPort}</td>
                <td>{p.sandboxId}</td>
                <td>{p.protocol}</td>
                <td>
                  <span class="sn-visibility sn-visibility--{p.visibility}">
                    <VIcon size={11} aria-hidden="true" />
                    {p.visibility}
                  </span>
                </td>
                <td>
                  {#if p.externalUrl}
                    <a class="sn-port-url" href={p.externalUrl} target="_blank" rel="noopener">
                      {p.externalUrl}
                    </a>
                  {:else if p.tcpEndpoint}
                    <code>{p.tcpEndpoint}</code>
                  {:else}
                    <span class="sn-muted">—</span>
                  {/if}
                </td>
                <td>{p.processName ?? p.label ?? "—"}</td>
                <td>
                  {#if p.openedByAgentId}
                    <span class="sn-agent">{p.openedByAgentId}</span>
                  {:else}
                    <span class="sn-muted">—</span>
                  {/if}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      {/if}
    </section>
  {:else if activeTab === "snapshots"}
    <!-- Snapshot timeline -->
    <section class="sn-section" aria-labelledby="sn-snap-label">
      <header class="sn-section-header">
        <h2 class="sn-section-title" id="sn-snap-label">
          <Camera size={14} aria-hidden="true" />
          Snapshots
        </h2>
        <span class="sn-section-meta">{snapshots.length} active</span>
      </header>

      {#if snapshots.length === 0}
        <p class="sn-empty">
          No snapshots taken. Snapshots come in three kinds: filesystem
          (indefinite), directory (30d), memory (7d).
        </p>
      {:else}
        <ul class="sn-snap-list" role="list">
          {#each snapshots as s (s.id)}
            <li class="sn-snap-row">
              <div class="sn-snap-kind sn-snap-kind--{s.kind}">{s.kind}</div>
              <div class="sn-snap-body">
                <div class="sn-snap-name">{s.name ?? s.slug}</div>
                <div class="sn-snap-meta">
                  <span>{s.sandboxId}</span>
                  <span>·</span>
                  <span>{fmtBytes(s.sizeBytes)}</span>
                  <span>·</span>
                  <span>created {fmtRelative(s.insertedAt)}</span>
                  {#if s.retentionUntil}
                    <span>·</span>
                    <span class="sn-snap-retention">
                      expires {fmtRelative(s.retentionUntil)}
                    </span>
                  {:else}
                    <span>·</span>
                    <span class="sn-snap-retention">indefinite</span>
                  {/if}
                </div>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
  {:else if activeTab === "events"}
    <!-- Operator activity feed -->
    <section class="sn-section" aria-labelledby="sn-events-label">
      <header class="sn-section-header">
        <h2 class="sn-section-title" id="sn-events-label">
          <Activity size={14} aria-hidden="true" />
          Sandbox Operator activity
        </h2>
        <span class="sn-section-meta">last 25 events</span>
      </header>

      {#if events.length === 0}
        <p class="sn-empty">
          No lifecycle events yet. The operator records every state
          transition: provision, pause, resume, snapshot, archive, destroy.
        </p>
      {:else}
        <ol class="sn-event-list" role="list">
          {#each events as e (e.id)}
            <li class="sn-event">
              <div class="sn-event-row">
                <span class="sn-event-state sn-event-state--{e.state}">
                  {e.state}
                </span>
                {#if e.priorState}
                  <span class="sn-muted">← {e.priorState}</span>
                {/if}
                <span class="sn-event-time">{fmtRelative(e.ts)}</span>
              </div>
              <div class="sn-event-id">{e.sandboxId}</div>
              {#if e.reason}
                <div class="sn-event-reason">{e.reason}</div>
              {/if}
            </li>
          {/each}
        </ol>
      {/if}
    </section>
  {/if}
</div>

<style>
  .sn-page {
    padding: 1.5rem 2rem 4rem;
    max-width: 1200px;
    margin: 0 auto;
    color: var(--cnp-fg);
  }

  .sn-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .sn-header-left {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .sn-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 2rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0;
  }

  .sn-subtitle {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .sn-badge {
    color: var(--cnp-accent);
    font-weight: 500;
  }

  .sn-badge-warn {
    color: #d97706;
  }

  .sn-settings-link {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.75rem;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    color: var(--cnp-fg-muted);
    text-decoration: none;
    font-size: 0.8rem;
  }

  .sn-settings-link:hover {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .sn-status-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
    gap: 0.5rem;
    margin-bottom: 1.5rem;
  }

  .sn-status-tile {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.6rem 0.85rem;
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    font-size: 0.8rem;
  }

  .sn-status-tile__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--cnp-fg-muted);
  }

  .sn-status-tile__body {
    display: flex;
    flex-direction: column;
    gap: 0.05rem;
    min-width: 0;
  }

  .sn-status-tile__label {
    font-size: 0.65rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sn-status-tile__value {
    font-size: 1.1rem;
    font-weight: 500;
    font-feature-settings: "tnum";
  }

  .sn-status-tile[data-state="running"] .sn-status-tile__icon {
    color: oklch(0.65 0.18 250);
  }

  .sn-status-tile[data-state="error"] .sn-status-tile__icon {
    color: #dc2626;
  }

  .sn-status-tile[data-state="paused"] .sn-status-tile__icon {
    color: #d97706;
  }

  .sn-tabs {
    display: flex;
    gap: 0.25rem;
    border-bottom: 1px solid var(--cnp-border);
    margin-bottom: 1rem;
  }

  .sn-tab {
    background: transparent;
    border: none;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    font-family: inherit;
    padding: 0.5rem 0.85rem;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -1px;
  }

  .sn-tab:hover:not(.sn-tab--active) {
    color: var(--cnp-fg);
  }

  .sn-tab--active {
    color: var(--cnp-fg);
    border-bottom-color: oklch(0.65 0.18 250);
  }

  .sn-loading {
    padding: 2rem 0;
    color: var(--cnp-fg-muted);
    text-align: center;
    font-size: 0.85rem;
  }

  .sn-section {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
  }

  .sn-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .sn-section-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .sn-section-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .sn-empty {
    padding: 1rem 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .sn-empty code {
    font-family: var(--cnp-font-mono, monospace);
    background: var(--cnp-bg);
    padding: 0.05rem 0.3rem;
    border-radius: 3px;
  }

  .sn-card-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 0.5rem;
  }

  .sn-card {
    padding: 0.75rem 1rem;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    background: var(--cnp-bg);
  }

  .sn-card[data-state="error"] {
    border-color: color-mix(in oklch, #dc2626 30%, var(--cnp-border));
  }

  .sn-card[data-state="paused"] {
    border-color: color-mix(in oklch, #d97706 25%, var(--cnp-border));
  }

  .sn-card-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.4rem;
    align-items: center;
  }

  .sn-card-state {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sn-card-time {
    font-size: 0.7rem;
    color: var(--cnp-fg-muted);
  }

  .sn-card-id {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.85rem;
    margin-bottom: 0.2rem;
  }

  .sn-card-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
  }

  .sn-card-reason {
    color: var(--cnp-fg-muted);
    font-size: 0.7rem;
    margin-top: 0.3rem;
    font-style: italic;
  }

  .sn-port-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .sn-port-table th {
    text-align: left;
    font-weight: 500;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .sn-port-table td {
    padding: 0.55rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
    vertical-align: middle;
  }

  .sn-port-num {
    font-family: var(--cnp-font-mono, monospace);
    font-weight: 500;
  }

  .sn-port-url {
    color: oklch(0.65 0.18 250);
    text-decoration: none;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.75rem;
  }

  .sn-port-url:hover {
    text-decoration: underline;
  }

  .sn-visibility {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.1rem 0.4rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
  }

  .sn-visibility--private {
    color: #16a34a;
    border-color: color-mix(in oklch, #16a34a 30%, var(--cnp-border));
  }

  .sn-visibility--token {
    color: #d97706;
    border-color: color-mix(in oklch, #d97706 30%, var(--cnp-border));
  }

  .sn-visibility--public {
    color: #dc2626;
    border-color: color-mix(in oklch, #dc2626 50%, var(--cnp-border));
    background: color-mix(in oklch, #dc2626 8%, transparent);
  }

  .sn-muted {
    color: var(--cnp-fg-muted);
  }

  .sn-agent {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.75rem;
  }

  .sn-snap-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .sn-snap-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.65rem 1rem;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    background: var(--cnp-bg);
  }

  .sn-snap-kind {
    padding: 0.15rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
    font-family: var(--cnp-font-mono, monospace);
  }

  .sn-snap-kind--filesystem {
    color: oklch(0.65 0.18 250);
    border-color: color-mix(in oklch, oklch(0.65 0.18 250) 30%, var(--cnp-border));
  }

  .sn-snap-kind--directory {
    color: oklch(0.62 0.16 165);
    border-color: color-mix(in oklch, oklch(0.62 0.16 165) 30%, var(--cnp-border));
  }

  .sn-snap-kind--memory {
    color: #d97706;
    border-color: color-mix(in oklch, #d97706 30%, var(--cnp-border));
  }

  .sn-snap-body {
    flex: 1;
    min-width: 0;
  }

  .sn-snap-name {
    font-size: 0.85rem;
    font-weight: 500;
  }

  .sn-snap-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.7rem;
    display: flex;
    gap: 0.3rem;
    flex-wrap: wrap;
  }

  .sn-snap-retention {
    font-feature-settings: "tnum";
  }

  .sn-event-list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .sn-event {
    padding: 0.6rem 0.85rem;
    border: 1px solid var(--cnp-border);
    border-left-width: 3px;
    border-radius: 4px;
    background: var(--cnp-bg);
  }

  .sn-event-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.2rem;
    font-size: 0.75rem;
  }

  .sn-event-state {
    text-transform: uppercase;
    letter-spacing: 0.04em;
    font-weight: 500;
    font-size: 0.7rem;
  }

  .sn-event-state--running {
    color: oklch(0.65 0.18 250);
  }

  .sn-event-state--error {
    color: #dc2626;
  }

  .sn-event-state--paused {
    color: #d97706;
  }

  .sn-event-state--destroyed {
    color: var(--cnp-fg-muted);
  }

  .sn-event-time {
    color: var(--cnp-fg-muted);
    margin-left: auto;
  }

  .sn-event-id {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.8rem;
  }

  .sn-event-reason {
    color: var(--cnp-fg-muted);
    font-size: 0.7rem;
    margin-top: 0.2rem;
  }
</style>
