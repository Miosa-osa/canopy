<script lang="ts">
	/**
	 * Toggle / Switch Component - BusinessOS Style
	 * Dark monochrome aesthetic: OFF = gray, ON = black (dark mode: ON = white)
	 */

	type ToggleSize = 'sm' | 'default' | 'lg';

	interface Props {
		checked?: boolean;
		disabled?: boolean;
		size?: ToggleSize;
		label?: string;
		id?: string;
		onchange?: (checked: boolean) => void;
	}

	let {
		checked = $bindable(false),
		disabled = false,
		size = 'default',
		label,
		id,
		onchange
	}: Props = $props();

	function handleClick() {
		if (disabled) return;
		checked = !checked;
		onchange?.(checked);
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === ' ' || e.key === 'Enter') {
			e.preventDefault();
			handleClick();
		}
	}

	const inputId = $derived(id ?? `toggle-${Math.random().toString(36).slice(2, 8)}`);
</script>

<label class="bos-toggle-wrapper" class:bos-toggle-wrapper--disabled={disabled} for={inputId}>
	<button
		type="button"
		role="switch"
		id={inputId}
		aria-checked={checked}
		aria-disabled={disabled || undefined}
		class="bos-toggle"
		data-size={size}
		data-checked={checked || undefined}
		data-disabled={disabled || undefined}
		onclick={handleClick}
		onkeydown={handleKeydown}
	>
		<span class="bos-toggle__thumb"></span>
	</button>
	{#if label}
		<span class="bos-toggle__label">{label}</span>
	{/if}
</label>

<style>
	.bos-toggle-wrapper {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		cursor: pointer;
		user-select: none;
	}

	.bos-toggle-wrapper--disabled {
		opacity: 0.45;
		cursor: not-allowed;
	}

	/* ============ TRACK ============ */
	.bos-toggle {
		position: relative;
		display: inline-flex;
		align-items: center;
		flex-shrink: 0;
		border: none;
		outline: none;
		cursor: pointer;
		padding: 0;
		border-radius: 9999px;
		background-color: rgba(0, 0, 0, 0.15);
		transition: background-color 0.2s ease;
	}

	.bos-toggle[data-disabled] {
		cursor: not-allowed;
	}

	.bos-toggle:not([data-disabled]):hover {
		background-color: rgba(0, 0, 0, 0.22);
	}

	.bos-toggle[data-checked] {
		background-color: #111;
	}

	.bos-toggle[data-checked]:not([data-disabled]):hover {
		background-color: #222;
	}

	/* Focus ring */
	.bos-toggle:focus-visible {
		box-shadow: 0 0 0 2px #fff, 0 0 0 4px rgba(0, 0, 0, 0.4);
	}

	/* ============ SIZES ============ */
	.bos-toggle[data-size='sm'] {
		width: 28px;
		height: 16px;
	}

	.bos-toggle[data-size='default'] {
		width: 36px;
		height: 20px;
	}

	.bos-toggle[data-size='lg'] {
		width: 44px;
		height: 24px;
	}

	/* ============ THUMB ============ */
	.bos-toggle__thumb {
		position: absolute;
		border-radius: 9999px;
		background-color: #fff;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2), 0 1px 2px rgba(0, 0, 0, 0.12);
		transition: transform 0.2s ease, box-shadow 0.2s ease;
	}

	.bos-toggle[data-size='sm'] .bos-toggle__thumb {
		width: 12px;
		height: 12px;
		left: 2px;
	}

	.bos-toggle[data-size='default'] .bos-toggle__thumb {
		width: 16px;
		height: 16px;
		left: 2px;
	}

	.bos-toggle[data-size='lg'] .bos-toggle__thumb {
		width: 20px;
		height: 20px;
		left: 2px;
	}

	/* Thumb movement when checked */
	.bos-toggle[data-size='sm'][data-checked] .bos-toggle__thumb {
		transform: translateX(12px);
	}

	.bos-toggle[data-size='default'][data-checked] .bos-toggle__thumb {
		transform: translateX(16px);
	}

	.bos-toggle[data-size='lg'][data-checked] .bos-toggle__thumb {
		transform: translateX(20px);
	}

	.bos-toggle[data-checked] .bos-toggle__thumb {
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.3), 0 1px 2px rgba(0, 0, 0, 0.2);
	}

	/* ============ LABEL ============ */
	.bos-toggle__label {
		font-size: 14px;
		font-weight: 500;
		color: #111;
		line-height: 1;
	}

	/* ============ DARK MODE ============ */
	:global(.dark) .bos-toggle {
		background-color: rgba(255, 255, 255, 0.18);
	}

	:global(.dark) .bos-toggle:not([data-disabled]):hover {
		background-color: rgba(255, 255, 255, 0.25);
	}

	:global(.dark) .bos-toggle[data-checked] {
		background-color: #fff;
	}

	:global(.dark) .bos-toggle[data-checked]:not([data-disabled]):hover {
		background-color: #e5e5e5;
	}

	:global(.dark) .bos-toggle__thumb {
		background-color: #fff;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4), 0 1px 2px rgba(0, 0, 0, 0.3);
	}

	:global(.dark) .bos-toggle[data-checked] .bos-toggle__thumb {
		background-color: #111;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.4);
	}

	:global(.dark) .bos-toggle:focus-visible {
		box-shadow: 0 0 0 2px #111, 0 0 0 4px rgba(255, 255, 255, 0.4);
	}

	:global(.dark) .bos-toggle__label {
		color: #e5e5e5;
	}
</style>
