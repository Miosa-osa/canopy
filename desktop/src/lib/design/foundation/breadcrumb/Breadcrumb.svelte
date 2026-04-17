<script lang="ts">
	/**
	 * Breadcrumb Component - BusinessOS Style
	 * Accessible path navigation with chevron or slash separators
	 */
	import { type Snippet } from 'svelte';

	type Separator = 'chevron' | 'slash';

	interface Props {
		separator?: Separator;
		class?: string;
		children: Snippet;
	}

	let {
		separator = 'chevron',
		class: className = '',
		children
	}: Props = $props();
</script>

<nav
	class="bos-breadcrumb {className}"
	aria-label="Breadcrumb"
	data-separator={separator}
>
	<ol class="bos-breadcrumb__list">
		{@render children()}
	</ol>
</nav>

<style>
	.bos-breadcrumb {
		display: flex;
		align-items: center;
	}

	.bos-breadcrumb__list {
		display: flex;
		align-items: center;
		list-style: none;
		margin: 0;
		padding: 0;
		gap: 0;
		flex-wrap: wrap;
	}

	/* Separator via CSS for chevron */
	.bos-breadcrumb[data-separator='chevron'] :global(.bos-breadcrumb-item + .bos-breadcrumb-item::before) {
		content: '';
		display: inline-block;
		width: 14px;
		height: 14px;
		background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' stroke='%23ccc' viewBox='0 0 24 24'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 5l7 7-7 7'/%3E%3C/svg%3E");
		background-size: contain;
		background-repeat: no-repeat;
		background-position: center;
		margin: 0 2px;
		vertical-align: middle;
		flex-shrink: 0;
	}

	.bos-breadcrumb[data-separator='slash'] :global(.bos-breadcrumb-item + .bos-breadcrumb-item::before) {
		content: '/';
		font-size: 13px;
		color: #ddd;
		margin: 0 6px;
		user-select: none;
	}
</style>
