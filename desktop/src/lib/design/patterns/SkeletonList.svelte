<script lang="ts">
/**
 * SkeletonList — N animated skeleton rows for list loading states.
 * Uses canopy-shim class from motion.css (skeleton-shimmer keyframe).
 * CSS prefix: skl- (SkeletonList)
 * LOC target: ≤ 60.
 *
 * @example
 *   <SkeletonList count={5} height="2.25rem" gap="0.5rem" />
 */

interface Props {
  /** Number of skeleton rows to render. */
  count?: number;
  /** Height of each row. Any CSS length value. */
  height?: string;
  /** Gap between rows. Any CSS length value. */
  gap?: string;
  class?: string;
}

let { count = 3, height = '2.25rem', gap = '0.5rem', class: className = '' }: Props = $props();

// Clamp count to a sane range — prevents accidental 10K DOM nodes.
const rowCount = $derived(Math.max(1, Math.min(count, 30)));
</script>

<div
  class="skl-list {className}"
  role="status"
  aria-label="Loading"
  aria-busy="true"
  style="--skl-gap: {gap};"
>
  {#each { length: rowCount } as _, i (i)}
    <div
      class="skl-row canopy-shim"
      style="height: {height}; animation-delay: {i * 60}ms;"
      aria-hidden="true"
    ></div>
  {/each}
</div>

<style>
  .skl-list {
    display: flex;
    flex-direction: column;
    gap: var(--skl-gap, 0.5rem);
    width: 100%;
  }

  .skl-row {
    width: 100%;
    background: var(--bg-elevated);
    border-radius: 6px;
    border: 1px solid var(--border);
  }
</style>
