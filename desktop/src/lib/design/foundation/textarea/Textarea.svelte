<script lang="ts">
	/**
	 * Textarea Component - BusinessOS Style
	 * Multi-line input matching Input.svelte patterns exactly
	 */
	import type { HTMLTextareaAttributes } from 'svelte/elements';

	type TextareaStatus = 'default' | 'error' | 'success' | 'warning';
	type TextareaResize = 'none' | 'vertical' | 'both';

	interface Props extends Omit<HTMLTextareaAttributes, 'class'> {
		value?: string;
		placeholder?: string;
		rows?: number;
		disabled?: boolean;
		status?: TextareaStatus;
		resize?: TextareaResize;
		maxlength?: number;
		showCount?: boolean;
		class?: string;
	}

	let {
		value = $bindable(''),
		placeholder,
		rows = 3,
		disabled = false,
		status = 'default',
		resize = 'vertical',
		maxlength,
		showCount = false,
		class: className = '',
		...restProps
	}: Props = $props();

	const charCount = $derived(value?.length ?? 0);
	const showCharCount = $derived(showCount && maxlength !== undefined);
</script>

<div class="bos-textarea-wrapper">
	<textarea
		class="bos-textarea {className}"
		data-status={status}
		data-resize={resize}
		bind:value
		{placeholder}
		{rows}
		{disabled}
		{maxlength}
		{...restProps}
	></textarea>
	{#if showCharCount}
		<span class="bos-textarea__count" class:bos-textarea__count--near={charCount >= maxlength! * 0.85} class:bos-textarea__count--at={charCount >= maxlength!}>
			{charCount}/{maxlength}
		</span>
	{/if}
</div>

<style>
	.bos-textarea-wrapper {
		position: relative;
		width: 100%;
	}

	.bos-textarea {
		width: 100%;
		padding: 10px 12px;
		font-size: var(--bos-font-sm, 14px);
		font-family: var(--bos-font-family);
		color: var(--bos-v2-text-primary, #121212);
		background-color: var(--bos-v2-layer-background-primary, #ffffff);
		border: 1px solid var(--bos-v2-layer-insideBorder-border, rgba(0, 0, 0, 0.1));
		border-radius: 8px;
		outline: none;
		transition: border-color 0.2s, box-shadow 0.2s;
		line-height: 1.5;
		resize: vertical;
		box-sizing: border-box;
	}

	.bos-textarea[data-resize='none'] {
		resize: none;
	}

	.bos-textarea[data-resize='vertical'] {
		resize: vertical;
	}

	.bos-textarea[data-resize='both'] {
		resize: both;
	}

	.bos-textarea::placeholder {
		color: var(--bos-placeholder-color, #c0bfc1);
	}

	.bos-textarea:focus {
		border-color: rgba(0, 0, 0, 0.3);
		box-shadow: 0 0 0 3px rgba(0, 0, 0, 0.06);
	}

	.bos-textarea:disabled {
		opacity: 0.5;
		cursor: not-allowed;
		resize: none;
	}

	/* Status variants */
	.bos-textarea[data-status='error'] {
		border-color: var(--bos-error-color, #eb4335);
	}

	.bos-textarea[data-status='error']:focus {
		box-shadow: 0 0 0 2px rgba(235, 67, 53, 0.1);
	}

	.bos-textarea[data-status='success'] {
		border-color: var(--bos-success-color, #10b981);
	}

	.bos-textarea[data-status='success']:focus {
		box-shadow: 0 0 0 2px rgba(16, 185, 129, 0.1);
	}

	.bos-textarea[data-status='warning'] {
		border-color: var(--bos-warning-color, #f59e0b);
	}

	.bos-textarea[data-status='warning']:focus {
		box-shadow: 0 0 0 2px rgba(245, 158, 11, 0.1);
	}

	/* Character count */
	.bos-textarea__count {
		position: absolute;
		bottom: 8px;
		right: 10px;
		font-size: 11px;
		color: var(--bos-v2-text-secondary, #999);
		pointer-events: none;
		font-family: var(--bos-font-family);
		line-height: 1;
	}

	.bos-textarea__count--near {
		color: var(--bos-warning-color, #f59e0b);
	}

	.bos-textarea__count--at {
		color: var(--bos-error-color, #eb4335);
	}

	/* Dark mode */
	:global(.dark) .bos-textarea {
		color: var(--bos-v2-text-primary, #e6e6e6);
		background-color: var(--bos-v2-layer-background-primary, #1e1e1e);
		border-color: var(--bos-v2-layer-insideBorder-border, rgba(255, 255, 255, 0.1));
	}

	:global(.dark) .bos-textarea::placeholder {
		color: var(--bos-placeholder-color, #545459);
	}

	:global(.dark) .bos-textarea:focus {
		border-color: rgba(255, 255, 255, 0.3);
		box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.06);
	}

	:global(.dark) .bos-textarea__count {
		color: #666;
	}

	:global(.dark) .bos-textarea__count--near {
		color: #d97706;
	}

	:global(.dark) .bos-textarea__count--at {
		color: #ef4444;
	}
</style>
