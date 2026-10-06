<!-- src/lib/components/layout/ToastContainer.svelte -->
<script lang="ts">
  import { toastStore } from '$lib/stores/toasts.svelte';
  import ToastItem from './Toast.svelte';
</script>

<div
  class="tc-container"
  role="region"
  aria-label="Notifications"
>
  {#each toastStore.toasts as toast (toast.id)}
    <ToastItem {toast} />
  {/each}
</div>

<style>
  .tc-container {
    position: fixed;
    bottom: 20px;
    right: 20px;
    z-index: 600;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
    pointer-events: none;
  }
</style>
