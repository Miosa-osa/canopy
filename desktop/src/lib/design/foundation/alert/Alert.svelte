<script lang="ts">
	import { type Snippet } from 'svelte';
	import { X } from 'lucide-svelte';

	type AlertVariant = 'info' | 'success' | 'warning' | 'error';

	interface Props {
		variant?: AlertVariant;
		title?: string;
		dismissible?: boolean;
		ondismiss?: () => void;
		class?: string;
		children?: Snippet;
	}

	let {
		variant = 'info',
		title,
		dismissible = false,
		ondismiss,
		class: className = '',
		children
	}: Props = $props();

	let dismissed = $state(false);

	function handleDismiss() {
		dismissed = true;
		ondismiss?.();
	}
</script>

{#if !dismissed}
	<div class="bos-alert bos-alert--{variant} {className}" role="alert">
		<span class="bos-alert__icon" aria-hidden="true">
			{#if variant === 'success'}
				<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
			{:else if variant === 'warning'}
				<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
				</svg>
			{:else if variant === 'error'}
				<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
			{:else}
				<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
				</svg>
			{/if}
		</span>

		<div class="bos-alert__body">
			{#if title}
				<div class="bos-alert__title">{title}</div>
			{/if}
			{#if children}
				<div class="bos-alert__content">
					{@render children()}
				</div>
			{/if}
		</div>

		{#if dismissible}
			<button class="bos-alert__dismiss" onclick={handleDismiss} aria-label="Dismiss alert">
				<X size={14} />
			</button>
		{/if}
	</div>
{/if}

<style>
	.bos-alert {
		position: relative;
		display: flex;
		align-items: flex-start;
		gap: 12px;
		padding: 14px 16px;
		border-radius: 10px;
		border: 1px solid transparent;
		border-left-width: 4px;
		box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
	}

	/* ── Variant: info ── */
	.bos-alert--info {
		background: rgba(0, 0, 0, 0.025);
		border-color: rgba(0, 0, 0, 0.06);
		border-left-color: #71717a;
		color: #3f3f46;
	}
	:global(.dark) .bos-alert--info {
		background: rgba(255, 255, 255, 0.04);
		border-color: rgba(255, 255, 255, 0.06);
		border-left-color: #71717a;
		color: #a1a1aa;
	}

	/* ── Variant: success ── */
	.bos-alert--success {
		background: #f0fdf4;
		border-color: #bbf7d0;
		border-left-color: #22c55e;
		color: #15803d;
	}
	:global(.dark) .bos-alert--success {
		background: rgba(34, 197, 94, 0.08);
		border-color: rgba(34, 197, 94, 0.15);
		border-left-color: #22c55e;
		color: #4ade80;
	}

	/* ── Variant: warning ── */
	.bos-alert--warning {
		background: #fffbeb;
		border-color: #fde68a;
		border-left-color: #f59e0b;
		color: #92400e;
	}
	:global(.dark) .bos-alert--warning {
		background: rgba(245, 158, 11, 0.08);
		border-color: rgba(245, 158, 11, 0.2);
		border-left-color: #f59e0b;
		color: #fbbf24;
	}

	/* ── Variant: error ── */
	.bos-alert--error {
		background: #fef2f2;
		border-color: #fecaca;
		border-left-color: #ef4444;
		color: #991b1b;
	}
	:global(.dark) .bos-alert--error {
		background: rgba(239, 68, 68, 0.08);
		border-color: rgba(239, 68, 68, 0.15);
		border-left-color: #ef4444;
		color: #f87171;
	}

	/* ── Icon ── */
	.bos-alert__icon {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		width: 16px;
		height: 16px;
		margin-top: 1px;
	}

	/* ── Body ── */
	.bos-alert__body {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.bos-alert__title {
		font-size: 13px;
		font-weight: 600;
		line-height: 1.4;
	}

	.bos-alert__content {
		font-size: 13px;
		line-height: 1.5;
		opacity: 0.85;
	}

	.bos-alert__content :global(a) {
		font-weight: 600;
		text-decoration: underline;
		text-underline-offset: 2px;
	}

	/* ── Dismiss button ── */
	.bos-alert__dismiss {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 24px;
		height: 24px;
		border-radius: 6px;
		border: none;
		background: transparent;
		cursor: pointer;
		color: currentColor;
		opacity: 0.5;
		transition: opacity 0.15s, background 0.15s;
		margin-top: -2px;
		margin-right: -4px;
	}

	.bos-alert__dismiss:hover {
		opacity: 1;
		background: rgba(0, 0, 0, 0.06);
	}

	:global(.dark) .bos-alert__dismiss:hover {
		background: rgba(255, 255, 255, 0.1);
	}
</style>
