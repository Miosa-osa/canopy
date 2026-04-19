<script lang="ts">
/**
 * /settings — redirects to /settings/appearance (default landing).
 * Uses SvelteKit's goto on mount so the layout renders before redirect.
 */
import { goto } from '$app/navigation';
import { onMount } from 'svelte';

onMount(() => {
  void goto('/settings/appearance', { replaceState: true });
});
</script>
