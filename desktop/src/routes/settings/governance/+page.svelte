<script lang="ts">
/**
 * Settings › Governance — redirect to the full governance route.
 * Governance is a first-class route at /governance, not a settings sub-page.
 */

import { onMount } from 'svelte';
import { goto } from '$app/navigation';

onMount(() => {
  void goto('/governance', { replaceState: true });
});
</script>
