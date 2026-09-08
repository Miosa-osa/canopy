<script lang="ts">
import { onMount } from 'svelte';
import { goto } from '$app/navigation';

onMount(() => {
  void goto('/home', { replaceState: true });
});
</script>

<!-- Placeholder while redirect fires — invisible in practice -->
<div aria-hidden="true"></div>
