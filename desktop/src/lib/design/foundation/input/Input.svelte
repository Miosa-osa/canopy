<script lang="ts">
	/**
	 * Input Component - BusinessOS Style
	 * Modern document-centric input patterns
	 */
	import { type Snippet } from 'svelte';
	import type { HTMLInputAttributes } from 'svelte/elements';

	type InputStatus = 'default' | 'error' | 'success' | 'warning';
	type InputSize = 'default' | 'large';

	interface Props extends Omit<HTMLInputAttributes, 'size' | 'prefix'> {
		status?: InputStatus;
		size?: InputSize;
		class?: string;
		wrapperClass?: string;
		prefix?: Snippet;
		suffix?: Snippet;
	}

	let {
		value = $bindable(''),
		status = 'default',
		size = 'default',
		class: className = '',
		wrapperClass = '',
		prefix,
		suffix,
		...restProps
	}: Props = $props();

	const hasAdornment = $derived(prefix || suffix);
</script>

{#if hasAdornment}
	<div class="bos-input-wrapper {wrapperClass}">
		{#if prefix}
			<div class="bos-input__prefix">
				{@render prefix()}
			</div>
		{/if}

		<input
			class="bos-input {className}"
			data-status={status}
			data-size={size}
			data-has-prefix={prefix ? true : undefined}
			data-has-suffix={suffix ? true : undefined}
			bind:value
			{...restProps}
		/>

		{#if suffix}
			<div class="bos-input__suffix">
				{@render suffix()}
			</div>
		{/if}
	</div>
{:else}
	<input
		class="bos-input {className}"
		data-status={status}
		data-size={size}
		bind:value
		{...restProps}
	/>
{/if}

<style>
	.bos-input-wrapper {
		position: relative;
		display: flex;
		align-items: center;
		width: 100%;
	}

	.bos-input {
		width: 100%;
		height: 32px;
		padding: 0 12px;
		font-size: var(--bos-font-sm, 14px);
		font-family: var(--bos-font-family);
		color: var(--bos-v2-text-primary, #121212);
		background-color: var(--bos-v2-layer-background-primary, #ffffff);
		border: 1px solid var(--bos-v2-layer-insideBorder-border, rgba(0, 0, 0, 0.1));
		border-radius: 8px;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
	}

	.bos-input[data-size='large'] {
		height: 40px;
		font-size: var(--bos-font-base, 15px);
	}

	.bos-input::placeholder {
		color: var(--bos-placeholder-color, #c0bfc1);
	}

	.bos-input:focus {
		border-color: rgba(0, 0, 0, 0.3);
		box-shadow: 0 0 0 3px rgba(0, 0, 0, 0.06);
	}

	:global(.dark) .bos-input:focus {
		border-color: rgba(255, 255, 255, 0.3);
		box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.06);
	}

	.bos-input:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Status variants */
	.bos-input[data-status='error'] {
		border-color: var(--bos-error-color, #eb4335);
	}

	.bos-input[data-status='error']:focus {
		box-shadow: 0 0 0 2px rgba(235, 67, 53, 0.1);
	}

	.bos-input[data-status='success'] {
		border-color: var(--bos-success-color, #10b981);
	}

	.bos-input[data-status='success']:focus {
		box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.1);
	}

	.bos-input[data-status='warning'] {
		border-color: var(--bos-warning-color, #f59e0b);
	}

	.bos-input[data-status='warning']:focus {
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.1);
	}

	/* Prefix/suffix padding */
	.bos-input[data-has-prefix] {
		padding-left: 36px;
	}

	.bos-input[data-has-suffix] {
		padding-right: 36px;
	}

	.bos-input__prefix,
	.bos-input__suffix {
		position: absolute;
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--bos-v2-icon-primary, #77757d);
		pointer-events: none;
	}

	.bos-input__prefix {
		left: 12px;
	}

	.bos-input__suffix {
		right: 12px;
	}

	.bos-input__prefix :global(svg),
	.bos-input__suffix :global(svg) {
		width: 16px;
		height: 16px;
	}

	/* Dark mode */
	:global(.dark) .bos-input {
		color: var(--bos-v2-text-primary, #e6e6e6);
		background-color: var(--bos-v2-layer-background-primary, #1e1e1e);
		border-color: var(--bos-v2-layer-insideBorder-border, rgba(255, 255, 255, 0.1));
	}

	:global(.dark) .bos-input::placeholder {
		color: var(--bos-placeholder-color, #545459);
	}

	:global(.dark) .bos-input__prefix,
	:global(.dark) .bos-input__suffix {
		color: var(--bos-v2-icon-primary, #a6a6ad);
	}
</style>
