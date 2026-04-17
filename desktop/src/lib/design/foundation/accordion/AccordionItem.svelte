<script lang="ts">
	import { getContext, type Snippet } from 'svelte';
	import { slide } from 'svelte/transition';
	import { cubicOut } from 'svelte/easing';

	interface AccordionContext {
		isOpen: (value: string) => boolean;
		toggle: (value: string) => void;
	}

	interface Props {
		value: string;
		title: string;
		disabled?: boolean;
		class?: string;
		children?: Snippet;
	}

	let {
		value,
		title,
		disabled = false,
		class: className = '',
		children
	}: Props = $props();

	const ctx = getContext<AccordionContext>('accordion');

	let open = $derived(ctx.isOpen(value));

	const triggerId = `accordion-trigger-${value}`;
	const contentId = `accordion-content-${value}`;

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' || e.key === ' ') {
			e.preventDefault();
			if (!disabled) ctx.toggle(value);
		}
	}
</script>

<div class="bos-accordion-item {className}" class:is-open={open} class:is-disabled={disabled}>
	<button
		id={triggerId}
		class="bos-accordion-trigger"
		aria-expanded={open}
		aria-controls={contentId}
		aria-disabled={disabled}
		disabled={disabled}
		onclick={() => ctx.toggle(value)}
		onkeydown={handleKeydown}
	>
		<span class="bos-accordion-trigger__title">{title}</span>
		<span class="bos-accordion-trigger__chevron" aria-hidden="true">
			<svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
			</svg>
		</span>
	</button>

	{#if open && children}
		<div
			id={contentId}
			class="bos-accordion-content"
			role="region"
			aria-labelledby={triggerId}
			transition:slide={{ duration: 220, easing: cubicOut }}
		>
			<div class="bos-accordion-content__inner">
				{@render children()}
			</div>
		</div>
	{/if}
</div>

<style>
	.bos-accordion-item {
		border-bottom: 1px solid rgba(0, 0, 0, 0.06);
	}
	.bos-accordion-item:last-child { border-bottom: none; }
	:global(.dark) .bos-accordion-item { border-bottom-color: rgba(255, 255, 255, 0.06); }

	/* Trigger */
	.bos-accordion-trigger {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 12px;
		padding: 14px 18px;
		background: transparent;
		border: none;
		cursor: pointer;
		text-align: left;
		font-family: inherit;
		transition: background 0.12s;
	}

	.bos-accordion-trigger:hover:not(:disabled) {
		background: rgba(0, 0, 0, 0.02);
	}
	:global(.dark) .bos-accordion-trigger:hover:not(:disabled) {
		background: rgba(255, 255, 255, 0.03);
	}

	.bos-accordion-trigger:focus-visible {
		outline: 2px solid rgba(0, 0, 0, 0.25);
		outline-offset: -2px;
	}
	:global(.dark) .bos-accordion-trigger:focus-visible {
		outline-color: rgba(255, 255, 255, 0.25);
	}

	.bos-accordion-trigger:disabled {
		cursor: not-allowed;
		opacity: 0.4;
	}

	/* Title */
	.bos-accordion-trigger__title {
		font-size: 14px;
		font-weight: 500;
		color: #111;
		line-height: 1.4;
		flex: 1;
	}
	:global(.dark) .bos-accordion-trigger__title { color: #e5e5e5; }

	/* Chevron */
	.bos-accordion-trigger__chevron {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		color: #999;
		transition: transform 0.22s cubic-bezier(0.4, 0, 0.2, 1);
	}

	.bos-accordion-item.is-open .bos-accordion-trigger__chevron {
		transform: rotate(180deg);
	}

	/* Content */
	.bos-accordion-content {
		overflow: hidden;
	}

	.bos-accordion-content__inner {
		padding: 0 18px 16px;
		font-size: 14px;
		color: #555;
		line-height: 1.6;
	}
	:global(.dark) .bos-accordion-content__inner { color: #999; }
</style>
