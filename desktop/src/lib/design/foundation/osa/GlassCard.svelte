<!--
	GlassCard.svelte
	Glassmorphism card component using Foundation's .glass-card CSS.

	Usage:
	<GlassCard padding="lg" hoverable>
		<h2>Card Content</h2>
	</GlassCard>
-->
<script lang="ts">
	import type { Snippet } from 'svelte';

	type PaddingSize = 'none' | 'sm' | 'md' | 'lg' | 'xl';

	interface Props {
		padding?: PaddingSize;
		hoverable?: boolean;
		onclick?: (e: MouseEvent) => void;
		class?: string;
		children?: Snippet;
	}

	let {
		padding = 'md',
		hoverable = false,
		onclick,
		class: className = '',
		children
	}: Props = $props();

	const paddingMap: Record<PaddingSize, string> = {
		none: '0',
		sm: '12px',
		md: '24px',
		lg: '32px',
		xl: '48px'
	};

	// Canopy fix: $derived() keeps reactivity if onclick prop changes after mount.
	// Render as <button> when clickable — avoids a11y_no_noninteractive_tabindex on <div>.
	const isClickable = $derived(onclick !== undefined);
</script>

{#if isClickable}
	<button
		type="button"
		class="glass-card {className}"
		class:osa-glass--hoverable={hoverable || isClickable}
		style:padding={paddingMap[padding]}
		{onclick}
	>
		{#if children}
			{@render children()}
		{/if}
	</button>
{:else}
	<div
		class="glass-card {className}"
		class:osa-glass--hoverable={hoverable}
		style:padding={paddingMap[padding]}
	>
		{#if children}
			{@render children()}
		{/if}
	</div>
{/if}

<style>
	/* When GlassCard renders as <button>, strip native button chrome */
	button.glass-card {
		appearance: none;
		font-family: inherit;
		font-size: inherit;
		text-align: inherit;
		width: 100%;
	}
	.osa-glass--hoverable {
		cursor: pointer;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}
	.osa-glass--hoverable:hover {
		transform: translateY(-1px);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
	}
</style>
