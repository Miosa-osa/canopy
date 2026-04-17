<script lang="ts">
	/**
	 * Tooltip Component - BusinessOS Style
	 * Modern document-centric tooltip patterns
	 */
	import { Tooltip as TooltipPrimitive } from 'bits-ui';
	import { type Snippet } from 'svelte';

	type TooltipSide = 'top' | 'right' | 'bottom' | 'left';

	interface Props {
		content?: string | Snippet;
		shortcut?: string | string[];
		side?: TooltipSide;
		align?: 'start' | 'center' | 'end';
		delayDuration?: number;
		class?: string;
		children: Snippet;
	}

	let {
		content,
		shortcut,
		side = 'top',
		align = 'center',
		delayDuration = 500,
		class: className = '',
		children
	}: Props = $props();

	const formatShortcut = (shortcut: string | string[]): string[] => {
		const shortcuts = Array.isArray(shortcut) ? shortcut : [shortcut];
		return shortcuts.map((s) => {
			return s
				.replace('$mod', navigator?.platform?.includes('Mac') ? '⌘' : 'Ctrl')
				.replace('$alt', navigator?.platform?.includes('Mac') ? '⌥' : 'Alt')
				.replace('$shift', navigator?.platform?.includes('Mac') ? '⇧' : 'Shift');
		});
	};

	const formattedShortcut = $derived(shortcut ? formatShortcut(shortcut) : []);
</script>

{#if content}
	<TooltipPrimitive.Provider>
		<TooltipPrimitive.Root {delayDuration}>
			<TooltipPrimitive.Trigger>
				{#snippet child({ props })}
					<span {...props}>
						{@render children()}
					</span>
				{/snippet}
			</TooltipPrimitive.Trigger>
			<TooltipPrimitive.Portal>
				<TooltipPrimitive.Content
					{side}
					{align}
					sideOffset={6}
					class="bos-tooltip {className}"
				>
					{#if shortcut}
						<div class="bos-tooltip__with-shortcut">
							<span class="bos-tooltip__text">
								{#if typeof content === 'string'}
									{content}
								{:else if content}
									{@render content()}
								{/if}
							</span>
							<div class="bos-tooltip__shortcut-group">
								{#each formattedShortcut as key}
									<kbd class="bos-tooltip__shortcut">{key}</kbd>
								{/each}
							</div>
						</div>
					{:else if typeof content === 'string'}
						{content}
					{:else}
						{@render content()}
					{/if}
				</TooltipPrimitive.Content>
			</TooltipPrimitive.Portal>
		</TooltipPrimitive.Root>
	</TooltipPrimitive.Provider>
{:else}
	{@render children()}
{/if}

<style>
	:global(.bos-tooltip) {
		z-index: var(--bos-z-index-popover, 1001);
		max-width: 280px;
		padding: 4px 12px;
		font-size: var(--bos-font-xs, 12px);
		font-family: var(--bos-font-family);
		line-height: 1.4;
		color: #ffffff;
		background-color: var(--bos-tooltip, #424149);
		border-radius: 8px;
		box-shadow: var(--bos-shadow-2);
		user-select: none;
	}

	/* Animation */
	:global(.bos-tooltip[data-state='delayed-open']) {
		animation: tooltip-in 0.15s ease-out;
	}

	:global(.bos-tooltip[data-state='closed']) {
		animation: tooltip-out 0.1s ease-in;
	}

	@keyframes tooltip-in {
		from {
			opacity: 0;
			transform: scale(0.96);
		}
		to {
			opacity: 1;
			transform: scale(1);
		}
	}

	@keyframes tooltip-out {
		from {
			opacity: 1;
			transform: scale(1);
		}
		to {
			opacity: 0;
			transform: scale(0.96);
		}
	}

	:global(.bos-tooltip__with-shortcut) {
		display: flex;
		align-items: center;
		gap: 12px;
	}

	:global(.bos-tooltip__text) {
		flex: 1;
	}

	:global(.bos-tooltip__shortcut-group) {
		display: flex;
		gap: 4px;
	}

	:global(.bos-tooltip__shortcut) {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		min-width: 20px;
		height: 20px;
		padding: 0 6px;
		font-size: 10px;
		font-family: var(--bos-font-code-family);
		font-weight: 500;
		color: var(--bos-v2-text-secondary, #8e8d91);
		background-color: rgba(255, 255, 255, 0.1);
		border-radius: 4px;
	}

	/* Dark mode - tooltip stays same but shortcut colors adjust */
	:global(.dark .bos-tooltip) {
		background-color: var(--bos-tooltip, #e6e6e6);
		color: #1e1e1e;
	}

	:global(.dark .bos-tooltip__shortcut) {
		color: var(--bos-v2-text-secondary, #545459);
		background-color: rgba(0, 0, 0, 0.1);
	}
</style>
