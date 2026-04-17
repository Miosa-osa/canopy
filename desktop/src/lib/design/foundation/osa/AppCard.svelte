<!--
	AppCard.svelte
	iOS-style app card with circular icon and glassmorphism.

	Usage:
	<AppCard
		title="Book Finds"
		description="Discover books..."
		iconFallback="B"
		usagePercentage={98}
		onclick={handleClick}
	/>
-->
<script lang="ts">
	import type { Snippet } from 'svelte';

	interface Props {
		title: string;
		description?: string;
		iconUrl?: string;
		iconFallback?: string;
		usagePercentage?: number;
		onclick?: (e: MouseEvent) => void;
		class?: string;
		children?: Snippet;
	}

	let {
		title,
		description,
		iconUrl,
		iconFallback,
		usagePercentage,
		onclick,
		class: className = '',
		children
	}: Props = $props();

	const firstLetter = title.charAt(0).toUpperCase();
</script>

<div
	class="osa-app-card {className}"
	role="button"
	tabindex="0"
	{onclick}
	onkeypress={(e) => e.key === 'Enter' && onclick?.(e as any)}
>
	{#if usagePercentage !== undefined}
		<div class="osa-app-card__usage">{usagePercentage}%</div>
	{/if}

	<div class="osa-app-card__icon">
		{#if iconUrl}
			<img src={iconUrl} alt={title} />
		{:else}
			<span class="osa-app-card__letter">{iconFallback || firstLetter}</span>
		{/if}
	</div>

	<div class="osa-app-card__title">{title}</div>

	{#if description}
		<div class="osa-app-card__desc">{description}</div>
	{/if}

	{#if children}
		{@render children()}
	{/if}
</div>

<style>
	.osa-app-card {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		padding: 20px 16px;
		background: var(--dbg2);
		border: 1px solid var(--dbd);
		border-radius: 16px;
		cursor: pointer;
		transition: transform 0.2s ease, box-shadow 0.2s ease;
		position: relative;
		text-align: center;
	}
	.osa-app-card:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.08);
	}
	.osa-app-card__usage {
		position: absolute;
		top: 8px;
		right: 8px;
		font-size: 0.6875rem;
		font-weight: 600;
		color: var(--dt3);
		background: var(--dbg3);
		padding: 2px 8px;
		border-radius: 9999px;
	}
	.osa-app-card__icon {
		width: 56px;
		height: 56px;
		border-radius: 14px;
		background: linear-gradient(135deg, #333, #111);
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
	}
	.osa-app-card__icon img {
		width: 100%;
		height: 100%;
		object-fit: cover;
	}
	.osa-app-card__letter {
		color: #fff;
		font-size: 1.5rem;
		font-weight: 700;
	}
	.osa-app-card__title {
		font-size: 0.8125rem;
		font-weight: 600;
		color: var(--dt);
	}
	.osa-app-card__desc {
		font-size: 0.75rem;
		color: var(--dt3);
		line-height: 1.4;
		max-width: 140px;
	}
</style>
