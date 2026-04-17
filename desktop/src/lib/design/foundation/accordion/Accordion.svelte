<script lang="ts">
	import { type Snippet, setContext } from 'svelte';

	type AccordionType = 'single' | 'multiple';

	interface Props {
		type?: AccordionType;
		value?: string | string[];
		class?: string;
		children: Snippet;
	}

	let {
		type = 'single',
		value = $bindable(type === 'single' ? '' : []),
		class: className = '',
		children
	}: Props = $props();

	function isOpen(itemValue: string): boolean {
		if (type === 'multiple') {
			return Array.isArray(value) && value.includes(itemValue);
		}
		return value === itemValue;
	}

	function toggle(itemValue: string) {
		if (type === 'multiple') {
			const arr = Array.isArray(value) ? value : [];
			if (arr.includes(itemValue)) {
				value = arr.filter((v) => v !== itemValue);
			} else {
				value = [...arr, itemValue];
			}
		} else {
			value = value === itemValue ? '' : itemValue;
		}
	}

	setContext('accordion', { isOpen, toggle });
</script>

<div class="bos-accordion {className}">
	{@render children()}
</div>

<style>
	.bos-accordion {
		display: flex;
		flex-direction: column;
		border: 1px solid rgba(0, 0, 0, 0.07);
		border-radius: 12px;
		overflow: hidden;
	}
	:global(.dark) .bos-accordion {
		border-color: rgba(255, 255, 255, 0.07);
	}
</style>
