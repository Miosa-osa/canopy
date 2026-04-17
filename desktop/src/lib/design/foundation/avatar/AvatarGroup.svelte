<script lang="ts">
	/**
	 * AvatarGroup Component - BusinessOS Style
	 * Stacked avatar group with overflow count badge
	 */
	import Avatar from './Avatar.svelte';

	type AvatarSize = 'xs' | 'sm' | 'default' | 'lg' | 'xl';

	type AvatarItem = {
		src?: string;
		alt?: string;
		fallback: string;
	};

	interface Props {
		avatars: AvatarItem[];
		max?: number;
		size?: AvatarSize;
		overlap?: number;
		class?: string;
	}

	let {
		avatars,
		max = 5,
		size = 'default',
		overlap = 8,
		class: className = ''
	}: Props = $props();

	const visibleAvatars = $derived(avatars.slice(0, max));
	const overflowCount = $derived(Math.max(0, avatars.length - max));

	const sizePx: Record<AvatarSize, number> = {
		xs: 24,
		sm: 28,
		default: 36,
		lg: 44,
		xl: 56
	};

	const avatarPx = $derived(sizePx[size]);
	const totalWidth = $derived(
		visibleAvatars.length * avatarPx -
		(visibleAvatars.length - 1) * overlap +
		(overflowCount > 0 ? avatarPx - overlap : 0)
	);
</script>

<div
	class="bos-avatar-group {className}"
	style="width: {totalWidth}px; height: {avatarPx}px;"
	role="group"
	aria-label="Avatar group"
>
	{#each visibleAvatars as avatar, i (i)}
		<span
			class="bos-avatar-group__item"
			style="left: {i * (avatarPx - overlap)}px; z-index: {visibleAvatars.length - i};"
		>
			<Avatar
				src={avatar.src}
				alt={avatar.alt}
				fallback={avatar.fallback}
				{size}
			/>
		</span>
	{/each}

	{#if overflowCount > 0}
		<span
			class="bos-avatar-group__overflow"
			data-size={size}
			style="left: {visibleAvatars.length * (avatarPx - overlap)}px; z-index: 0; width: {avatarPx}px; height: {avatarPx}px;"
			aria-label="+{overflowCount} more"
		>
			+{overflowCount}
		</span>
	{/if}
</div>

<style>
	.bos-avatar-group {
		position: relative;
		display: inline-flex;
	}

	.bos-avatar-group__item {
		position: absolute;
		top: 0;
		display: block;
		border-radius: 9999px;
		box-shadow: 0 0 0 2px #fff;
	}

	:global(.dark) .bos-avatar-group__item {
		box-shadow: 0 0 0 2px #1e1e1e;
	}

	.bos-avatar-group__overflow {
		position: absolute;
		top: 0;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		border-radius: 9999px;
		background: rgba(0, 0, 0, 0.07);
		border: 1px solid rgba(0, 0, 0, 0.08);
		box-shadow: 0 0 0 2px #fff;
		font-size: 11px;
		font-weight: 700;
		font-family: var(--bos-font-family);
		color: #555;
		letter-spacing: -0.01em;
		user-select: none;
	}

	.bos-avatar-group__overflow[data-size='xs'] { font-size: 9px; }
	.bos-avatar-group__overflow[data-size='sm'] { font-size: 10px; }
	.bos-avatar-group__overflow[data-size='default'] { font-size: 11px; }
	.bos-avatar-group__overflow[data-size='lg'] { font-size: 13px; }
	.bos-avatar-group__overflow[data-size='xl'] { font-size: 15px; }

	:global(.dark) .bos-avatar-group__overflow {
		background: rgba(255, 255, 255, 0.1);
		border-color: rgba(255, 255, 255, 0.1);
		box-shadow: 0 0 0 2px #1e1e1e;
		color: #ccc;
	}
</style>
