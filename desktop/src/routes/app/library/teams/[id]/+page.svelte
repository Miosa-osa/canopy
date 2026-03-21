<!-- src/routes/app/library/teams/[id]/+page.svelte -->
<script lang="ts">
  import { page } from '$app/state';
  import { goto } from '$app/navigation';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import {
    getLibraryTeamDetail,
    type LibraryTemplate,
  } from '$lib/api/mock/library';
  import { deployTemplate } from '$lib/services/template-deploy';
  import { toastStore } from '$lib/stores/toasts.svelte';

  const id = $derived(page.params.id ?? '');
  const team = $derived<LibraryTemplate | null>(id ? getLibraryTeamDetail(id) : null);

  let deploying = $state(false);
  let deployed = $state(false);

  async function handleDeploy() {
    if (!team || deploying) return;
    deploying = true;
    try {
      const result = await deployTemplate(team.id, team.name);
      if (result.success) {
        deployed = true;
        toastStore.success(
          `${team.emoji} ${team.name} deployed`,
          `${result.agentCount} agents provisioned.`,
        );
        goto('/app');
      } else {
        toastStore.error('Deploy failed', result.error ?? 'Unknown error');
      }
    } catch (e) {
      toastStore.error('Deploy failed', (e as Error).message);
    } finally {
      deploying = false;
    }
  }

  function formatNumber(n: number): string {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
    return String(n);
  }

  function sizeColor(size: string): string {
    switch (size.toLowerCase()) {
      case 'small':  return 'rgba(34, 197, 94, 0.6)';
      case 'medium': return '#60a5fa';
      case 'large':  return '#a78bfa';
      case 'xl':
      case 'enterprise': return '#f472b6';
      default: return '#94a3b8';
    }
  }
</script>

<svelte:head>
  <title>{team ? `${team.name} — Library — Canopy` : 'Team — Library — Canopy'}</title>
</svelte:head>

<PageShell title={team?.name ?? 'Team'} subtitle={team ? team.size : undefined}>
  {#if !team}
    <div class="ldt-not-found" role="main">
      <span class="ldt-not-found-icon" aria-hidden="true">🔍</span>
      <p class="ldt-not-found-text">Team template not found.</p>
      <button
        class="ldt-back-btn"
        onclick={() => goto('/app/library')}
        aria-label="Go back to library"
      >
        ← Back to library
      </button>
    </div>
  {:else}
    <div class="ldt-page">

      <!-- Top bar -->
      <div class="ldt-topbar">
        <button
          class="ldt-back"
          onclick={() => goto('/app/library')}
          aria-label="Back to library"
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Library
        </button>
        <span class="ldt-breadcrumb-sep" aria-hidden="true">/</span>
        <span class="ldt-breadcrumb-cur">Teams</span>
      </div>

      <!-- Two-column layout -->
      <div class="ldt-layout">

        <!-- LEFT: content -->
        <div class="ldt-main">

          <!-- Hero -->
          <div class="ldt-hero">
            <span class="ldt-hero-emoji" aria-hidden="true">{team.emoji}</span>
            <div class="ldt-hero-meta">
              <div class="ldt-hero-badges">
                {#if team.isOfficial}
                  <span class="ldt-badge ldt-badge--official" aria-label="Official team">Official</span>
                {/if}
                <span
                  class="ldt-badge ldt-badge--size"
                  style="
                    background: {sizeColor(team.size)}1a;
                    border-color: {sizeColor(team.size)}40;
                    color: {sizeColor(team.size)};
                  "
                  aria-label="Size: {team.size}"
                >{team.size}</span>
              </div>
              <h1 class="ldt-hero-name">{team.name}</h1>
            </div>
          </div>

          <!-- Description -->
          <section class="ldt-card" aria-label="Team description">
            <h2 class="ldt-card-title">About</h2>
            <p class="ldt-description">{team.description}</p>
          </section>

          <!-- Team composition -->
          <section class="ldt-card" aria-label="Team composition">
            <h2 class="ldt-card-title">Composition</h2>
            <div class="ldt-composition">
              <div class="ldt-comp-item">
                <div class="ldt-comp-icon" aria-hidden="true">🤖</div>
                <div class="ldt-comp-count">{team.agent_count}</div>
                <div class="ldt-comp-label">Agents</div>
              </div>
            </div>
          </section>

          <!-- Stats grid -->
          <section class="ldt-card" aria-label="Team statistics">
            <h2 class="ldt-card-title">Stats</h2>
            <div class="ldt-stats-grid" role="list">
              <div class="ldt-stat" role="listitem">
                <span class="ldt-stat-icon" aria-hidden="true">⬇</span>
                <span class="ldt-stat-value">{formatNumber(team.downloads)}</span>
                <span class="ldt-stat-label">Downloads</span>
              </div>
              <div class="ldt-stat" role="listitem">
                <span class="ldt-stat-icon" aria-hidden="true">★</span>
                <span class="ldt-stat-value">{formatNumber(team.favorites)}</span>
                <span class="ldt-stat-label">Favorites</span>
              </div>
              <div class="ldt-stat" role="listitem">
                <span class="ldt-stat-icon" aria-hidden="true">⑂</span>
                <span class="ldt-stat-value">{formatNumber(team.forks)}</span>
                <span class="ldt-stat-label">Forks</span>
              </div>
              <div class="ldt-stat" role="listitem">
                <span class="ldt-stat-icon" aria-hidden="true">v</span>
                <span class="ldt-stat-value">{team.version}</span>
                <span class="ldt-stat-label">Version</span>
              </div>
            </div>
          </section>

          <!-- Tags -->
          {#if team.tags.length > 0}
            <section class="ldt-card" aria-label="Team tags">
              <h2 class="ldt-card-title">Tags</h2>
              <div class="ldt-tags" role="list" aria-label="Tags">
                {#each team.tags as tag}
                  <span class="ldt-tag" role="listitem">{tag}</span>
                {/each}
              </div>
            </section>
          {/if}

        </div>

        <!-- RIGHT: Configuration panel -->
        <aside class="ldt-sidebar" aria-label="Configuration panel">
          <div class="ldt-panel">
            <h2 class="ldt-panel-title">Deploy Team</h2>

            <div class="ldt-panel-info">
              <p class="ldt-panel-desc">
                Deploying this team will spin up {team.agent_count}
                {team.agent_count === 1 ? 'agent' : 'agents'} in your workspace,
                each pre-configured with the roles and settings defined in this template.
              </p>
            </div>

            <div class="ldt-panel-meta">
              <div class="ldt-meta-row">
                <span class="ldt-meta-label">Agents</span>
                <span class="ldt-meta-value">{team.agent_count}</span>
              </div>
              <div class="ldt-meta-row">
                <span class="ldt-meta-label">Size</span>
                <span class="ldt-meta-value" style="color: {sizeColor(team.size)}">{team.size}</span>
              </div>
              <div class="ldt-meta-row">
                <span class="ldt-meta-label">Version</span>
                <span class="ldt-meta-value">{team.version}</span>
              </div>
            </div>

            <button
              class="ldt-deploy-btn"
              class:ldt-deploy-btn--loading={deploying}
              onclick={handleDeploy}
              disabled={deploying || deployed}
              aria-label="Deploy {team.name} team"
            >
              {#if deployed}
                Deployed
              {:else if deploying}
                Deploying...
              {:else}
                Deploy Team
              {/if}
            </button>
          </div>
        </aside>

      </div>
    </div>
  {/if}
</PageShell>

<style>
  /* Not found */
  .ldt-not-found {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 12px;
    height: 100%;
    color: var(--text-tertiary);
    font-size: 13px;
  }

  .ldt-not-found-icon {
    font-size: 40px;
    opacity: 0.4;
  }

  .ldt-not-found-text {
    margin: 0;
  }

  .ldt-back-btn {
    height: 32px;
    padding: 0 14px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
    background: transparent;
    color: var(--text-secondary);
    font-size: 13px;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .ldt-back-btn:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  /* Page wrapper */
  .ldt-page {
    display: flex;
    flex-direction: column;
    gap: 0;
    min-height: 100%;
  }

  /* Top bar */
  .ldt-topbar {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 16px 24px 0;
  }

  .ldt-back {
    display: flex;
    align-items: center;
    gap: 6px;
    height: 28px;
    padding: 0 10px;
    border-radius: var(--radius-xs);
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-tertiary);
    font-size: 12px;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .ldt-back:hover {
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-primary);
  }

  .ldt-breadcrumb-sep {
    color: var(--text-muted);
    font-size: 12px;
  }

  .ldt-breadcrumb-cur {
    font-size: 12px;
    color: var(--text-secondary);
  }

  /* Two-column layout */
  .ldt-layout {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 24px;
    padding: 24px;
    align-items: start;
  }

  .ldt-main {
    display: flex;
    flex-direction: column;
    gap: 16px;
    min-width: 0;
  }

  /* Hero */
  .ldt-hero {
    display: flex;
    align-items: flex-start;
    gap: 20px;
  }

  .ldt-hero-emoji {
    font-size: 56px;
    line-height: 1;
    flex-shrink: 0;
  }

  .ldt-hero-meta {
    display: flex;
    flex-direction: column;
    gap: 6px;
    min-width: 0;
    padding-top: 4px;
  }

  .ldt-hero-badges {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .ldt-hero-name {
    font-size: 24px;
    font-weight: 700;
    color: var(--text-primary);
    margin: 0;
    line-height: 1.2;
  }

  /* Badges */
  .ldt-badge {
    display: inline-flex;
    align-items: center;
    height: 20px;
    padding: 0 8px;
    border-radius: 10px;
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.2px;
    white-space: nowrap;
    border: 1px solid transparent;
  }

  .ldt-badge--official {
    background: rgba(251, 191, 36, 0.15);
    border-color: rgba(251, 191, 36, 0.3);
    color: #fbbf24;
  }

  .ldt-badge--size {
    text-transform: capitalize;
  }

  /* Cards */
  .ldt-card {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 16px;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
  }

  .ldt-card-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: var(--text-tertiary);
    margin: 0 0 12px 0;
  }

  .ldt-description {
    font-size: 14px;
    line-height: 1.6;
    color: var(--text-secondary);
    margin: 0;
  }

  /* Team composition */
  .ldt-composition {
    display: flex;
    gap: 16px;
  }

  .ldt-comp-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 16px 24px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
    min-width: 100px;
  }

  .ldt-comp-icon {
    font-size: 24px;
  }

  .ldt-comp-count {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .ldt-comp-label {
    font-size: 12px;
    color: var(--text-muted);
  }

  /* Stats grid */
  .ldt-stats-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }

  .ldt-stat {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 12px 8px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm);
  }

  .ldt-stat-icon {
    font-size: 16px;
    color: var(--text-muted);
  }

  .ldt-stat-value {
    font-size: 18px;
    font-weight: 700;
    color: var(--text-primary);
    font-variant-numeric: tabular-nums;
    line-height: 1;
  }

  .ldt-stat-label {
    font-size: 11px;
    color: var(--text-muted);
    text-align: center;
  }

  /* Tags */
  .ldt-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .ldt-tag {
    display: inline-flex;
    align-items: center;
    height: 24px;
    padding: 0 10px;
    border-radius: var(--radius-xs);
    background: rgba(52, 211, 153, 0.08);
    border: 1px solid rgba(52, 211, 153, 0.2);
    font-size: 12px;
    color: #6ee7b7;
    font-family: var(--font-mono);
  }

  /* Sidebar */
  .ldt-sidebar {
    position: sticky;
    top: 24px;
  }

  .ldt-panel {
    background: var(--bg-surface);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-md);
    padding: 20px;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .ldt-panel-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .ldt-panel-info {
    padding: 12px;
    background: var(--bg-secondary);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
  }

  .ldt-panel-desc {
    font-size: 12px;
    line-height: 1.6;
    color: var(--text-tertiary);
    margin: 0;
  }

  .ldt-panel-meta {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 12px;
    background: var(--bg-secondary);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-default);
  }

  .ldt-meta-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
  }

  .ldt-meta-label {
    font-size: 11px;
    color: var(--text-muted);
    flex-shrink: 0;
  }

  .ldt-meta-value {
    font-size: 12px;
    color: var(--text-secondary);
    text-align: right;
    text-transform: capitalize;
  }

  .ldt-deploy-btn {
    height: 38px;
    width: 100%;
    border-radius: var(--radius-sm);
    border: 1px solid rgba(52, 211, 153, 0.3);
    background: rgba(52, 211, 153, 0.12);
    color: #6ee7b7;
    font-size: 13px;
    font-weight: 600;
    font-family: var(--font-sans);
    cursor: pointer;
    transition: all 120ms ease;
  }

  .ldt-deploy-btn:hover {
    background: rgba(52, 211, 153, 0.12);
    border-color: rgba(52, 211, 153, 0.3);
    color: #6ee7b7;
  }

  .ldt-deploy-btn:active:not(:disabled) {
    background: rgba(52, 211, 153, 0.28);
  }

  .ldt-deploy-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .ldt-deploy-btn--loading {
    cursor: wait;
  }
</style>
