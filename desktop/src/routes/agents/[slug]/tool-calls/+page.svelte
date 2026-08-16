<script lang="ts">
  /**
   * Agent tool-calls debug page — /agents/:slug/tool-calls
   *
   * Shows recent agent_tool_calls rows for this agent. Useful for verifying
   * orchestration tool invocations, reviewing governance-pending calls, and
   * debugging failed executions.
   *
   * Minimal page: read-only, auto-refreshes every 10 s.
   * Backend: GET /api/v1/agents/:slug/tool-calls
   */

  import { createQuery } from '@tanstack/svelte-query';
  import { page } from '$app/state';
  import { API_BASE } from '$lib/api/client.js';

  const slug = $derived(page.params.slug);

  type ToolCall = {
    id: string;
    session_id: string;
    agent_id: string;
    tool_name: string;
    params: Record<string, unknown>;
    result: Record<string, unknown> | null;
    status: 'ok' | 'error' | 'pending_review';
    error: string | null;
    review_id: string | null;
    inserted_at: string;
  };

  const toolCallsQuery = createQuery<{ data: ToolCall[] }>({
    queryKey: () => ['agent-tool-calls', slug],
    queryFn: async () => {
      const res = await fetch(`${API_BASE}/agents/${slug}/tool-calls?limit=50`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    },
    refetchInterval: 10_000,
  });

  const STATUS_BADGE: Record<string, string> = {
    ok: 'bg-emerald-500/15 text-emerald-400 border-emerald-500/30',
    error: 'bg-red-500/15 text-red-400 border-red-500/30',
    pending_review: 'bg-amber-500/15 text-amber-400 border-amber-500/30',
  };

  function formatTs(ts: string): string {
    return new Intl.DateTimeFormat('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    }).format(new Date(ts));
  }

  function truncate(s: string, n = 60): string {
    return s.length > n ? s.slice(0, n) + '…' : s;
  }
</script>

<div class="p-6 space-y-6">
  <!-- Header -->
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-lg font-semibold text-white">Tool Call Audit</h1>
      <p class="text-sm text-white/40 mt-0.5">
        Agent: <span class="text-white/70 font-mono">{slug}</span>
        · auto-refreshes every 10 s
      </p>
    </div>

    <a
      href="/agents/{slug}"
      class="text-sm text-white/40 hover:text-white/70 transition-colors"
    >
      ← Agent Detail
    </a>
  </div>

  <!-- Table -->
  {#if $toolCallsQuery.isLoading}
    <p class="text-sm text-white/40">Loading…</p>
  {:else if $toolCallsQuery.isError}
    <p class="text-sm text-red-400">Failed to load tool calls.</p>
  {:else}
    {@const calls = $toolCallsQuery.data?.data ?? []}

    {#if calls.length === 0}
      <div class="rounded-lg border border-white/8 p-8 text-center text-sm text-white/30">
        No tool calls recorded yet for this agent.
      </div>
    {:else}
      <div class="rounded-lg border border-white/8 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-white/8 bg-white/3">
              <th class="text-left px-4 py-2.5 text-white/40 font-medium">Tool</th>
              <th class="text-left px-4 py-2.5 text-white/40 font-medium">Status</th>
              <th class="text-left px-4 py-2.5 text-white/40 font-medium">Session</th>
              <th class="text-left px-4 py-2.5 text-white/40 font-medium">Result / Error</th>
              <th class="text-left px-4 py-2.5 text-white/40 font-medium">Time</th>
            </tr>
          </thead>
          <tbody>
            {#each calls as tc (tc.id)}
              <tr class="border-b border-white/5 hover:bg-white/2 transition-colors">
                <!-- Tool name -->
                <td class="px-4 py-3">
                  <span class="font-mono text-white/80 text-xs">{tc.tool_name}</span>
                </td>

                <!-- Status badge -->
                <td class="px-4 py-3">
                  <span
                    class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium border
                    {STATUS_BADGE[tc.status] ?? 'bg-white/10 text-white/50 border-white/10'}"
                  >
                    {tc.status}
                  </span>
                </td>

                <!-- Session ID (truncated) -->
                <td class="px-4 py-3">
                  <a
                    href="/sessions/{tc.session_id}"
                    class="font-mono text-xs text-white/40 hover:text-white/70 transition-colors"
                  >
                    {tc.session_id.slice(0, 8)}…
                  </a>
                </td>

                <!-- Result / Error -->
                <td class="px-4 py-3 max-w-xs">
                  {#if tc.error}
                    <span class="text-red-400 text-xs">{truncate(tc.error)}</span>
                  {:else if tc.review_id}
                    <a
                      href="/review?id={tc.review_id}"
                      class="text-amber-400 text-xs hover:underline"
                    >
                      review: {tc.review_id.slice(0, 8)}…
                    </a>
                  {:else if tc.result}
                    <span class="text-white/40 text-xs font-mono">
                      {truncate(JSON.stringify(tc.result))}
                    </span>
                  {:else}
                    <span class="text-white/20 text-xs">—</span>
                  {/if}
                </td>

                <!-- Timestamp -->
                <td class="px-4 py-3 text-xs text-white/30 whitespace-nowrap">
                  {formatTs(tc.inserted_at)}
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>

      <p class="text-xs text-white/20">
        Showing latest {calls.length} of up to 50 calls.
      </p>
    {/if}
  {/if}
</div>
