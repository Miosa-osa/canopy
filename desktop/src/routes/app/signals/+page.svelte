<!-- src/routes/app/signals/+page.svelte -->
<script lang="ts">
  import { onMount } from 'svelte';
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import { signalsStore } from '$lib/stores/signals.svelte';

  onMount(() => {
    void signalsStore.fetchAll(100);
  });
</script>

<PageShell title="Signals" badge={signalsStore.totalCount > 0 ? signalsStore.totalCount : undefined}>
  {#snippet actions()}
    <input
      class="sig-search"
      type="search"
      placeholder="Search signals…"
      value={signalsStore.searchQuery}
      oninput={(e) => signalsStore.setSearch((e.target as HTMLInputElement).value)}
      aria-label="Search signals"
    />
  {/snippet}

  <!-- Stats row -->
  {#if signalsStore.stats}
    {@const s = signalsStore.stats}
    <section class="sig-stats" aria-label="Signal statistics">
      <div class="sig-stat-card">
        <span class="sig-stat-value">{s.total}</span>
        <span class="sig-stat-label">Total ({s.period_hours}h)</span>
      </div>
      <div class="sig-stat-card">
        <span class="sig-stat-value">{s.avg_weight.toFixed(2)}</span>
        <span class="sig-stat-label">Avg Weight</span>
      </div>
      <div class="sig-stat-card">
        <span class="sig-stat-value sig-stat-value--warn">{s.failure_count}</span>
        <span class="sig-stat-label">Failures</span>
      </div>
      {#each Object.entries(s.by_tier) as [tier, count] (tier)}
        <div class="sig-stat-card">
          <span class="sig-stat-value">{count}</span>
          <span class="sig-stat-label sig-tier-label sig-tier-label--{tier}">{tier}</span>
        </div>
      {/each}
    </section>
  {:else if signalsStore.statsLoading}
    <div class="sig-stats-skeleton" aria-hidden="true">
      {#each { length: 5 } as _, i (i)}<div class="sig-stat-card sig-stat-card--skeleton"></div>{/each}
    </div>
  {/if}

  <!-- Patterns section -->
  {#if signalsStore.patterns.length > 0}
    <section class="sig-patterns" aria-label="Signal patterns">
      <h2 class="sig-section-title">Top Patterns</h2>
      <div class="sig-pattern-grid" role="list">
        {#each signalsStore.patterns as pattern (pattern.pattern)}
          <div class="sig-pattern-card" role="listitem">
            <div class="sig-pattern-header">
              <span class="sig-pattern-name">{pattern.pattern}</span>
              <span class="sig-pattern-count">{pattern.count}</span>
            </div>
            <div class="sig-pattern-meta">
              <span class="sig-pattern-weight">avg {pattern.avg_weight.toFixed(2)}</span>
              {#if pattern.failure_rate > 0}
                <span class="sig-pattern-fail">{Math.round(pattern.failure_rate * 100)}% fail</span>
              {/if}
              <span class="sig-pattern-channels">{pattern.channels.join(', ')}</span>
            </div>
          </div>
        {/each}
      </div>
    </section>
  {:else if signalsStore.patternsLoading}
    <div class="sig-patterns-skeleton" aria-hidden="true">
      {#each { length: 3 } as _, i (i)}<div class="sig-pattern-card sig-pattern-card--skeleton"></div>{/each}
    </div>
  {/if}

  <!-- Feed -->
  <section aria-label="Signal feed">
    <h2 class="sig-section-title">Feed</h2>

    {#if signalsStore.loading && signalsStore.signals.length === 0}
      <div class="sig-loading" role="status" aria-live="polite">
        <div class="sig-spinner" aria-hidden="true"></div>
        <span>Loading signals…</span>
      </div>
    {:else if signalsStore.error && signalsStore.signals.length === 0}
      <div class="sig-error" role="alert">
        <p>Failed to load signals: {signalsStore.error}</p>
        <button onclick={() => void signalsStore.fetchAll(100)}>Retry</button>
      </div>
    {:else if signalsStore.filteredSignals.length === 0}
      <div class="sig-empty" role="status">
        <p>{signalsStore.searchQuery ? 'No signals match your search.' : 'No signals recorded yet.'}</p>
      </div>
    {:else}
      <div class="sig-list" role="list" aria-label="Signal events">
        {#each signalsStore.filteredSignals as signal (signal.id)}
          <div class="sig-row" role="listitem">
            <div class="sig-meta">
              <span class="sig-channel">{signal.channel}</span>
              <span class="sig-mode">{signal.mode}</span>
              <span class="sig-tier sig-tier--{signal.tier}">{signal.tier}</span>
            </div>
            <div class="sig-preview">{signal.input_preview}</div>
            <div class="sig-footer">
              <span class="sig-agent">{signal.agent_name}</span>
              <span class="sig-weight">weight: {signal.weight.toFixed(2)}</span>
              {#if signal.failure_mode}
                <span class="sig-fail">{signal.failure_mode}</span>
              {/if}
              <span class="sig-time">{new Date(signal.created_at).toLocaleString()}</span>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </section>
</PageShell>

<style>
  .sig-search {
    height: 28px; padding: 0 10px; border-radius: 6px; font-size: 12px;
    background: var(--dbg2); border: 1px solid var(--dbd); color: var(--dt); min-width: 200px;
  }
  .sig-search:focus { outline: none; border-color: #6366f1; }

  /* Stats */
  .sig-stats, .sig-stats-skeleton {
    display: flex; flex-wrap: wrap; gap: 10px; padding: 16px 24px 0;
  }
  .sig-stat-card {
    display: flex; flex-direction: column; align-items: center; gap: 4px;
    padding: 10px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd); min-width: 80px;
  }
  .sig-stat-card--skeleton {
    height: 52px; min-width: 80px;
    background: linear-gradient(90deg, var(--dbg2) 0%, var(--dbg3) 50%, var(--dbg2) 100%);
    background-size: 200% 100%;
    animation: sig-shimmer 1.4s ease-in-out infinite;
  }
  @keyframes sig-shimmer { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
  .sig-stat-value { font-size: 20px; font-weight: 700; color: var(--dt); font-variant-numeric: tabular-nums; line-height: 1; }
  .sig-stat-value--warn { color: #fca5a5; }
  .sig-stat-label { font-size: 10px; color: var(--dt3); text-transform: uppercase; letter-spacing: 0.04em; }
  .sig-tier-label--haiku { color: var(--dt3); }
  .sig-tier-label--sonnet { color: #fde047; }
  .sig-tier-label--opus { color: #c4b5fd; }

  /* Patterns */
  .sig-section-title {
    font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.04em;
    color: var(--dt3); margin: 0 0 10px; padding: 16px 24px 0;
  }
  .sig-patterns { padding-bottom: 0; }
  .sig-pattern-grid, .sig-patterns-skeleton {
    display: flex; flex-wrap: wrap; gap: 8px; padding: 0 24px;
  }
  .sig-pattern-card {
    padding: 10px 14px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
    min-width: 180px; flex: 1 1 180px; max-width: 300px;
  }
  .sig-pattern-card--skeleton {
    height: 52px; min-width: 180px; flex: 1 1 180px; max-width: 300px;
    background: linear-gradient(90deg, var(--dbg2) 0%, var(--dbg3) 50%, var(--dbg2) 100%);
    background-size: 200% 100%;
    animation: sig-shimmer 1.4s ease-in-out infinite;
  }
  .sig-pattern-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 5px; }
  .sig-pattern-name { font-size: 12px; font-weight: 600; color: var(--dt); }
  .sig-pattern-count {
    font-size: 11px; font-weight: 700; font-variant-numeric: tabular-nums;
    padding: 1px 6px; border-radius: 4px; background: var(--dbg3); color: var(--dt2);
  }
  .sig-pattern-meta { display: flex; gap: 8px; flex-wrap: wrap; }
  .sig-pattern-weight { font-size: 11px; color: var(--dt3); font-family: var(--font-mono, monospace); }
  .sig-pattern-fail { font-size: 11px; color: #fca5a5; }
  .sig-pattern-channels { font-size: 11px; color: var(--dt4); }

  /* Feed */
  .sig-loading, .sig-empty, .sig-error {
    display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 12px; height: 200px;
    color: var(--dt3); font-size: 13px;
  }
  .sig-spinner {
    width: 24px; height: 24px; border-radius: 50%;
    border: 2px solid var(--dbd); border-top-color: var(--dt2);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }
  .sig-list { display: flex; flex-direction: column; gap: 8px; padding: 8px 24px 24px; }
  .sig-row {
    padding: 12px 16px; border-radius: 8px;
    background: var(--dbg2); border: 1px solid var(--dbd);
  }
  .sig-meta { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
  .sig-channel { font-size: 12px; font-weight: 500; color: var(--dt2); }
  .sig-mode { font-size: 11px; color: var(--dt3); }
  .sig-tier {
    font-size: 10px; font-weight: 600; padding: 1px 6px; border-radius: 4px;
    text-transform: uppercase; letter-spacing: 0.05em;
  }
  .sig-tier--opus { background: color-mix(in srgb, #8b5cf6 15%, transparent); color: #c4b5fd; }
  .sig-tier--sonnet { background: color-mix(in srgb, #f59e0b 15%, transparent); color: #fde047; }
  .sig-tier--haiku { background: var(--dbg3); color: var(--dt3); }
  .sig-preview { font-size: 12px; color: var(--dt); margin-bottom: 8px; line-height: 1.5; }
  .sig-footer { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; }
  .sig-agent { font-size: 11px; color: var(--dt3); }
  .sig-weight { font-size: 11px; color: var(--dt4); font-family: var(--font-mono, monospace); }
  .sig-fail { font-size: 11px; color: #fca5a5; }
  .sig-time { font-size: 11px; color: var(--dt4); margin-left: auto; }
</style>
