<script lang="ts">
/**
 * SkeletonGrid — N animated skeleton cards in a CSS grid for card loading states.
 * Uses canopy-shim class from motion.css (skeleton-shimmer keyframe).
 * CSS prefix: skg- (SkeletonGrid)
 * LOC target: ≤ 60.
 *
 * @example
 *   <SkeletonGrid count={6} columns={3} aspectRatio="4/3" />
 */

interface Props {
  /** Number of skeleton cards to render. */
  count?: number;
  /** Number of columns in the grid. */
  columns?: number;
  /** CSS aspect-ratio for each card. */
  aspectRatio?: string;
  class?: string;
}

let { count = 6, columns = 3, aspectRatio = '4/3', class: className = '' }: Props = $props();

const cardCount = $derived(Math.max(1, Math.min(count, 60)));
const colCount = $derived(Math.max(1, Math.min(columns, 12)));
</script>

<div
  class="skg-grid {className}"
  role="status"
  aria-label="Loading"
  aria-busy="true"
  style="--skg-cols: {colCount};"
>
  {#each { length: cardCount } as _, i (i)}
    <div
      class="skg-card canopy-shim"
      style="aspect-ratio: {aspectRatio}; animation-delay: {i * 40}ms;"
      aria-hidden="true"
    ></div>
  {/each}
</div>

<style>
  .skg-grid {
    display: grid;
    grid-template-columns: repeat(var(--skg-cols, 3), 1fr);
    gap: var(--space-3, 0.75rem);
    width: 100%;
  }

  .skg-card {
    width: 100%;
    background: var(--bg-elevated);
    border-radius: 8px;
    border: 1px solid var(--border);
  }
</style>
