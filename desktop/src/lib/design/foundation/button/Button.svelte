<script lang="ts">
	/**
	 * Button Component - BusinessOS Style
	 * Modern document-centric button patterns
	 */
	import { type Snippet } from 'svelte';
	import type { HTMLButtonAttributes } from 'svelte/elements';
	import Loading from '../loading/Loading.svelte';

	type ButtonVariant = 'primary' | 'secondary' | 'plain' | 'error' | 'success';
	type ButtonSize = 'default' | 'large' | 'extraLarge';

	interface Props extends Omit<HTMLButtonAttributes, 'disabled' | 'prefix'> {
		variant?: ButtonVariant;
		size?: ButtonSize;
		loading?: boolean;
		disabled?: boolean;
		block?: boolean;
		withoutHover?: boolean;
		class?: string;
		prefix?: Snippet;
		suffix?: Snippet;
		children?: Snippet;
	}

	let {
		variant = 'secondary',
		size = 'default',
		loading = false,
		disabled = false,
		block = false,
		withoutHover = false,
		class: className = '',
		prefix,
		suffix,
		children,
		...restProps
	}: Props = $props();
</script>

<button
	class="bos-button {className}"
	disabled={disabled || loading}
	data-loading={loading || undefined}
	data-disabled={disabled || undefined}
	data-block={block || undefined}
	data-no-hover={withoutHover || undefined}
	data-variant={variant}
	data-size={size}
	{...restProps}
>
	{#if loading || prefix}
		<span class="bos-button__icon">
			{#if loading}
				<Loading size="sm" />
			{:else if prefix}
				{@render prefix()}
			{/if}
		</span>
	{/if}

	{#if children}
		<span class="bos-button__content">
			{@render children()}
		</span>
	{/if}

	{#if suffix && !loading}
		<span class="bos-button__icon">
			{@render suffix()}
		</span>
	{/if}
</button>

<style>
	/* BusinessOS Button Styles */
	.bos-button {
		/* Layout */
		flex-shrink: 0;
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		gap: 4px;
		user-select: none;
		outline: 0;
		border-radius: 8px;
		transition: all 0.3s;
		border-width: 1px;
		border-style: solid;

		/* Default colors - will be overridden by variants */
		background-color: var(--bos-v2-button-secondary, #f4f4f5);
		color: var(--bos-v2-text-primary, #121212);
		border-color: var(--bos-v2-layer-insideBorder-blackBorder, rgba(0, 0, 0, 0.1));
	}

	/* Hover overlay pseudo-element */
	.bos-button::before {
		content: '';
		position: absolute;
		width: 100%;
		height: 100%;
		transition: inherit;
		border-radius: inherit;
		opacity: 0;
		left: 50%;
		top: 50%;
		transform: translate(-50%, -50%);
		background-color: var(--bos-v2-layer-background-hoverOverlay, rgba(0, 0, 0, 0.04));
		pointer-events: none;
	}

	.bos-button:hover::before {
		opacity: 1;
	}

	.bos-button[data-no-hover]::before,
	.bos-button[data-disabled]::before {
		display: none;
	}

	.bos-button[data-block] {
		display: flex;
	}

	/* ============ SIZE VARIANTS ============ */
	.bos-button[data-size='default'] {
		height: 28px;
		padding: 4px 12px;
		font-size: var(--bos-font-xs, 12px);
		font-weight: 500;
		line-height: 20px;
	}

	.bos-button[data-size='large'] {
		height: 32px;
		padding: 4px 12px;
		font-size: 15px;
		font-weight: 500;
		line-height: 24px;
	}

	.bos-button[data-size='extraLarge'] {
		height: 40px;
		padding: 8px 18px;
		font-size: 15px;
		font-weight: 600;
		line-height: 24px;
	}

	/* ============ VARIANT STYLES ============ */
	.bos-button[data-variant='primary'] {
		background-color: var(--bos-v2-button-primary, #1e96eb);
		color: var(--bos-v2-button-pureWhiteText, #ffffff);
	}

	.bos-button[data-variant='secondary'] {
		background-color: var(--bos-v2-button-secondary, #f4f4f5);
		color: var(--bos-v2-text-primary, #121212);
	}

	.bos-button[data-variant='plain'] {
		background-color: transparent;
		color: var(--bos-v2-text-primary, #121212);
		border-color: transparent;
		border-width: 0;
	}

	.bos-button[data-variant='error'] {
		background-color: var(--bos-v2-button-error, #eb4335);
		color: var(--bos-v2-button-pureWhiteText, #ffffff);
	}

	.bos-button[data-variant='success'] {
		background-color: var(--bos-v2-button-success, #10b981);
		color: var(--bos-v2-button-pureWhiteText, #ffffff);
	}

	/* ============ STATES ============ */
	.bos-button[data-disabled] {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.bos-button:not([data-disabled]) {
		cursor: pointer;
	}

	/* Focus ring */
	.bos-button:focus-visible::after {
		content: '';
		width: 100%;
		height: 100%;
		position: absolute;
		top: 0;
		left: 0;
		border-radius: inherit;
		box-shadow: 0 0 0 1px var(--bos-v2-layer-insideBorder-primaryBorder, #1e96eb);
	}

	/* ============ ICON STYLES ============ */
	.bos-button__icon {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		width: 16px;
		height: 16px;
		font-size: 16px;
	}

	.bos-button[data-size='large'] .bos-button__icon {
		width: 20px;
		height: 20px;
		font-size: 20px;
	}

	.bos-button[data-size='extraLarge'] .bos-button__icon {
		width: 24px;
		height: 24px;
		font-size: 24px;
	}

	.bos-button__icon :global(svg) {
		width: 100%;
		height: 100%;
		display: block;
	}

	/* Icon color based on variant */
	.bos-button[data-variant='primary'] .bos-button__icon,
	.bos-button[data-variant='error'] .bos-button__icon,
	.bos-button[data-variant='success'] .bos-button__icon {
		color: var(--bos-v2-button-pureWhiteText, #ffffff);
	}

	.bos-button[data-variant='secondary'] .bos-button__icon,
	.bos-button[data-variant='plain'] .bos-button__icon {
		color: var(--bos-v2-icon-primary, #77757d);
	}

	/* ============ CONTENT ============ */
	.bos-button__content {
		text-overflow: ellipsis;
		white-space: nowrap;
		overflow: hidden;
	}

	/* ============ DARK MODE ============ */
	:global(.dark) .bos-button[data-variant='secondary'] {
		background-color: var(--bos-v2-button-secondary, #3a3a3a);
		color: var(--bos-v2-text-primary, #e6e6e6);
	}

	:global(.dark) .bos-button[data-variant='plain'] {
		color: var(--bos-v2-text-primary, #e6e6e6);
	}

	:global(.dark) .bos-button::before {
		background-color: var(--bos-v2-layer-background-hoverOverlay, rgba(255, 255, 255, 0.08));
	}
</style>
