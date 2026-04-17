<script lang="ts">
	import { toast } from './toast.js';
	import Toast from './Toast.svelte';
</script>

<div class="bos-toaster" aria-label="Notifications">
	{#each $toast as item (item.id)}
		<Toast {item} />
	{/each}
</div>

<style>
	.bos-toaster {
		position: fixed;
		bottom: 24px;
		right: 24px;
		z-index: 9999;
		display: flex;
		flex-direction: column;
		gap: 8px;
		align-items: flex-end;
		pointer-events: none;
	}

	.bos-toaster :global(.bos-toast) {
		pointer-events: all;
	}
</style>
