<script lang="ts">
	/**
	 * RadioItem Component - BusinessOS Style
	 * Must be used inside a RadioGroup.
	 * Custom styled: 18px circle, selected = black fill with white inner dot.
	 */
	import { getContext } from 'svelte';

	interface RadioGroupContext {
		value: string;
		name: string;
		disabled: boolean;
		select: (value: string) => void;
	}

	interface Props {
		value: string;
		label: string;
		disabled?: boolean;
		description?: string;
		id?: string;
	}

	let {
		value,
		label,
		disabled = false,
		description,
		id
	}: Props = $props();

	const group = getContext<RadioGroupContext>('radio-group');

	const isChecked = $derived(group.value === value);
	const isDisabled = $derived(disabled || group.disabled);
	const inputId = $derived(id ?? `radio-${group.name}-${value}-${Math.random().toString(36).slice(2, 6)}`);

	function handleClick() {
		if (isDisabled) return;
		group.select(value);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			handleClick();
		}
	}
</script>

<label
	class="bos-radio-item"
	class:bos-radio-item--disabled={isDisabled}
	class:bos-radio-item--has-desc={!!description}
	for={inputId}
>
	<button
		type="button"
		role="radio"
		id={inputId}
		aria-checked={isChecked}
		aria-disabled={isDisabled || undefined}
		class="bos-radio"
		data-checked={isChecked || undefined}
		data-disabled={isDisabled || undefined}
		onclick={handleClick}
		onkeydown={handleKeydown}
	>
		{#if isChecked}
			<span class="bos-radio__dot"></span>
		{/if}
	</button>
	<div class="bos-radio-item__content">
		<span class="bos-radio-item__label">{label}</span>
		{#if description}
			<span class="bos-radio-item__desc">{description}</span>
		{/if}
	</div>
</label>

<style>
	.bos-radio-item {
		display: inline-flex;
		align-items: flex-start;
		gap: 10px;
		cursor: pointer;
		user-select: none;
	}

	.bos-radio-item--disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	/* ============ CIRCLE ============ */
	.bos-radio {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		width: 18px;
		height: 18px;
		border-radius: 9999px;
		border: 1.5px solid rgba(0, 0, 0, 0.25);
		background-color: transparent;
		cursor: pointer;
		padding: 0;
		outline: none;
		transition: border-color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease;
		/* Align radio button center with first line of label text */
		margin-top: 1px;
	}

	.bos-radio-item--has-desc .bos-radio {
		margin-top: 2px;
	}

	.bos-radio[data-disabled] {
		cursor: not-allowed;
	}

	.bos-radio:not([data-disabled]):hover {
		border-color: rgba(0, 0, 0, 0.45);
		background-color: rgba(0, 0, 0, 0.03);
	}

	.bos-radio[data-checked] {
		background-color: #111;
		border-color: #111;
	}

	.bos-radio[data-checked]:not([data-disabled]):hover {
		background-color: #222;
		border-color: #222;
	}

	/* Focus ring */
	.bos-radio:focus-visible {
		box-shadow: 0 0 0 2px #fff, 0 0 0 4px rgba(0, 0, 0, 0.35);
	}

	/* ============ DOT ============ */
	.bos-radio__dot {
		display: block;
		width: 6px;
		height: 6px;
		border-radius: 9999px;
		background-color: #fff;
		flex-shrink: 0;
	}

	/* ============ CONTENT ============ */
	.bos-radio-item__content {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.bos-radio-item__label {
		font-size: 14px;
		font-weight: 500;
		color: #111;
		line-height: 1.4;
	}

	.bos-radio-item__desc {
		font-size: 12px;
		color: #888;
		line-height: 1.4;
	}

	/* ============ DARK MODE ============ */
	:global(.dark) .bos-radio {
		border-color: rgba(255, 255, 255, 0.25);
	}

	:global(.dark) .bos-radio:not([data-disabled]):hover {
		border-color: rgba(255, 255, 255, 0.45);
		background-color: rgba(255, 255, 255, 0.04);
	}

	:global(.dark) .bos-radio[data-checked] {
		background-color: #fff;
		border-color: #fff;
	}

	:global(.dark) .bos-radio[data-checked]:not([data-disabled]):hover {
		background-color: #e5e5e5;
		border-color: #e5e5e5;
	}

	:global(.dark) .bos-radio__dot {
		background-color: #111;
	}

	:global(.dark) .bos-radio:focus-visible {
		box-shadow: 0 0 0 2px #111, 0 0 0 4px rgba(255, 255, 255, 0.4);
	}

	:global(.dark) .bos-radio-item__label {
		color: #e5e5e5;
	}

	:global(.dark) .bos-radio-item__desc {
		color: #666;
	}
</style>
