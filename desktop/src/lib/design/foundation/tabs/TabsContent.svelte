<script lang="ts">
	import { Tabs as TabsPrimitive } from 'bits-ui';
	import { type Snippet } from 'svelte';
	import { cn } from '$lib/utils';

	interface Props {
		value: string;
		class?: string;
		children: Snippet;
	}

	let { value, class: className = '', children }: Props = $props();
</script>

<TabsPrimitive.Content
	{value}
	class={cn(
		'mt-2 ring-offset-background focus-visible:outline-none',
		'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2',
		className
	)}
>
	{@render children()}
</TabsPrimitive.Content>
