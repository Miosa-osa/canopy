<script lang="ts">
/**
 * WorkspaceStatsTiles — 4-tile stat row for workspace overview tab.
 * CSS prefix: wst-
 * LOC target: ≤ 100
 */

interface Props {
  sessions: number | null;
  files: number | null;
  sizeBytes: number | null;
  createdAt: string | null;
}

let { sessions, files, sizeBytes, createdAt }: Props = $props();

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function formatDate(iso: string | null): string {
  if (!iso) return '—';
  return new Date(iso).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  });
}

const tiles = $derived([
  { label: 'Sessions', value: sessions !== null ? String(sessions) : '—' },
  { label: 'Files', value: files !== null ? files.toLocaleString() : '—' },
  { label: 'Size', value: sizeBytes !== null ? formatBytes(sizeBytes) : '—' },
  { label: 'Created', value: formatDate(createdAt) },
]);
</script>

<div class="wst-row">
  {#each tiles as tile (tile.label)}
    <div class="wst-tile glass-card">
      <span class="wst-value">{tile.value}</span>
      <span class="wst-label">{tile.label}</span>
    </div>
  {/each}
</div>

<style>
  .wst-row {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 640px) {
    .wst-row { grid-template-columns: repeat(2, 1fr); }
  }

  .wst-tile {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    padding: var(--space-4);
    align-items: flex-start;
  }

  .wst-value {
    font-family: var(--font-mono);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.2;
  }

  .wst-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
</style>
