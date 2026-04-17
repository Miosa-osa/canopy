<script lang="ts">
	/**
	 * TableHeader Component - BusinessOS Style
	 * Styled thead with uppercase column labels
	 */
	import { type Snippet } from 'svelte';

	interface Props {
		children: Snippet;
	}

	let { children }: Props = $props();
</script>

<thead class="bos-table-header">
	{@render children()}
</thead>

<style>
	.bos-table-header :global(tr) {
		border-bottom: 1px solid rgba(0, 0, 0, 0.08);
	}

	.bos-table-header :global(th) {
		padding: 8px 12px;
		text-align: left;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: #999;
		white-space: nowrap;
	}

	/* Dark mode */
	:global(.dark) .bos-table-header :global(tr) {
		border-bottom-color: rgba(255, 255, 255, 0.08);
	}

	:global(.dark) .bos-table-header :global(th) {
		color: #666;
	}
</style>
