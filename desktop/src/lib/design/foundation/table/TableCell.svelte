<script lang="ts">
	/**
	 * TableCell Component - BusinessOS Style
	 * Table data cell with alignment and width control
	 */
	import { type Snippet } from 'svelte';

	type Align = 'left' | 'center' | 'right';

	interface Props {
		align?: Align;
		width?: string;
		header?: boolean;
		children: Snippet;
		class?: string;
	}

	let {
		align = 'left',
		width,
		header = false,
		children,
		class: className = ''
	}: Props = $props();
</script>

{#if header}
	<th
		class="bos-table-cell bos-table-cell--header {className}"
		data-align={align}
		style={width ? `width: ${width}` : undefined}
	>
		{@render children()}
	</th>
{:else}
	<td
		class="bos-table-cell {className}"
		data-align={align}
		style={width ? `width: ${width}` : undefined}
	>
		{@render children()}
	</td>
{/if}

<style>
	.bos-table-cell {
		padding: 10px 12px;
		font-size: 13px;
		color: var(--bos-v2-text-primary, #121212);
		vertical-align: middle;
	}

	.bos-table-cell--header {
		padding: 8px 12px;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #999;
		white-space: nowrap;
	}

	.bos-table-cell[data-align='left'] {
		text-align: left;
	}

	.bos-table-cell[data-align='center'] {
		text-align: center;
	}

	.bos-table-cell[data-align='right'] {
		text-align: right;
	}

	/* Dark mode */
	:global(.dark) .bos-table-cell {
		color: var(--bos-v2-text-primary, #e6e6e6);
	}

	:global(.dark) .bos-table-cell--header {
		color: #666;
	}
</style>
