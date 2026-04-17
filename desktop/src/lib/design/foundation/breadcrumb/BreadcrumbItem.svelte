<script lang="ts">
	/**
	 * BreadcrumbItem Component - BusinessOS Style
	 * Individual breadcrumb item — link or current page label
	 */
	import { type Snippet } from 'svelte';

	interface Props {
		href?: string;
		current?: boolean;
		children: Snippet;
	}

	let {
		href,
		current = false,
		children
	}: Props = $props();
</script>

<li class="bos-breadcrumb-item">
	{#if current}
		<span
			class="bos-breadcrumb-item__current"
			aria-current="page"
		>
			{@render children()}
		</span>
	{:else if href}
		<a
			{href}
			class="bos-breadcrumb-item__link"
		>
			{@render children()}
		</a>
	{:else}
		<span class="bos-breadcrumb-item__text">
			{@render children()}
		</span>
	{/if}
</li>

<style>
	.bos-breadcrumb-item {
		display: flex;
		align-items: center;
		font-size: 13px;
		font-family: var(--bos-font-family);
	}

	.bos-breadcrumb-item__link {
		color: #999;
		text-decoration: none;
		padding: 2px 4px;
		border-radius: 4px;
		transition: color 0.12s, background-color 0.12s;
		white-space: nowrap;
	}

	.bos-breadcrumb-item__link:hover {
		color: #333;
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	.bos-breadcrumb-item__current {
		font-weight: 600;
		color: #111;
		padding: 2px 4px;
		white-space: nowrap;
	}

	.bos-breadcrumb-item__text {
		color: #999;
		padding: 2px 4px;
		white-space: nowrap;
	}

	/* Dark mode */
	:global(.dark) .bos-breadcrumb-item__link {
		color: #666;
	}

	:global(.dark) .bos-breadcrumb-item__link:hover {
		color: #bbb;
	}

	:global(.dark) .bos-breadcrumb-item__current {
		color: #e6e6e6;
	}

	:global(.dark) .bos-breadcrumb-item__text {
		color: #666;
	}
</style>
