<script lang="ts">
  import { goto } from '$app/navigation';
  import { onMount } from 'svelte';

  onMount(() => {
    void goto('/home', { replaceState: true });
  });
</script>

<!-- Placeholder while redirect fires — invisible in practice -->
<div aria-hidden="true"></div>
