<script lang="ts">
  /**
   * Settings › Build — Build cockpit configuration.
   *   • Default layout picker (per workspace)
   *   • Density default
   *   • Pane title format
   *   • Conductor autonomy bound (auto-open vs ask vs manual)
   *   • Saved layouts list with edit + archive
   *   • "Reset Build to factory defaults" button
   */
  import {
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { RotateCcw, Trash2 } from "lucide-svelte";
  import {
    archiveLayout,
    layoutsQuery,
    setDefaultLayout,
    updateLayout,
  } from "$lib/api/queries/build.js";
  import type {
    BuildLayout,
    ConductorAutonomy,
    Density,
    PaneTitleFormat,
  } from "$lib/domain/build/types.js";

  const qc = useQueryClient();
  const layoutsResult = createQuery(layoutsQuery({ includeArchived: false }));

  const layouts = $derived<BuildLayout[]>(
    ($layoutsResult.data ?? []) as BuildLayout[],
  );

  // ── Local UI state (preferences live in localStorage; not persisted to API) ──

  const LS_KEY = "canopy.build.settings";

  interface BuildSettings {
    workspaceSlug: string;
    defaultSlug: string;
    density: Density;
    paneTitleFormat: PaneTitleFormat;
    autonomy: ConductorAutonomy;
  }

  const FACTORY: BuildSettings = {
    workspaceSlug: "default",
    defaultSlug: "",
    density: "comfortable",
    paneTitleFormat: "command",
    autonomy: "ask_first",
  };

  let settings = $state<BuildSettings>(loadSettings());

  function loadSettings(): BuildSettings {
    if (typeof localStorage === "undefined") return { ...FACTORY };
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (!raw) return { ...FACTORY };
      return { ...FACTORY, ...(JSON.parse(raw) as Partial<BuildSettings>) };
    } catch {
      return { ...FACTORY };
    }
  }

  function persist(): void {
    try {
      localStorage.setItem(LS_KEY, JSON.stringify(settings));
    } catch {
      // ignore quota errors
    }
  }

  function resetToFactory(): void {
    settings = { ...FACTORY };
    persist();
  }

  // ── Mutations ───────────────────────────────────────────────────────────────

  const setDefaultMut = createMutation({
    mutationFn: ({ slug, ws }: { slug: string; ws: string }) =>
      setDefaultLayout(slug, ws),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["build"] });
    },
  });

  const updateMut = createMutation({
    mutationFn: ({
      slug,
      patch,
    }: {
      slug: string;
      patch: { density?: Density; paneTitleFormat?: PaneTitleFormat };
    }) => updateLayout(slug, patch),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["build", "layouts"] });
    },
  });

  const archiveMut = createMutation({
    mutationFn: (slug: string) => archiveLayout(slug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["build", "layouts"] });
    },
  });

  function applyAsDefault(slug: string): void {
    settings.defaultSlug = slug;
    persist();
    if (settings.workspaceSlug) {
      $setDefaultMut.mutate({ slug, ws: settings.workspaceSlug });
    }
  }

  function fmt(d: string | null): string {
    return d ? new Date(d).toLocaleString() : "never";
  }
</script>

<div class="sb-page">
  <header class="sb-header">
    <div>
      <h1 class="sb-title">Build</h1>
      <p class="sb-sub">
        Cockpit configuration · Conductor autonomy · saved layouts
      </p>
    </div>
    <button type="button" class="sb-btn-ghost" onclick={resetToFactory}>
      <RotateCcw size={14} aria-hidden="true" />
      Reset to factory defaults
    </button>
  </header>

  <!-- Conductor agent card -->
  <section class="sb-card sb-conductor">
    <div class="sb-cond-row">
      <span class="sb-cond-emoji" aria-hidden="true">🎼</span>
      <div class="sb-cond-body">
        <div class="sb-cond-name">Conductor</div>
        <div class="sb-cond-meta">
          Cockpit orchestrator · event-only heartbeat · escalates to user
        </div>
      </div>
      <a href="/agents/conductor" class="sb-cond-link">View persona</a>
    </div>
  </section>

  <!-- Cockpit defaults -->
  <section class="sb-card">
    <h2 class="sb-section-title">Cockpit defaults</h2>
    <div class="sb-grid">
      <label class="sb-field">
        <span class="sb-label">Workspace</span>
        <input
          type="text"
          class="sb-input"
          bind:value={settings.workspaceSlug}
          onblur={persist}
          placeholder="default"
        />
      </label>

      <label class="sb-field">
        <span class="sb-label">Default layout</span>
        <select
          class="sb-input"
          bind:value={settings.defaultSlug}
          onchange={(e) => {
            const slug = (e.currentTarget as HTMLSelectElement).value;
            if (slug) applyAsDefault(slug);
          }}
        >
          <option value="">— none —</option>
          {#each layouts as l (l.slug)}
            <option value={l.slug}>{l.name} ({l.scope})</option>
          {/each}
        </select>
      </label>

      <label class="sb-field">
        <span class="sb-label">Density</span>
        <select
          class="sb-input"
          bind:value={settings.density}
          onchange={persist}
        >
          <option value="compact">Compact</option>
          <option value="comfortable">Comfortable</option>
          <option value="roomy">Roomy</option>
        </select>
      </label>

      <label class="sb-field">
        <span class="sb-label">Pane title format</span>
        <select
          class="sb-input"
          bind:value={settings.paneTitleFormat}
          onchange={persist}
        >
          <option value="command">Command</option>
          <option value="cwd">Working directory</option>
          <option value="branch">Git branch</option>
        </select>
      </label>
    </div>
  </section>

  <!-- Conductor autonomy -->
  <section class="sb-card">
    <h2 class="sb-section-title">Conductor autonomy</h2>
    <p class="sb-help">
      Controls when Conductor opens panes on its own vs asks first.
    </p>
    <fieldset class="sb-radio-group">
      <label class="sb-radio">
        <input
          type="radio"
          name="autonomy"
          value="auto_open"
          checked={settings.autonomy === "auto_open"}
          onchange={() => {
            settings.autonomy = "auto_open";
            persist();
          }}
        />
        <span>
          <strong>Auto-open</strong> — Conductor opens suggested panes
          immediately. Best for solo deep-work.
        </span>
      </label>
      <label class="sb-radio">
        <input
          type="radio"
          name="autonomy"
          value="ask_first"
          checked={settings.autonomy === "ask_first"}
          onchange={() => {
            settings.autonomy = "ask_first";
            persist();
          }}
        />
        <span>
          <strong>Ask first</strong> — Conductor proposes a layout, waits
          for confirmation. Recommended.
        </span>
      </label>
      <label class="sb-radio">
        <input
          type="radio"
          name="autonomy"
          value="manual_only"
          checked={settings.autonomy === "manual_only"}
          onchange={() => {
            settings.autonomy = "manual_only";
            persist();
          }}
        />
        <span>
          <strong>Manual only</strong> — Conductor surfaces suggestions in
          chat; you drive every pane operation.
        </span>
      </label>
    </fieldset>
  </section>

  <!-- Saved layouts -->
  <section class="sb-card">
    <h2 class="sb-section-title">Saved layouts</h2>
    {#if layouts.length === 0}
      <p class="sb-empty">
        No saved layouts yet. Use Conductor's <code>build.save_layout</code> to
        capture the current cockpit state.
      </p>
    {:else}
      <table class="sb-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Scope</th>
            <th>Workspace</th>
            <th>Uses</th>
            <th>Last used</th>
            <th aria-label="Actions"></th>
          </tr>
        </thead>
        <tbody>
          {#each layouts as l (l.slug)}
            <tr>
              <td>
                <div class="sb-row-name">{l.name}</div>
                <div class="sb-row-slug"><code>{l.slug}</code></div>
              </td>
              <td>{l.scope}</td>
              <td>{l.workspaceSlug ?? "—"}</td>
              <td>{l.useCount}</td>
              <td>{fmt(l.lastUsedAt)}</td>
              <td class="sb-row-actions">
                <button
                  type="button"
                  class="sb-row-btn"
                  title="Archive layout"
                  onclick={() => $archiveMut.mutate(l.slug)}
                >
                  <Trash2 size={14} aria-hidden="true" />
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>
</div>

<style>
  .sb-page {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 16px 20px;
    max-width: 880px;
  }

  .sb-header {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 12px;
  }

  .sb-title {
    font-size: 18px;
    font-weight: 600;
    margin: 0;
  }

  .sb-sub {
    color: var(--text-muted, #666);
    font-size: 13px;
    margin: 4px 0 0 0;
  }

  .sb-btn-ghost {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 10px;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.12));
    border-radius: 6px;
    font-size: 12px;
    background: transparent;
    cursor: pointer;
  }

  .sb-card {
    border: 1px solid var(--border, rgba(0, 0, 0, 0.08));
    border-radius: 8px;
    padding: 16px;
    background: var(--surface, #fff);
  }

  .sb-section-title {
    font-size: 14px;
    font-weight: 600;
    margin: 0 0 12px 0;
  }

  .sb-help {
    color: var(--text-muted, #666);
    font-size: 12px;
    margin: 0 0 10px 0;
  }

  .sb-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
  }

  .sb-field {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .sb-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-muted, #555);
  }

  .sb-input {
    padding: 6px 8px;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.12));
    border-radius: 6px;
    font-size: 13px;
    background: var(--input-bg, #fff);
  }

  .sb-radio-group {
    border: 0;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .sb-radio {
    display: flex;
    align-items: flex-start;
    gap: 8px;
    font-size: 13px;
    cursor: pointer;
  }

  .sb-conductor {
    background: var(--surface, #fff);
  }

  .sb-cond-row {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .sb-cond-emoji {
    font-size: 24px;
  }

  .sb-cond-body {
    flex: 1;
  }

  .sb-cond-name {
    font-weight: 600;
    font-size: 14px;
  }

  .sb-cond-meta {
    color: var(--text-muted, #666);
    font-size: 12px;
  }

  .sb-cond-link {
    font-size: 12px;
    color: var(--accent, #0a66c2);
    text-decoration: none;
  }

  .sb-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }

  .sb-table th,
  .sb-table td {
    text-align: left;
    padding: 8px 6px;
    border-bottom: 1px solid var(--border, rgba(0, 0, 0, 0.06));
  }

  .sb-row-name {
    font-weight: 500;
  }

  .sb-row-slug {
    color: var(--text-muted, #888);
    font-size: 11px;
  }

  .sb-row-actions {
    text-align: right;
  }

  .sb-row-btn {
    background: transparent;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.12));
    border-radius: 4px;
    padding: 4px 6px;
    cursor: pointer;
  }

  .sb-empty {
    color: var(--text-muted, #666);
    font-size: 13px;
    margin: 0;
  }
</style>
