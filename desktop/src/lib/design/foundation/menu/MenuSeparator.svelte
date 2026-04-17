<script lang="ts">
	import { DropdownMenu as MenuPrimitive } from 'bits-ui';
	import { cn } from '$lib/utils';

	interface Props {
		class?: string;
	}

	let { class: className = '' }: Props = $props();
</script>

<MenuPrimitive.Separator class={cn('-mx-1 my-1 h-px bg-border', className)} />
