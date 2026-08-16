/**
 * spatial-layouts — pure geometry utilities for auto-arranging items.
 * No imports. No side-effects. Zero dependencies.
 */

export interface LayoutItem {
  id: string;
  width: number;
  height: number;
}

export interface PositionedItem extends LayoutItem {
  x: number;
  y: number;
}

export interface LayoutOptions {
  /** Pixel gap between items. Default 16. */
  gap?: number;
  /** Fixed column count. Default: auto-computed from containerWidth / avg item width. */
  columns?: number;
  /** Total container width in pixels. Default 800. */
  containerWidth?: number;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function resolveGap(opts?: LayoutOptions): number {
  return opts?.gap ?? 16;
}

function resolveContainer(opts?: LayoutOptions): number {
  return opts?.containerWidth ?? 800;
}

function resolveColumns(items: LayoutItem[], opts?: LayoutOptions): number {
  if (opts?.columns && opts.columns > 0) return opts.columns;
  const gap = resolveGap(opts);
  const container = resolveContainer(opts);
  const avgWidth =
    items.length > 0
      ? items.reduce((s, it) => s + it.width, 0) / items.length
      : 120;
  return Math.max(1, Math.floor((container + gap) / (avgWidth + gap)));
}

function overlaps(a: PositionedItem, b: PositionedItem, gap: number): boolean {
  return (
    a.x < b.x + b.width + gap &&
    a.x + a.width + gap > b.x &&
    a.y < b.y + b.height + gap &&
    a.y + a.height + gap > b.y
  );
}

// ── seeded PRNG (mulberry32) ──────────────────────────────────────────────────

function mulberry32(seed: number): () => number {
  let s = seed;
  return () => {
    s |= 0;
    s = (s + 0x6d2b79f5) | 0;
    let z = Math.imul(s ^ (s >>> 15), 1 | s);
    z = (z + Math.imul(z ^ (z >>> 7), 61 | z)) ^ z;
    return ((z ^ (z >>> 14)) >>> 0) / 4294967296;
  };
}

// ── gridLayout ────────────────────────────────────────────────────────────────

/**
 * Grid layout: places items in uniform rows of `columns` columns.
 * Items are positioned left-to-right, top-to-bottom. Row height = tallest item
 * in that row. Items narrower than the column cell are left-aligned within it.
 *
 * @param items - Items to lay out.
 * @param opts  - Gap, column count, and container width overrides.
 * @returns     - A new array of items with x/y coordinates assigned.
 */
export function gridLayout(
  items: LayoutItem[],
  opts?: LayoutOptions,
): PositionedItem[] {
  if (items.length === 0) return [];

  const gap = resolveGap(opts);
  const columns = resolveColumns(items, opts);
  const result: PositionedItem[] = [];

  let x = 0;
  let y = 0;
  let rowMaxH = 0;
  let col = 0;

  for (const item of items) {
    result.push({ ...item, x, y });

    rowMaxH = Math.max(rowMaxH, item.height);
    col++;

    if (col >= columns) {
      // Move to next row
      x = 0;
      y += rowMaxH + gap;
      rowMaxH = 0;
      col = 0;
    } else {
      x += item.width + gap;
    }
  }

  return result;
}

// ── bentoLayout ───────────────────────────────────────────────────────────────

/**
 * Bento layout: variable-size tiles packed column-by-column.
 * Items whose width exceeds the average are allocated 2 columns; all others
 * receive 1 column. Column heights are tracked independently so items flow
 * into the shortest column first (greedy bin-packing).
 *
 * @param items - Items to lay out.
 * @param opts  - Gap, column count, and container width overrides.
 * @returns     - A new array of items with x/y coordinates assigned.
 */
export function bentoLayout(
  items: LayoutItem[],
  opts?: LayoutOptions,
): PositionedItem[] {
  if (items.length === 0) return [];

  const gap = resolveGap(opts);
  const columns = resolveColumns(items, opts);
  const container = resolveContainer(opts);

  const colWidth = (container - gap * (columns - 1)) / columns;
  const colHeights = new Array<number>(columns).fill(0);

  const avgWidth = items.reduce((s, it) => s + it.width, 0) / items.length;

  const result: PositionedItem[] = [];

  for (const item of items) {
    const span = item.width > avgWidth && columns >= 2 ? 2 : 1;

    // Find the leftmost column where `span` consecutive columns are shallowest.
    let bestCol = 0;
    let bestH = Infinity;
    for (let c = 0; c <= columns - span; c++) {
      const maxH = Math.max(...colHeights.slice(c, c + span));
      if (maxH < bestH) {
        bestH = maxH;
        bestCol = c;
      }
    }

    const x = bestCol * (colWidth + gap);
    const y = bestH > 0 ? bestH + gap : 0;
    result.push({ ...item, x, y });

    const newH = y + item.height;
    for (let c = bestCol; c < bestCol + span; c++) {
      colHeights[c] = newH;
    }
  }

  return result;
}

// ── scatterLayout ─────────────────────────────────────────────────────────────

/**
 * Scatter layout: pseudo-random placement with collision avoidance.
 * Items are placed one at a time at a seeded random position within the
 * container. If the candidate position overlaps any already-placed item
 * (including gap clearance), it is shifted rightward then downward in small
 * increments until a clear slot is found.
 *
 * @param items - Items to lay out.
 * @param opts  - Gap, container width, and optional PRNG seed.
 * @returns     - A new array of items with x/y coordinates assigned.
 */
export function scatterLayout(
  items: LayoutItem[],
  opts?: LayoutOptions & { seed?: number },
): PositionedItem[] {
  if (items.length === 0) return [];

  const gap = resolveGap(opts);
  const container = resolveContainer(opts);
  const seed = opts?.seed ?? 0x4f1a2b3c;
  const rand = mulberry32(seed);

  // Estimate a reasonable canvas height for initial random placement.
  const totalArea = items.reduce(
    (s, it) => s + (it.width + gap) * (it.height + gap),
    0,
  );
  const canvasH = Math.max(600, Math.ceil(totalArea / container) * 2);

  const placed: PositionedItem[] = [];
  const step = gap > 0 ? Math.max(4, Math.floor(gap / 2)) : 4;

  for (const item of items) {
    // Random starting position within bounds.
    const maxX = Math.max(0, container - item.width);
    const maxY = Math.max(0, canvasH - item.height);

    let x = Math.floor(rand() * (maxX + 1));
    let y = Math.floor(rand() * (maxY + 1));

    // Shift until no collision — scan right then wrap to next row.
    let attempts = 0;
    const maxAttempts = Math.ceil(container / step) * Math.ceil(canvasH / step);

    while (attempts < maxAttempts) {
      const candidate: PositionedItem = { ...item, x, y };
      const collision = placed.some((p) => overlaps(candidate, p, gap));
      if (!collision) break;

      x += step;
      if (x + item.width > container) {
        x = 0;
        y += step;
      }
      attempts++;
    }

    placed.push({ ...item, x, y });
  }

  return placed;
}
