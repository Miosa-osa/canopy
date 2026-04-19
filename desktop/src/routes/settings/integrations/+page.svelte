<script lang="ts">
/**
 * Settings › Integrations — OAuth integration placeholders.
 * All connections are disabled until OAuth ships in Week 11-12.
 */

interface Integration {
  id: string;
  name: string;
  description: string;
  icon: 'mail' | 'calendar' | 'users' | 'message-circle';
}

const INTEGRATIONS: Integration[] = [
  {
    id: 'gmail',
    name: 'Gmail',
    description: 'Read and send emails from Canopy sessions.',
    icon: 'mail',
  },
  {
    id: 'google-calendar',
    name: 'Google Calendar',
    description: 'Read and create calendar events.',
    icon: 'calendar',
  },
  {
    id: 'microsoft-365',
    name: 'Microsoft 365',
    description: 'Outlook mail, Teams messages, and OneDrive files.',
    icon: 'users',
  },
  {
    id: 'slack',
    name: 'Slack',
    description: 'Post messages and read channel history.',
    icon: 'message-circle',
  },
];
</script>

<div class="ig-page">
  <p class="ig-desc">
    OAuth integrations ship in Week 11-12. Connect once to allow agents to read and write
    on your behalf with per-scope consent.
  </p>

  <div class="ig-list">
    {#each INTEGRATIONS as integration (integration.id)}
      <div class="ig-card">
        <div class="ig-card-icon" aria-hidden="true">
          {#if integration.icon === 'mail'}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
          {:else if integration.icon === 'calendar'}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
          {:else if integration.icon === 'users'}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          {:else if integration.icon === 'message-circle'}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
          {/if}
        </div>

        <div class="ig-card-body">
          <span class="ig-card-name">{integration.name}</span>
          <span class="ig-card-desc">{integration.description}</span>
        </div>

        <div class="ig-card-right">
          <span class="ig-status-chip">Not connected</span>
          <button
            class="ig-pill-btn"
            disabled
            title="Coming in Week 11-12"
            aria-label="Connect {integration.name} — coming in Week 11-12"
          >
            Connect
          </button>
        </div>
      </div>
    {/each}
  </div>

  <p class="ig-note">
    OAuth flow and credential storage land in Week 11-12. All connections will use
    per-scope consent with revocation support.
  </p>
</div>

<style>
  .ig-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .ig-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Integration list ────────────────────────────────────────────────────── */

  .ig-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .ig-card {
    display: flex;
    align-items: center;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .ig-card:hover {
    border-color: var(--border-strong);
  }

  /* ── Icon ────────────────────────────────────────────────────────────────── */

  .ig-card-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border-radius: var(--radius-sm);
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    color: var(--fg-muted);
    flex-shrink: 0;
  }

  /* ── Body ────────────────────────────────────────────────────────────────── */

  .ig-card-body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .ig-card-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .ig-card-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
  }

  /* ── Right: status + button ──────────────────────────────────────────────── */

  .ig-card-right {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-shrink: 0;
  }

  .ig-status-chip {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    padding: 0 var(--space-2);
    height: 18px;
    border-radius: 9999px;
    display: inline-flex;
    align-items: center;
    white-space: nowrap;
  }

  .ig-pill-btn {
    display: inline-flex;
    align-items: center;
    padding: var(--space-1) var(--space-3);
    border-radius: 9999px;
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: not-allowed;
    opacity: 0.4;
    white-space: nowrap;
  }

  /* ── Note ────────────────────────────────────────────────────────────────── */

  .ig-note {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0;
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }
</style>
