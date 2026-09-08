<script lang="ts">
/**
 * McpServerList — connected MCP servers (Phase A: stub).
 *
 * Pulls from `GET /api/v1/mcp/servers`, which returns an empty list until
 * the MCP server-management context is built (Track J — see roadmap).
 * Toggle wiring is intentionally a no-op for Phase A; documented in
 * mcp-wiring.md.
 *
 * CSS prefix: ms-
 */
import { createQuery } from '@tanstack/svelte-query';
import { Plug } from 'lucide-svelte';
import { mcpServersQuery } from '$lib/api/queries/mcp.js';
import Toggle from '$lib/design/foundation/toggle/Toggle.svelte';

const servers = createQuery(mcpServersQuery());
</script>

<section class="ms-root" aria-label="Connected MCP servers">
  <header class="ms-header">
    <Plug size={12} aria-hidden="true" />
    <h3 class="ms-title">MCP servers</h3>
    <span class="ms-count">{($servers.data ?? []).length}</span>
  </header>

  {#if $servers.isLoading}
    <p class="ms-empty">Loading…</p>
  {:else if $servers.isError}
    <p class="ms-empty ms-empty--err">
      Server endpoint not yet available — Phase B.
    </p>
  {:else if ($servers.data ?? []).length === 0}
    <p class="ms-empty">
      No MCP servers connected yet.
      <span class="ms-empty__hint">Server management ships in Phase B (roadmap Track J).</span>
    </p>
  {:else}
    <ul class="ms-list">
      {#each $servers.data ?? [] as srv (srv.id)}
        <li class="ms-row" data-status={srv.status}>
          <span class="ms-row__name">{srv.name}</span>
          {#if srv.url}
            <span class="ms-row__url">{srv.url}</span>
          {/if}
          <span class="ms-row__count">{srv.toolCount} tools</span>
          <Toggle checked={srv.status === 'connected'} label="Toggle {srv.name}" disabled />
        </li>
      {/each}
    </ul>
  {/if}
</section>

<style>
  .ms-root {
    display: flex;
    flex-direction: column;
    border-top: 1px solid var(--border);
    font-family: var(--font-sans);
  }

  .ms-header {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 8px 12px;
    color: var(--fg-muted);
    border-bottom: 1px solid var(--border);
  }

  .ms-title {
    margin: 0;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    flex: 1;
  }

  .ms-count {
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .ms-empty {
    margin: 0;
    padding: 14px 12px;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
    line-height: 1.45;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .ms-empty--err { color: oklch(0.6 0.18 25); }

  .ms-empty__hint {
    color: var(--fg-subtle);
    font-size: 11px;
    font-style: italic;
  }

  .ms-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }

  .ms-row {
    display: grid;
    grid-template-columns: 1fr auto auto auto;
    gap: 12px;
    align-items: center;
    padding: 8px 12px;
    border-bottom: 1px solid color-mix(in oklch, var(--border) 50%, transparent);
    font-size: var(--text-sm);
  }

  .ms-row__name { color: var(--fg); font-weight: 500; }
  .ms-row__url {
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11px;
    color: var(--fg-subtle);
  }
  .ms-row__count { font-size: 11px; color: var(--fg-muted); }
</style>
