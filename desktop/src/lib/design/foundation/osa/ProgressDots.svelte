<!--
	ProgressDots.svelte
	iOS-style progress dots indicator.

	Usage:
	<ProgressDots total={4} current={1} />
-->
<script lang="ts">
	interface Props {
		total: number;
		current: number;
		class?: string;
	}

	let {
		total,
		current,
		class: className = ''
	}: Props = $props();

	const dots = Array.from({ length: total }, (_, i) => i);
</script>

<div
	class="osa-dots {className}"
	role="progressbar"
	aria-valuenow={current}
	aria-valuemin={0}
	aria-valuemax={total}
>
	{#each dots as index}
		<div class="osa-dot" class:osa-dot--active={index === current}></div>
	{/each}
</div>

<style>
	.osa-dots {
		display: flex;
		align-items: center;
		gap: 8px;
		justify-content: center;
	}
	.osa-dot {
		width: 8px;
		height: 8px;
		border-radius: 9999px;
		background: var(--dbd);
		transition: all 0.3s ease;
	}
	.osa-dot--active {
		width: 24px;
		background: var(--dt);
	}
</style>
