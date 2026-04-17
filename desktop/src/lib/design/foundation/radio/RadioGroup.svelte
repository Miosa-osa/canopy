<script lang="ts">
	/**
	 * RadioGroup Component - BusinessOS Style
	 * Provides context to RadioItem children for value management.
	 */
	import { setContext } from 'svelte';
	import type { Snippet } from 'svelte';

	type Orientation = 'vertical' | 'horizontal';

	interface Props {
		value?: string;
		name: string;
		disabled?: boolean;
		orientation?: Orientation;
		children?: Snippet;
		onchange?: (value: string) => void;
	}

	let {
		value = $bindable(''),
		name,
		disabled = false,
		orientation = 'vertical',
		children,
		onchange
	}: Props = $props();

	function selectValue(newValue: string) {
		if (disabled) return;
		value = newValue;
		onchange?.(newValue);
	}

	setContext('radio-group', {
		get value() { return value; },
		get name() { return name; },
		get disabled() { return disabled; },
		select: selectValue,
	});
</script>

<div
	role="radiogroup"
	class="bos-radio-group"
	data-orientation={orientation}
	aria-disabled={disabled || undefined}
>
	{@render children?.()}
</div>

<style>
	.bos-radio-group {
		display: flex;
		flex-direction: column;
		gap: 10px;
	}

	.bos-radio-group[data-orientation='horizontal'] {
		flex-direction: row;
		flex-wrap: wrap;
		gap: 20px;
	}
</style>
