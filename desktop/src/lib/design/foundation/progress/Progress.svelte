<script lang="ts">
	type ProgressVariant = 'default' | 'success' | 'warning' | 'error';
	type ProgressSize = 'sm' | 'default' | 'lg';

	interface Props {
		value?: number;
		max?: number;
		variant?: ProgressVariant;
		size?: ProgressSize;
		indeterminate?: boolean;
		label?: string;
		showValue?: boolean;
		class?: string;
	}

	let {
		value = 0,
		max = 100,
		variant = 'default',
		size = 'default',
		indeterminate = false,
		label,
		showValue = false,
		class: className = ''
	}: Props = $props();

	let clampedValue = $derived(Math.min(Math.max(0, value), max));
	let percentage = $derived(Math.round((clampedValue / max) * 100));
	let fillWidth = $derived(indeterminate ? '100%' : `${percentage}%`);
</script>

<div class="bos-progress-wrap {className}">
	{#if label || showValue}
		<div class="bos-progress-header">
			{#if label}
				<span class="bos-progress-label">{label}</span>
			{/if}
			{#if showValue && !indeterminate}
				<span class="bos-progress-value">{percentage}%</span>
			{/if}
		</div>
	{/if}

	<div
		class="bos-progress bos-progress--{size}"
		role="progressbar"
		aria-valuenow={indeterminate ? undefined : clampedValue}
		aria-valuemin={0}
		aria-valuemax={max}
		aria-label={label}
		aria-busy={indeterminate}
	>
		<div
			class="bos-progress__fill bos-progress__fill--{variant}"
			class:bos-progress__fill--indeterminate={indeterminate}
			style:width={fillWidth}
		></div>
	</div>
</div>

<style>
	.bos-progress-wrap {
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	/* ── Header row ── */
	.bos-progress-header {
		display: flex;
		justify-content: space-between;
		align-items: center;
	}

	.bos-progress-label {
		font-size: 12px;
		font-weight: 500;
		color: #555;
	}
	:global(.dark) .bos-progress-label { color: #999; }

	.bos-progress-value {
		font-size: 12px;
		font-weight: 600;
		color: #888;
		font-variant-numeric: tabular-nums;
	}
	:global(.dark) .bos-progress-value { color: #666; }

	/* ── Track ── */
	.bos-progress {
		width: 100%;
		background: rgba(0, 0, 0, 0.06);
		border-radius: 9999px;
		overflow: hidden;
		position: relative;
	}
	:global(.dark) .bos-progress { background: rgba(255, 255, 255, 0.08); }

	.bos-progress--sm     { height: 4px; }
	.bos-progress--default { height: 8px; }
	.bos-progress--lg     { height: 12px; }

	/* ── Fill ── */
	.bos-progress__fill {
		height: 100%;
		border-radius: 9999px;
		transition: width 0.4s cubic-bezier(0.4, 0, 0.2, 1);
	}

	/* Variant colours */
	.bos-progress__fill--default {
		background: #111;
	}
	:global(.dark) .bos-progress__fill--default { background: #e5e5e5; }

	.bos-progress__fill--success { background: #22c55e; }
	.bos-progress__fill--warning { background: #f59e0b; }
	.bos-progress__fill--error   { background: #ef4444; }

	/* ── Indeterminate shimmer ── */
	.bos-progress__fill--indeterminate {
		width: 40% !important;
		animation: bos-progress-slide 1.4s ease-in-out infinite;
		background: linear-gradient(
			90deg,
			transparent 0%,
			currentColor 40%,
			currentColor 60%,
			transparent 100%
		);
	}

	.bos-progress__fill--default.bos-progress__fill--indeterminate {
		color: #111;
	}
	:global(.dark) .bos-progress__fill--default.bos-progress__fill--indeterminate {
		color: #e5e5e5;
	}
	.bos-progress__fill--success.bos-progress__fill--indeterminate { color: #22c55e; }
	.bos-progress__fill--warning.bos-progress__fill--indeterminate { color: #f59e0b; }
	.bos-progress__fill--error.bos-progress__fill--indeterminate   { color: #ef4444; }

	@keyframes bos-progress-slide {
		0%   { transform: translateX(-100%); }
		100% { transform: translateX(300%); }
	}
</style>
