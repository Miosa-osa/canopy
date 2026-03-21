<!-- src/routes/app/inbox/+page.svelte -->
<script lang="ts">
  import PageShell from '$lib/components/layout/PageShell.svelte';
  import InboxFilters from '$lib/components/inbox/InboxFilters.svelte';
  import InboxFeed from '$lib/components/inbox/InboxFeed.svelte';
  import { inboxStore } from '$lib/stores/inbox.svelte';
  import { workspaceStore } from '$lib/stores/workspace.svelte';

  // Re-fetch whenever the active workspace changes (covers onMount + workspace switches)
  $effect(() => {
    void workspaceStore.activeWorkspaceId;
    void inboxStore.fetchItems();
  });
</script>

<PageShell
  title="Inbox"
  badge={inboxStore.unreadCount > 0 ? inboxStore.unreadCount : undefined}
>
  <div class="inp-content">
    <InboxFilters />
    <InboxFeed />
  </div>
</PageShell>

<style>
  .inp-content {
    height: 100%;
    display: flex;
    flex-direction: column;
    min-height: 0;
  }
</style>
