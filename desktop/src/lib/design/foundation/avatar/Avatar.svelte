<script lang="ts">
	/**
	 * Avatar Component - BusinessOS Style
	 * User avatar with image support, initials fallback, and gradient background
	 */

	type AvatarSize = 'xs' | 'sm' | 'default' | 'lg' | 'xl';
	type AvatarShape = 'circle' | 'rounded';

	interface Props {
		src?: string;
		alt?: string;
		fallback: string;
		size?: AvatarSize;
		shape?: AvatarShape;
		class?: string;
	}

	let {
		src,
		alt = '',
		fallback,
		size = 'default',
		shape = 'circle',
		class: className = ''
	}: Props = $props();

	let imageError = $state(false);

	const showImage = $derived(!!src && !imageError);

	const initials = $derived(() => {
		const trimmed = fallback.trim();
		if (!trimmed) return '?';
		const parts = trimmed.split(/\s+/);
		if (parts.length === 1) return trimmed.slice(0, 2).toUpperCase();
		return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
	});
</script>

<span
	class="bos-avatar {className}"
	data-size={size}
	data-shape={shape}
	role="img"
	aria-label={alt || fallback}
>
	{#if showImage}
		<img
			src={src}
			{alt}
			class="bos-avatar__img"
			onerror={() => { imageError = true; }}
		/>
	{:else}
		<span class="bos-avatar__fallback" aria-hidden="true">
			{initials()}
		</span>
	{/if}
</span>

<style>
	.bos-avatar {
		position: relative;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
		overflow: hidden;
		background: linear-gradient(135deg, #333 0%, #111 100%);
		box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.06);
		user-select: none;
	}

	/* Size variants */
	.bos-avatar[data-size='xs'] {
		width: 24px;
		height: 24px;
		font-size: 9px;
	}

	.bos-avatar[data-size='sm'] {
		width: 28px;
		height: 28px;
		font-size: 10px;
	}

	.bos-avatar[data-size='default'] {
		width: 36px;
		height: 36px;
		font-size: 13px;
	}

	.bos-avatar[data-size='lg'] {
		width: 44px;
		height: 44px;
		font-size: 16px;
	}

	.bos-avatar[data-size='xl'] {
		width: 56px;
		height: 56px;
		font-size: 20px;
	}

	/* Shape variants */
	.bos-avatar[data-shape='circle'] {
		border-radius: 9999px;
	}

	.bos-avatar[data-shape='rounded'] {
		border-radius: 8px;
	}

	.bos-avatar__img {
		width: 100%;
		height: 100%;
		object-fit: cover;
		display: block;
	}

	.bos-avatar__fallback {
		font-weight: 600;
		color: rgba(255, 255, 255, 0.92);
		letter-spacing: -0.01em;
		line-height: 1;
		font-family: var(--bos-font-family);
	}

	/* Dark mode — invert gradient for fallback */
	:global(.dark) .bos-avatar {
		background: linear-gradient(135deg, #d4d4d4 0%, #f0f0f0 100%);
		box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.08);
	}

	:global(.dark) .bos-avatar__fallback {
		color: rgba(0, 0, 0, 0.85);
	}
</style>
