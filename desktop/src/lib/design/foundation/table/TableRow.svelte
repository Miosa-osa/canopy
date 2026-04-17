<script lang="ts">
	/**
	 * TableRow Component - BusinessOS Style
	 * Table row with hover and stripe support
	 */
	import { type Snippet } from 'svelte';

	interface Props {
		children: Snippet;
		class?: string;
	}

	let {
		children,
		class: className = ''
	}: Props = $props();
</script>

<tr class="bos-table-row {className}">
	{@render children()}
</tr>

<style>
	.bos-table-row {
		border-bottom: 1px solid rgba(0, 0, 0, 0.04);
		transition: background-color 0.1s;
	}

	.bos-table-row:last-child {
		border-bottom: none;
	}

	/* Dark mode */
	:global(.dark) .bos-table-row {
		border-bottom-color: rgba(255, 255, 255, 0.04);
	}
</style>
