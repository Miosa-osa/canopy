<script lang="ts">
	import { fly } from 'svelte/transition';
	import { quintOut } from 'svelte/easing';
	import { X } from 'lucide-svelte';
	import type { Toast } from './toast.js';
	import { toast as toastStore } from './toast.js';

	interface Props {
		item: Toast;
	}

	let { item }: Props = $props();

	function dismiss() {
		toastStore.dismiss(item.id);
	}
</script>

<div
	class="bos-toast bos-toast--{item.type}"
	role="alert"
	aria-live="assertive"
	in:fly={{ x: 64, duration: 280, easing: quintOut }}
	out:fly={{ x: 64, duration: 200, easing: quintOut }}
>
	<span class="bos-toast__accent" aria-hidden="true"></span>

	<span class="bos-toast__icon" aria-hidden="true">
		{#if item.type === 'success'}
			<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/>
			</svg>
		{:else if item.type === 'warning'}
			<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
			</svg>
		{:else if item.type === 'error'}
			<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
			</svg>
		{:else}
			<svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
			</svg>
		{/if}
	</span>

	<div class="bos-toast__body">
		<div class="bos-toast__title">{item.title}</div>
		{#if item.description}
			<div class="bos-toast__desc">{item.description}</div>
		{/if}
	</div>

	<button class="bos-toast__close" onclick={dismiss} aria-label="Dismiss notification">
		<X size={13} />
	</button>
</div>

<style>
	.bos-toast {
		position: relative;
		display: flex;
		align-items: flex-start;
		gap: 10px;
		padding: 13px 14px 13px 18px;
		min-width: 280px;
		max-width: 380px;
		border-radius: 12px;
		background: #1a1a1a;
		color: #e5e5e5;
		box-shadow:
			0 4px 16px rgba(0, 0, 0, 0.35),
			0 1px 4px rgba(0, 0, 0, 0.2),
			inset 0 0 0 1px rgba(255, 255, 255, 0.06);
		overflow: hidden;
	}

	:global(.dark) .bos-toast {
		background: #111;
		box-shadow:
			0 4px 16px rgba(0, 0, 0, 0.5),
			0 1px 4px rgba(0, 0, 0, 0.3),
			inset 0 0 0 1px rgba(255, 255, 255, 0.04);
	}

	/* Accent line on left edge */
	.bos-toast__accent {
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 3px;
		border-radius: 12px 0 0 12px;
	}

	.bos-toast--success .bos-toast__accent { background: #22c55e; }
	.bos-toast--warning .bos-toast__accent { background: #f59e0b; }
	.bos-toast--error   .bos-toast__accent { background: #ef4444; }
	.bos-toast--info    .bos-toast__accent { background: #71717a; }

	/* Icon */
	.bos-toast__icon {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		width: 16px;
		height: 16px;
		margin-top: 1px;
	}

	.bos-toast--success .bos-toast__icon { color: #4ade80; }
	.bos-toast--warning .bos-toast__icon { color: #fbbf24; }
	.bos-toast--error   .bos-toast__icon { color: #f87171; }
	.bos-toast--info    .bos-toast__icon { color: #a1a1aa; }

	/* Body */
	.bos-toast__body {
		flex: 1;
		min-width: 0;
		display: flex;
		flex-direction: column;
		gap: 3px;
	}

	.bos-toast__title {
		font-size: 13px;
		font-weight: 600;
		color: #f0f0f0;
		line-height: 1.4;
	}

	.bos-toast__desc {
		font-size: 12px;
		color: #888;
		line-height: 1.5;
	}

	/* Close button */
	.bos-toast__close {
		flex-shrink: 0;
		display: flex;
		align-items: center;
		justify-content: center;
		width: 22px;
		height: 22px;
		border-radius: 6px;
		border: none;
		background: transparent;
		cursor: pointer;
		color: #666;
		transition: color 0.15s, background 0.15s;
		margin-top: -2px;
		margin-right: -2px;
	}

	.bos-toast__close:hover {
		color: #ccc;
		background: rgba(255, 255, 255, 0.08);
	}
</style>
