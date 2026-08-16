<script lang="ts">
  /**
   * HexPreview — fallback for binary / unknown files.
   * CSS prefix: hxp- (Hex Preview).
   *
   * Shows offset (8 hex digits), 16 bytes per row in hex, and an ASCII gutter.
   * Renders only the first HEX_PREVIEW_BYTES (4 KiB) — full disassembly is
   * out of scope for a preview pane.
   */
  import type { FileRecord } from "$lib/domain/files/types.js";
  import { HEX_PREVIEW_BYTES } from "$lib/domain/file-viewer/types.js";
  import { formatBytes } from "$lib/api/queries/files.js";

  interface Props {
    /** File metadata for the header strip. May be null when only addressed by path. */
    file: FileRecord | null;
    /** Raw bytes (already capped to HEX_PREVIEW_BYTES upstream). */
    bytes: Uint8Array | null;
  }

  let { file, bytes }: Props = $props();

  const ROW = 16;

  /** Build the hex + ascii rows for rendering. */
  const rows = $derived.by(() => {
    if (!bytes) return [] as { offset: string; hex: string; ascii: string }[];
    const out: { offset: string; hex: string; ascii: string }[] = [];
    for (let i = 0; i < bytes.length; i += ROW) {
      const slice = bytes.slice(i, i + ROW);
      const offset = i.toString(16).padStart(8, "0");
      const hex = Array.from(slice)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join(" ");
      const ascii = Array.from(slice)
        .map((b) => (b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : "."))
        .join("");
      out.push({ offset, hex, ascii });
    }
    return out;
  });
</script>

<div class="hxp-root" aria-label="Hex preview">
  <div class="hxp-meta">
    <div class="hxp-meta-row">
      <span class="hxp-meta-key">Type</span>
      <span class="hxp-meta-val">Binary / unknown</span>
    </div>
    {#if file}
      <div class="hxp-meta-row">
        <span class="hxp-meta-key">Size</span>
        <span class="hxp-meta-val">{formatBytes(file.sizeBytes)}</span>
      </div>
      <div class="hxp-meta-row">
        <span class="hxp-meta-key">MIME</span>
        <span class="hxp-meta-val">{file.mimeType ?? "—"}</span>
      </div>
    {/if}
    <div class="hxp-meta-row">
      <span class="hxp-meta-key">Preview</span>
      <span class="hxp-meta-val">First {HEX_PREVIEW_BYTES} bytes</span>
    </div>
  </div>

  {#if !bytes}
    <div class="hxp-empty">Loading preview…</div>
  {:else}
    <div class="hxp-scroll">
      <table class="hxp-table">
        <tbody>
          {#each rows as r, idx (idx)}
            <tr>
              <td class="hxp-offset">{r.offset}</td>
              <td class="hxp-hex">{r.hex}</td>
              <td class="hxp-ascii">{r.ascii}</td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  {/if}
</div>

<style>
  .hxp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    background: var(--bg-inset);
  }

  .hxp-meta {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-3);
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border);
    background: var(--bg-elevated, var(--bg));
    flex-shrink: 0;
  }

  .hxp-meta-row {
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .hxp-meta-key {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .hxp-meta-val {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg);
  }

  .hxp-scroll {
    flex: 1;
    overflow: auto;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
    padding: var(--space-2);
  }

  .hxp-table {
    border-collapse: collapse;
    font-family: var(--font-mono);
    font-size: 11px;
    line-height: 1.5;
    color: var(--fg);
  }

  .hxp-offset {
    color: var(--fg-subtle);
    padding-right: var(--space-3);
    user-select: none;
  }

  .hxp-hex {
    padding-right: var(--space-3);
    white-space: pre;
  }

  .hxp-ascii {
    color: var(--fg-muted);
    white-space: pre;
  }

  .hxp-empty {
    padding: var(--space-4);
    color: var(--fg-subtle);
    font-style: italic;
  }
</style>
