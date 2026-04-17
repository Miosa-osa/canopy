<script lang="ts">
	import { Tabs as TabsPrimitive } from 'bits-ui';
	import { type Snippet } from 'svelte';
	import { cn } from '$lib/utils';

	interface Props {
		class?: string;
		children: Snippet;
	}

	let { class: className = '', children }: Props = $props();
</script>

<TabsPrimitive.List
	class={cn(
		'inline-flex h-9 items-center justify-center rounded-lg bg-muted p-1 text-muted-foreground',
		className
	)}
>
	{@render children()}
</TabsPrimitive.List>
