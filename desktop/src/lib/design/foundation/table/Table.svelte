<script lang="ts">
	/**
	 * Table Component - BusinessOS Style
	 * Clean monochrome data table
	 */
	import { type Snippet } from 'svelte';

	interface Props {
		striped?: boolean;
		hoverable?: boolean;
		compact?: boolean;
		class?: string;
		children: Snippet;
	}

	let {
		striped = false,
		hoverable = false,
		compact = false,
		class: className = '',
		children
	}: Props = $props();
</script>

<div class="bos-table-wrapper">
	<table
		class="bos-table {className}"
		data-striped={striped || undefined}
		data-hoverable={hoverable || undefined}
		data-compact={compact || undefined}
	>
		{@render children()}
	</table>
</div>

<style>
	.bos-table-wrapper {
		width: 100%;
		overflow-x: auto;
	}

	.bos-table {
		width: 100%;
		border-collapse: collapse;
		font-size: var(--bos-font-sm, 14px);
		font-family: var(--bos-font-family);
		color: var(--bos-v2-text-primary, #121212);
	}

	/* Hoverable rows */
	.bos-table[data-hoverable] :global(tbody tr:hover) {
		background-color: rgba(0, 0, 0, 0.02);
	}

	/* Striped rows */
	.bos-table[data-striped] :global(tbody tr:nth-child(even)) {
		background-color: rgba(0, 0, 0, 0.02);
	}

	/* Compact */
	.bos-table[data-compact] :global(th),
	.bos-table[data-compact] :global(td) {
		padding: 6px 10px;
		font-size: 12px;
	}

	/* Dark mode */
	:global(.dark) .bos-table {
		color: var(--bos-v2-text-primary, #e6e6e6);
	}

	:global(.dark) .bos-table[data-hoverable] :global(tbody tr:hover) {
		background-color: rgba(255, 255, 255, 0.03);
	}

	:global(.dark) .bos-table[data-striped] :global(tbody tr:nth-child(even)) {
		background-color: rgba(255, 255, 255, 0.02);
	}
</style>
