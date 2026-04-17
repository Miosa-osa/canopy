<!--
	GradientBackground.svelte
	Full-viewport background wrapper using Foundation tokens.

	Usage:
	<GradientBackground>
		<YourContent />
	</GradientBackground>
-->
<script lang="ts">
	interface Props {
		variant?: 'default' | 'dark' | 'surface';
		fullScreen?: boolean;
		children?: import('svelte').Snippet;
	}

	let {
		variant = 'default',
		fullScreen = true,
		children
	}: Props = $props();
</script>

<div
	class="osa-bg osa-bg--{variant}"
	class:osa-bg--full={fullScreen}
	role="presentation"
>
	{#if children}
		{@render children()}
	{/if}
</div>

<style>
	.osa-bg {
		width: 100%;
		overflow-x: hidden;
		position: relative;
	}
	.osa-bg--full {
		min-height: 100vh;
		width: 100vw;
	}
	.osa-bg--default {
		background: var(--dbg2, #f5f5f5);
	}
	.osa-bg--dark {
		background: var(--dbg, #1a1a1a);
	}
	.osa-bg--surface {
		background: var(--dbg3, #eee);
	}
</style>
