<script lang="ts">
import { createQuery } from '@tanstack/svelte-query';
import { Activity, Bot, Clock } from 'lucide-svelte';
import { hiredAgentsQuery } from '$lib/api/queries/agents.js';
import { specsQuery } from '$lib/api/queries/schedule.js';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import type { Agent } from '$lib/domain/agents/types.js';
import type { Session } from '$lib/domain/sessions/types.js';

const agentsQ = createQuery(hiredAgentsQuery());
const sessionsQ = createQuery({ ...sessionsQuery({}), refetchInterval: 10_000 });
const specsQ = createQuery(specsQuery({ status: 'active' }));

const agentCount = $derived(($agentsQ.data as Agent[] | undefined)?.length ?? 0);
const runningSessions = $derived(
  (($sessionsQ.data as Session[] | undefined) ?? []).filter((s) => s.status === 'running')
);
const runningCount = $derived(runningSessions.length);
const scheduledCount = $derived(($specsQ.data as unknown[] | undefined)?.length ?? 0);
const anyRunning = $derived(runningCount > 0);

interface Stat {
  label: string;
  count: number;
  color: string;
  pulse: boolean;
}

const stats = $derived<Stat[]>([
  { label: 'agents', count: agentCount, color: 'var(--cnp-accent, #6366f1)', pulse: false },
  { label: 'running', count: runningCount, color: '#22c55e', pulse: anyRunning },
  { label: 'scheduled', count: scheduledCount, color: '#f59e0b', pulse: false },
]);
</script>

<div class="ws-row" role="status" aria-label="Workspace stats">
  {#each stats as stat, i (stat.label)}
    <div class="ws-pill">
      <span class="ws-dot" class:ws-dot--pulse={stat.pulse} style="background: {stat.color}" aria-hidden="true"></span>
      <span class="ws-count">{stat.count}</span>
      <span class="ws-label">{stat.label}</span>
    </div>
  {/each}
</div>

<style>
  .ws-row {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    flex-wrap: wrap;
  }

  .ws-pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 10px;
    border-radius: var(--radius-sm, 6px);
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border: 1px solid color-mix(in oklch, var(--border) 60%, transparent);
    font-family: var(--font-sans);
  }

  .ws-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .ws-dot--pulse {
    animation: ws-pulse 1.5s ease-in-out infinite;
  }

  @keyframes ws-pulse {
    0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(34, 197, 94, 0.35); }
    50%      { opacity: 0.7; box-shadow: 0 0 0 4px rgba(34, 197, 94, 0); }
  }

  .ws-count {
    font-family: var(--font-mono);
    font-size: 12px;
    font-weight: 600;
    color: var(--fg);
    font-variant-numeric: tabular-nums;
  }

  .ws-label {
    font-size: 11px;
    color: var(--fg-muted);
  }

  @media (prefers-reduced-motion: reduce) {
    .ws-dot--pulse { animation: none; }
  }
</style>
