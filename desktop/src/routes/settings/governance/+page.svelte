<script lang="ts">
/**
 * Settings › Governance — redirect to the full governance route.
 * Governance is a first-class route at /governance, not a settings sub-page.
 */
import { goto } from '$app/navigation';
import { onMount } from 'svelte';

onMount(() => {
  void goto('/governance', { replaceState: true });
});
</script>
