<script lang="ts">
	import { ScrollArea as ScrollAreaPrimitive } from 'bits-ui';
	import { type Snippet } from 'svelte';
	import { cn } from '$lib/utils';

	type ScrollbarVisibility = 'auto' | 'always' | 'scroll' | 'hover';

	interface Props {
		orientation?: 'vertical' | 'horizontal' | 'both';
		scrollbarVisibility?: ScrollbarVisibility;
		class?: string;
		viewportClass?: string;
		children: Snippet;
	}

	let {
		orientation = 'vertical',
		scrollbarVisibility = 'hover',
		class: className = '',
		viewportClass = '',
		children
	}: Props = $props();

	const showVertical = $derived(orientation === 'vertical' || orientation === 'both');
	const showHorizontal = $derived(orientation === 'horizontal' || orientation === 'both');
</script>

<ScrollAreaPrimitive.Root class={cn('relative overflow-hidden', className)}>
	<ScrollAreaPrimitive.Viewport class={cn('h-full w-full rounded-[inherit]', viewportClass)}>
		{@render children()}
	</ScrollAreaPrimitive.Viewport>

	{#if showVertical}
		<ScrollAreaPrimitive.Scrollbar
			orientation="vertical"
			class={cn(
				'flex touch-none select-none transition-colors',
				'h-full w-2.5 border-l border-l-transparent p-[1px]',
				scrollbarVisibility === 'hover' && 'opacity-0 hover:opacity-100',
				scrollbarVisibility === 'auto' && 'data-[state=hidden]:opacity-0'
			)}
		>
			<ScrollAreaPrimitive.Thumb
				class="relative flex-1 rounded-full bg-border"
			/>
		</ScrollAreaPrimitive.Scrollbar>
	{/if}

	{#if showHorizontal}
		<ScrollAreaPrimitive.Scrollbar
			orientation="horizontal"
			class={cn(
				'flex touch-none select-none transition-colors',
				'h-2.5 flex-col border-t border-t-transparent p-[1px]',
				scrollbarVisibility === 'hover' && 'opacity-0 hover:opacity-100',
				scrollbarVisibility === 'auto' && 'data-[state=hidden]:opacity-0'
			)}
		>
			<ScrollAreaPrimitive.Thumb
				class="relative flex-1 rounded-full bg-border"
			/>
		</ScrollAreaPrimitive.Scrollbar>
	{/if}

	<ScrollAreaPrimitive.Corner />
</ScrollAreaPrimitive.Root>
