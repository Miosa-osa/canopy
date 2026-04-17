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

	const isClickable = onclick !== undefined;
</script>

<div
	class="glass-card {className}"
	class:osa-glass--hoverable={hoverable || isClickable}
	style:padding={paddingMap[padding]}
	role={isClickable ? 'button' : undefined}
	tabindex={isClickable ? 0 : undefined}
	{onclick}
	onkeypress={(e) => e.key === 'Enter' && isClickable && onclick?.(e as any)}
>
	{#if children}
		{@render children()}
	{/if}
</div>

<style>
	.osa-glass--hoverable {
		cursor: pointer;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}
	.osa-glass--hoverable:hover {
		transform: translateY(-1px);
		box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
	}
</style>
