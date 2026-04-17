<script lang="ts">
	/**
	 * Slider Component - BusinessOS Style
	 * Custom styled range input with monochrome aesthetic
	 */

	interface Props {
		value?: number;
		min?: number;
		max?: number;
		step?: number;
		disabled?: boolean;
		showValue?: boolean;
		label?: string;
		class?: string;
	}

	let {
		value = $bindable(50),
		min = 0,
		max = 100,
		step = 1,
		disabled = false,
		showValue = false,
		label,
		class: className = ''
	}: Props = $props();

	const percentage = $derived(((value - min) / (max - min)) * 100);
</script>

<div class="bos-slider-root {className}" class:bos-slider-root--disabled={disabled}>
	{#if label || showValue}
		<div class="bos-slider__header">
			{#if label}
				<label class="bos-slider__label">{label}</label>
			{/if}
			{#if showValue}
				<span class="bos-slider__value">{value}</span>
			{/if}
		</div>
	{/if}
	<div class="bos-slider__track-wrapper">
		<div class="bos-slider__track">
			<div class="bos-slider__fill" style="width: {percentage}%"></div>
		</div>
		<input
			type="range"
			class="bos-slider__input"
			bind:value
			{min}
			{max}
			{step}
			{disabled}
			aria-label={label}
			aria-valuemin={min}
			aria-valuemax={max}
			aria-valuenow={value}
		/>
	</div>
</div>

<style>
	.bos-slider-root {
		display: flex;
		flex-direction: column;
		gap: 8px;
		width: 100%;
	}

	.bos-slider__header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
	}

	.bos-slider__label {
		font-size: 12px;
		font-weight: 600;
		color: var(--bos-v2-text-secondary, #555);
		letter-spacing: 0.01em;
		font-family: var(--bos-font-family);
	}

	.bos-slider__value {
		font-size: 12px;
		font-weight: 600;
		color: var(--bos-v2-text-primary, #111);
		font-family: var(--bos-font-family);
		min-width: 2.5ch;
		text-align: right;
	}

	.bos-slider__track-wrapper {
		position: relative;
		height: 18px;
		display: flex;
		align-items: center;
	}

	.bos-slider__track {
		position: absolute;
		left: 0;
		right: 0;
		height: 4px;
		background: rgba(0, 0, 0, 0.1);
		border-radius: 9999px;
		overflow: hidden;
		pointer-events: none;
	}

	.bos-slider__fill {
		height: 100%;
		background: #111;
		border-radius: 9999px;
		transition: width 0.05s;
	}

	.bos-slider__input {
		position: relative;
		width: 100%;
		height: 18px;
		background: transparent;
		outline: none;
		cursor: pointer;
		margin: 0;
		padding: 0;
		-webkit-appearance: none;
		appearance: none;
		z-index: 1;
	}

	/* Webkit thumb */
	.bos-slider__input::-webkit-slider-thumb {
		-webkit-appearance: none;
		appearance: none;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: #fff;
		border: 2px solid #111;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
		cursor: pointer;
		transition: box-shadow 0.15s, transform 0.15s;
	}

	.bos-slider__input::-webkit-slider-thumb:hover {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25), 0 0 0 4px rgba(0, 0, 0, 0.06);
	}

	.bos-slider__input:focus::-webkit-slider-thumb {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2), 0 0 0 3px rgba(0, 0, 0, 0.08);
	}

	.bos-slider__input:active::-webkit-slider-thumb {
		transform: scale(1.1);
	}

	/* Firefox thumb */
	.bos-slider__input::-moz-range-thumb {
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: #fff;
		border: 2px solid #111;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
		cursor: pointer;
		transition: box-shadow 0.15s, transform 0.15s;
	}

	.bos-slider__input::-moz-range-thumb:hover {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.25), 0 0 0 4px rgba(0, 0, 0, 0.06);
	}

	/* Remove default track */
	.bos-slider__input::-webkit-slider-runnable-track {
		background: transparent;
	}

	.bos-slider__input::-moz-range-track {
		background: transparent;
	}

	/* Disabled state */
	.bos-slider-root--disabled .bos-slider__input {
		cursor: not-allowed;
		opacity: 0.5;
	}

	.bos-slider-root--disabled .bos-slider__track {
		opacity: 0.5;
	}

	/* Dark mode */
	:global(.dark) .bos-slider__label {
		color: #aaa;
	}

	:global(.dark) .bos-slider__value {
		color: #e6e6e6;
	}

	:global(.dark) .bos-slider__track {
		background: rgba(255, 255, 255, 0.1);
	}

	:global(.dark) .bos-slider__fill {
		background: #fff;
	}

	:global(.dark) .bos-slider__input::-webkit-slider-thumb {
		background: #1e1e1e;
		border-color: #fff;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.4);
	}

	:global(.dark) .bos-slider__input::-webkit-slider-thumb:hover {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.5), 0 0 0 4px rgba(255, 255, 255, 0.06);
	}

	:global(.dark) .bos-slider__input:focus::-webkit-slider-thumb {
		box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4), 0 0 0 3px rgba(255, 255, 255, 0.08);
	}

	:global(.dark) .bos-slider__input::-moz-range-thumb {
		background: #1e1e1e;
		border-color: #fff;
		box-shadow: 0 1px 4px rgba(0, 0, 0, 0.4);
	}
</style>
