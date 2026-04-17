<script lang="ts">
	/**
	 * Select Component - BusinessOS Style
	 * Dropdown select with monochrome focus ring, status states, and keyboard navigation
	 */
	import { Select as SelectPrimitive } from 'bits-ui';

	type SelectOption = {
		value: string;
		label: string;
		disabled?: boolean;
	};

	type SelectStatus = 'default' | 'error' | 'success';
	type SelectSize = 'default' | 'large';

	interface Props {
		value?: string;
		options: SelectOption[];
		placeholder?: string;
		disabled?: boolean;
		size?: SelectSize;
		status?: SelectStatus;
		class?: string;
		onValueChange?: (value: string) => void;
	}

	let {
		value = $bindable(''),
		options,
		placeholder = 'Select an option...',
		disabled = false,
		size = 'default',
		status = 'default',
		class: className = '',
		onValueChange
	}: Props = $props();

	const selectedLabel = $derived(
		options.find((o) => o.value === value)?.label ?? ''
	);

	function handleValueChange(v: string) {
		value = v;
		onValueChange?.(v);
	}
</script>

<SelectPrimitive.Root
	type="single"
	value={value || undefined}
	onValueChange={handleValueChange}
	{disabled}
>
	<SelectPrimitive.Trigger>
		{#snippet child({ props })}
			<button
				{...props}
				class="bos-select {className}"
				data-size={size}
				data-status={status}
				data-disabled={disabled || undefined}
				aria-label={selectedLabel || placeholder}
			>
				<span class="bos-select__label" class:bos-select__label--placeholder={!selectedLabel}>
					{selectedLabel || placeholder}
				</span>
				<span class="bos-select__chevron" aria-hidden="true">
					<svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
					</svg>
				</span>
			</button>
		{/snippet}
	</SelectPrimitive.Trigger>

	<SelectPrimitive.Portal>
		<SelectPrimitive.Content class="bos-select-content" sideOffset={4} align="start">
			<SelectPrimitive.Viewport class="bos-select-viewport">
				{#each options as option (option.value)}
					<SelectPrimitive.Item
						value={option.value}
						label={option.label}
						disabled={option.disabled}
						class="bos-select-item"
						data-disabled={option.disabled || undefined}
					>
						{#snippet child({ props, selected })}
							<div {...props} class="bos-select-item" data-disabled={option.disabled || undefined} data-selected={selected || undefined}>
								<span class="bos-select-item__check" aria-hidden="true">
									{#if selected}
										<svg width="14" height="14" fill="none" stroke="currentColor" viewBox="0 0 24 24">
											<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
										</svg>
									{/if}
								</span>
								<span class="bos-select-item__label">{option.label}</span>
							</div>
						{/snippet}
					</SelectPrimitive.Item>
				{/each}
			</SelectPrimitive.Viewport>
		</SelectPrimitive.Content>
	</SelectPrimitive.Portal>
</SelectPrimitive.Root>

<style>
	/* ── Trigger ───────────────────────────────────────────────── */
	.bos-select {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		width: 100%;
		height: 32px;
		padding: 0 10px 0 12px;
		font-size: var(--bos-font-sm, 14px);
		font-family: var(--bos-font-family);
		color: var(--bos-v2-text-primary, #121212);
		background-color: var(--bos-v2-layer-background-primary, #ffffff);
		border: 1px solid var(--bos-v2-layer-insideBorder-border, rgba(0, 0, 0, 0.1));
		border-radius: 8px;
		outline: none;
		cursor: pointer;
		user-select: none;
		transition: border-color 0.2s, box-shadow 0.2s;
		text-align: left;
	}

	.bos-select[data-size='large'] {
		height: 40px;
		font-size: var(--bos-font-base, 15px);
	}

	.bos-select:hover:not([data-disabled]) {
		border-color: rgba(0, 0, 0, 0.18);
	}

	.bos-select:focus-visible {
		border-color: rgba(0, 0, 0, 0.3);
		box-shadow: 0 0 0 3px rgba(0, 0, 0, 0.06);
	}

	.bos-select[data-disabled] {
		opacity: 0.5;
		cursor: not-allowed;
	}

	/* Status variants */
	.bos-select[data-status='error'] {
		border-color: var(--bos-error-color, #eb4335);
	}

	.bos-select[data-status='error']:focus-visible {
		box-shadow: 0 0 0 3px rgba(235, 67, 53, 0.1);
	}

	.bos-select[data-status='success'] {
		border-color: var(--bos-success-color, #10b981);
	}

	.bos-select[data-status='success']:focus-visible {
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.bos-select__label {
		flex: 1;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
		line-height: 1;
	}

	.bos-select__label--placeholder {
		color: var(--bos-placeholder-color, #c0bfc1);
	}

	.bos-select__chevron {
		display: flex;
		align-items: center;
		color: var(--bos-v2-icon-primary, #77757d);
		flex-shrink: 0;
		transition: transform 0.18s ease;
	}

	/* Dark mode trigger */
	:global(.dark) .bos-select {
		color: var(--bos-v2-text-primary, #e6e6e6);
		background-color: var(--bos-v2-layer-background-primary, #1e1e1e);
		border-color: var(--bos-v2-layer-insideBorder-border, rgba(255, 255, 255, 0.1));
	}

	:global(.dark) .bos-select:hover:not([data-disabled]) {
		border-color: rgba(255, 255, 255, 0.18);
	}

	:global(.dark) .bos-select:focus-visible {
		border-color: rgba(255, 255, 255, 0.3);
		box-shadow: 0 0 0 3px rgba(255, 255, 255, 0.06);
	}

	:global(.dark) .bos-select__label--placeholder {
		color: var(--bos-placeholder-color, #545459);
	}

	:global(.dark) .bos-select__chevron {
		color: var(--bos-v2-icon-primary, #a6a6ad);
	}

	/* ── Dropdown Panel ────────────────────────────────────────── */
	:global(.bos-select-content) {
		z-index: var(--bos-z-index-popover, 1001);
		min-width: var(--bits-select-trigger-width, 180px);
		max-height: 280px;
		overflow: hidden;
		background-color: var(--bos-v2-layer-background-overlayPanel, #fbfbfc);
		border: 1px solid rgba(0, 0, 0, 0.08);
		border-radius: 12px;
		box-shadow:
			0px 0px 12px rgba(66, 65, 73, 0.14),
			0px 0px 0px 0.5px rgba(0, 0, 0, 0.08);
		outline: none;
	}

	:global(.bos-select-content[data-state='open']) {
		animation: select-in 0.15s ease-out;
	}

	:global(.bos-select-content[data-state='closed']) {
		animation: select-out 0.1s ease-in;
	}

	@keyframes select-in {
		from { opacity: 0; transform: scale(0.96) translateY(-4px); }
		to { opacity: 1; transform: scale(1) translateY(0); }
	}

	@keyframes select-out {
		from { opacity: 1; transform: scale(1); }
		to { opacity: 0; transform: scale(0.96); }
	}

	:global(.dark .bos-select-content) {
		background-color: var(--bos-v2-layer-background-overlayPanel, #252525);
		border-color: rgba(255, 255, 255, 0.08);
		box-shadow:
			0px 0px 12px rgba(0, 0, 0, 0.5),
			0px 0px 0px 0.5px rgba(255, 255, 255, 0.1);
	}

	:global(.bos-select-viewport) {
		padding: 6px;
		max-height: 272px;
		overflow-y: auto;
		overscroll-behavior: contain;
	}

	/* ── Option Items ──────────────────────────────────────────── */
	:global(.bos-select-item) {
		display: flex;
		align-items: center;
		gap: 6px;
		width: 100%;
		min-height: 32px;
		padding: 0 8px;
		border-radius: 6px;
		font-size: var(--bos-font-sm, 14px);
		font-family: var(--bos-font-family);
		color: var(--bos-v2-text-primary, #121212);
		background: transparent;
		cursor: pointer;
		user-select: none;
		outline: none;
		transition: background-color 0.12s;
	}

	:global(.bos-select-item:hover),
	:global(.bos-select-item:focus),
	:global(.bos-select-item[data-highlighted]) {
		background: rgba(0, 0, 0, 0.04);
	}

	:global(.bos-select-item[data-selected]) {
		color: var(--bos-v2-text-primary, #111);
		font-weight: 600;
	}

	:global(.bos-select-item[data-disabled]) {
		opacity: 0.4;
		cursor: not-allowed;
		pointer-events: none;
	}

	:global(.bos-select-item__check) {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 16px;
		height: 16px;
		flex-shrink: 0;
		color: var(--bos-v2-text-primary, #111);
	}

	:global(.bos-select-item__label) {
		flex: 1;
		overflow: hidden;
		text-overflow: ellipsis;
		white-space: nowrap;
	}

	/* Dark mode items */
	:global(.dark .bos-select-item) {
		color: var(--bos-v2-text-primary, #e6e6e6);
	}

	:global(.dark .bos-select-item:hover),
	:global(.dark .bos-select-item:focus),
	:global(.dark .bos-select-item[data-highlighted]) {
		background: rgba(255, 255, 255, 0.07);
	}

	:global(.dark .bos-select-item[data-selected]) {
		color: #fff;
	}

	:global(.dark .bos-select-item__check) {
		color: #fff;
	}
</style>
