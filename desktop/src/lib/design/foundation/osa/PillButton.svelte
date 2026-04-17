<!--
	PillButton.svelte
	Desktop-style pill button with grayscale colors.
	Uses the Foundation btn-pill CSS system from app.css.

	Usage:
	<PillButton variant="primary" onclick={handleClick}>
		Sign In
	</PillButton>
-->
<script lang="ts">
	import type { Snippet } from 'svelte';

	type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'outline' | 'soft' | 'danger' | 'success' | 'warning' | 'link';
	type ButtonSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

	interface Props {
		variant?: ButtonVariant;
		size?: ButtonSize;
		disabled?: boolean;
		loading?: boolean;
		block?: boolean;
		iconOnly?: boolean;
		type?: 'button' | 'submit' | 'reset';
		onclick?: (e: MouseEvent) => void;
		children?: Snippet;
		class?: string;
	}

	let {
		variant = 'primary',
		size = 'md',
		disabled = false,
		loading = false,
		block = false,
		iconOnly = false,
		type = 'button',
		onclick,
		children,
		class: className = ''
	}: Props = $props();

	const variantClass = `btn-pill-${variant}`;
	const sizeClass = size !== 'md' ? `btn-pill-${size}` : '';
	const blockClass = block ? 'btn-pill-block' : '';
	const iconClass = iconOnly ? 'btn-pill-icon' : '';
	const loadingClass = loading ? 'btn-pill-loading' : '';
	const classes = ['btn-pill', variantClass, sizeClass, blockClass, iconClass, loadingClass, className].filter(Boolean).join(' ');
</script>

<button
	{type}
	class={classes}
	disabled={disabled || loading}
	{onclick}
>
	{#if loading}
		<svg class="btn-pill-spinner" width="16" height="16" viewBox="0 0 24 24" fill="none">
			<circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="3" opacity="0.25" />
			<path d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" fill="currentColor" opacity="0.75" />
		</svg>
	{/if}

	{#if children}
		{@render children()}
	{/if}
</button>

<style>
	.btn-pill-spinner {
		animation: spin 0.6s linear infinite;
	}
	@keyframes spin {
		to { transform: rotate(360deg); }
	}
</style>
