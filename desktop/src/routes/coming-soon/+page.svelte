<script lang="ts">
/**
 * Coming-soon placeholder — used by sidebar routes not yet built.
 * Week 1 scope: only Home, Agents, Runtimes, Sessions, Workspaces, Sandboxes.
 * All other routes (Inbox, Schedule, Chat, etc.) land here.
 */

import { Clock } from 'lucide-svelte';
import { goto } from '$app/navigation';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
</script>

<div class="coming-soon">
  <EmptyState
    icon={Clock}
    title="Coming in Week 2"
    body="This module is in progress. Check back soon — it ships next sprint."
    action="Back to Home"
    onAction={() => goto('/')}
  />
</div>

<style>
  .coming-soon {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
  }
</style>
