<script lang="ts">
/**
 * CsvTableViewer — sortable HTML table for CSV / TSV.
 * CSS prefix: ctv- (Csv Table Viewer).
 *
 * Lightweight RFC-4180-ish parser inline (handles quoted fields, escaped
 * quotes, embedded delimiters). NO new library dependency.
 *
 * Sort-by-column toggles between asc / desc / off.
 * First row is treated as header by default; toggle via the "Header row"
 * checkbox if your data has no header.
 */

interface Props {
  /** Raw CSV/TSV source. */
  content: string;
  /** Column delimiter. Defaults to "," — pass "\t" for TSV. */
  delimiter?: string;
}

let { content, delimiter = ',' }: Props = $props();

// ── Parser ──────────────────────────────────────────────────────────────────

/** Parse a delimiter-separated string into rows of strings. */
function parseDsv(src: string, delim: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (inQuotes) {
      if (ch === '"' && src[i + 1] === '"') {
        field += '"';
        i++;
      } else if (ch === '"') {
        inQuotes = false;
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === delim) {
      row.push(field);
      field = '';
    } else if (ch === '\n') {
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else if (ch === '\r') {
      // skip — handled by \n
    } else {
      field += ch;
    }
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

const rows = $derived(parseDsv(content, delimiter));

// ── Header toggle + sort state ──────────────────────────────────────────────

let firstRowIsHeader = $state(true);
let sortCol = $state<number | null>(null);
let sortDir = $state<'asc' | 'desc'>('asc');

const header = $derived(firstRowIsHeader && rows.length > 0 ? rows[0] : null);
const dataRows = $derived(firstRowIsHeader ? rows.slice(1) : rows);

/** Sorted view of dataRows. Stable when sortCol is null. */
const sortedRows = $derived.by(() => {
  if (sortCol === null) return dataRows;
  const col = sortCol;
  const dir = sortDir === 'asc' ? 1 : -1;
  return [...dataRows].sort((a, b) => {
    const av = a[col] ?? '';
    const bv = b[col] ?? '';
    // Numeric compare when both look like numbers.
    const an = Number(av);
    const bn = Number(bv);
    if (!Number.isNaN(an) && !Number.isNaN(bn) && av !== '' && bv !== '') {
      return (an - bn) * dir;
    }
    return av.localeCompare(bv) * dir;
  });
});

function handleSort(col: number): void {
  if (sortCol === col) {
    sortDir = sortDir === 'asc' ? 'desc' : 'asc';
  } else {
    sortCol = col;
    sortDir = 'asc';
  }
}

// Cap displayed rows for perf — at this point a virtualised view would be
// the right call; flag it for the next iteration if it bites us.
const ROW_CAP = 1000;
</script>

<div class="ctv-root" role="region" aria-label="Tabular preview">
  <div class="ctv-toolbar">
    <label class="ctv-toolbar-item">
      <input type="checkbox" bind:checked={firstRowIsHeader} />
      Header row
    </label>
    <span class="ctv-stats">
      {dataRows.length} {dataRows.length === 1 ? "row" : "rows"}
      {#if dataRows.length > ROW_CAP}<em> (showing first {ROW_CAP})</em>{/if}
    </span>
  </div>

  <div class="ctv-scroll">
    <table class="ctv-table">
      {#if header}
        <thead>
          <tr>
            {#each header as cell, idx (idx)}
              <th>
                <button
                  type="button"
                  class="ctv-sort-btn"
                  onclick={() => handleSort(idx)}
                  aria-label="Sort by {cell}"
                >
                  {cell}
                  {#if sortCol === idx}
                    <span class="ctv-sort-indicator">{sortDir === "asc" ? "▲" : "▼"}</span>
                  {/if}
                </button>
              </th>
            {/each}
          </tr>
        </thead>
      {/if}
      <tbody>
        {#each sortedRows.slice(0, ROW_CAP) as row, ri (ri)}
          <tr>
            {#each row as cell, ci (ci)}
              <td>{cell}</td>
            {/each}
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
</div>

<style>
  .ctv-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg);
  }

  .ctv-toolbar {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    background: var(--bg-elevated, var(--bg));
  }

  .ctv-toolbar-item {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    cursor: pointer;
  }

  .ctv-stats {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin-left: auto;
  }

  .ctv-scroll {
    flex: 1;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .ctv-table {
    border-collapse: collapse;
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    width: max-content;
    min-width: 100%;
  }

  .ctv-table th,
  .ctv-table td {
    border: 1px solid var(--border);
    padding: 4px var(--space-2);
    text-align: left;
    vertical-align: top;
    white-space: nowrap;
    color: var(--fg);
  }

  .ctv-table thead th {
    position: sticky;
    top: 0;
    background: var(--bg-elevated, var(--bg));
    font-weight: 600;
    color: var(--fg);
    padding: 0;
  }

  .ctv-sort-btn {
    display: flex;
    align-items: center;
    gap: 4px;
    background: transparent;
    border: none;
    width: 100%;
    padding: 4px var(--space-2);
    font: inherit;
    color: inherit;
    text-align: left;
    cursor: pointer;
  }

  .ctv-sort-btn:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
  }

  .ctv-sort-indicator {
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .ctv-table tbody tr:nth-child(even) {
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }
</style>
