<script lang="ts">
	import { type Snippet } from 'svelte';
	import { cn } from '$lib/utils';

	interface Props {
		class?: string;
		children: Snippet;
	}

	let { class: className = '', children }: Props = $props();
</script>

<!-- Menu label - a simple text element for labeling groups -->
<div role="none" class={cn('px-2 py-1.5 text-sm font-semibold', className)}>
	{@render children()}
</div>
