<script lang="ts">
	/**
	 * Checkbox Component - BusinessOS Style
	 * Dark monochrome: unchecked = border only, checked = black fill + white checkmark
	 * Indeterminate state: black fill + white dash
	 */

	interface Props {
		checked?: boolean;
		indeterminate?: boolean;
		disabled?: boolean;
		label?: string;
		id?: string;
		onchange?: (checked: boolean) => void;
	}

	let {
		checked = $bindable(false),
		indeterminate = false,
		disabled = false,
		label,
		id,
		onchange
	}: Props = $props();

	const ariaChecked = $derived(indeterminate ? 'mixed' : checked);

	function handleClick() {
		if (disabled) return;
		if (indeterminate) {
			checked = true;
		} else {
			checked = !checked;
		}
		onchange?.(checked);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			handleClick();
		}
	}

	const inputId = $derived(id ?? `checkbox-${Math.random().toString(36).slice(2, 8)}`);
</script>

<label
	class="bos-checkbox-wrapper"
	class:bos-checkbox-wrapper--disabled={disabled}
	for={inputId}
>
	<button
		type="button"
		role="checkbox"
		id={inputId}
		aria-checked={ariaChecked}
		aria-disabled={disabled || undefined}
		class="bos-checkbox"
		data-checked={checked || undefined}
		data-indeterminate={indeterminate || undefined}
		data-disabled={disabled || undefined}
		onclick={handleClick}
		onkeydown={handleKeydown}
	>
		{#if indeterminate}
			<!-- Dash for indeterminate -->
			<svg
				class="bos-checkbox__icon"
				width="10"
				height="10"
				viewBox="0 0 10 10"
				fill="none"
				aria-hidden="true"
			>
				<line x1="2" y1="5" x2="8" y2="5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
			</svg>
		{:else if checked}
			<!-- Checkmark -->
			<svg
				class="bos-checkbox__icon"
				width="10"
				height="10"
				viewBox="0 0 10 10"
				fill="none"
				aria-hidden="true"
			>
				<path
					d="M1.5 5L4 7.5L8.5 2.5"
					stroke="currentColor"
					stroke-width="1.75"
					stroke-linecap="round"
					stroke-linejoin="round"
				/>
			</svg>
		{/if}
	</button>
	{#if label}
		<span class="bos-checkbox__label">{label}</span>
	{/if}
</label>

<style>
	.bos-checkbox-wrapper {
		display: inline-flex;
		align-items: center;
		gap: 9px;
		cursor: pointer;
		user-select: none;
	}

	.bos-checkbox-wrapper--disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	/* ============ BOX ============ */
	.bos-checkbox {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		width: 18px;
		height: 18px;
		border-radius: 4px;
		border: 1.5px solid rgba(0, 0, 0, 0.25);
		background-color: transparent;
		cursor: pointer;
		padding: 0;
		outline: none;
		transition: border-color 0.15s ease, background-color 0.15s ease, box-shadow 0.15s ease;
		color: #fff;
	}

	.bos-checkbox[data-disabled] {
		cursor: not-allowed;
	}

	.bos-checkbox:not([data-disabled]):hover {
		border-color: rgba(0, 0, 0, 0.45);
		background-color: rgba(0, 0, 0, 0.03);
	}

	/* Checked & indeterminate: filled black */
	.bos-checkbox[data-checked],
	.bos-checkbox[data-indeterminate] {
		background-color: #111;
		border-color: #111;
	}

	.bos-checkbox[data-checked]:not([data-disabled]):hover,
	.bos-checkbox[data-indeterminate]:not([data-disabled]):hover {
		background-color: #222;
		border-color: #222;
	}

	/* Focus ring */
	.bos-checkbox:focus-visible {
		box-shadow: 0 0 0 2px #fff, 0 0 0 4px rgba(0, 0, 0, 0.35);
	}

	/* ============ ICON ============ */
	.bos-checkbox__icon {
		display: block;
		flex-shrink: 0;
	}

	/* ============ LABEL ============ */
	.bos-checkbox__label {
		font-size: 14px;
		font-weight: 500;
		color: #111;
		line-height: 1;
	}

	/* ============ DARK MODE ============ */
	:global(.dark) .bos-checkbox {
		border-color: rgba(255, 255, 255, 0.25);
		color: #111;
	}

	:global(.dark) .bos-checkbox:not([data-disabled]):hover {
		border-color: rgba(255, 255, 255, 0.45);
		background-color: rgba(255, 255, 255, 0.04);
	}

	:global(.dark) .bos-checkbox[data-checked],
	:global(.dark) .bos-checkbox[data-indeterminate] {
		background-color: #fff;
		border-color: #fff;
		color: #111;
	}

	:global(.dark) .bos-checkbox[data-checked]:not([data-disabled]):hover,
	:global(.dark) .bos-checkbox[data-indeterminate]:not([data-disabled]):hover {
		background-color: #e5e5e5;
		border-color: #e5e5e5;
	}

	:global(.dark) .bos-checkbox:focus-visible {
		box-shadow: 0 0 0 2px #111, 0 0 0 4px rgba(255, 255, 255, 0.4);
	}

	:global(.dark) .bos-checkbox__label {
		color: #e5e5e5;
	}
</style>
