<script lang="ts">
  /**
   * Settings › Drive — Drive defaults and Vault agent settings.
   *
   * Phase A: client-side preferences only (default scope, archive retention,
   * sharing defaults). These persist via localStorage; Phase B will round-trip
   * through a server-side workspace settings table.
   *
   * CSS prefix: dst-
   */
  import { onMount } from "svelte";
  import { Save } from "lucide-svelte";
  import { Button, Input } from "$lib/design/foundation";
  import type { DriveScope } from "$lib/domain/drive/types.js";

  const STORAGE_KEY = "canopy.drive.settings.v1";

  interface DriveSettings {
    defaultScope: DriveScope;
    archiveRetentionDays: number;
    teamSharingDefault: "private" | "team";
    autoSeedSuggestions: boolean;
  }

  const DEFAULT_SETTINGS: DriveSettings = {
    defaultScope: "personal",
    archiveRetentionDays: 90,
    teamSharingDefault: "private",
    autoSeedSuggestions: true,
  };

  let settings = $state<DriveSettings>({ ...DEFAULT_SETTINGS });
  let savedAt = $state<string | null>(null);

  onMount(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        settings = { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
      }
    } catch {
      // ignore
    }
  });

  function save(e: Event) {
    e.preventDefault();
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
      savedAt = new Date().toLocaleTimeString();
    } catch (err) {
      savedAt = `error: ${(err as Error).message}`;
    }
  }

  function reset() {
    settings = { ...DEFAULT_SETTINGS };
    savedAt = null;
  }
</script>

<div class="dst-page">
  <header class="dst-header">
    <h1 class="dst-title">Drive</h1>
    <p class="dst-subtitle">
      Defaults for new entries, archive retention, and Vault curator behavior.
    </p>
  </header>

  <form class="dst-form" onsubmit={save}>
    <section class="dst-section">
      <h2 class="dst-section-title">Defaults</h2>

      <label class="dst-field">
        <span class="dst-label">Default scope</span>
        <select bind:value={settings.defaultScope} class="dst-select">
          <option value="personal">Personal</option>
          <option value="team">Team</option>
        </select>
        <span class="dst-hint">
          Pre-selected scope when you click <strong>+ New</strong>.
        </span>
      </label>

      <label class="dst-field">
        <span class="dst-label">Team sharing default</span>
        <select bind:value={settings.teamSharingDefault} class="dst-select">
          <option value="private">Private (creator only)</option>
          <option value="team">Team (workspace-wide)</option>
        </select>
        <span class="dst-hint">
          Default visibility when creating a Team-scope entry.
        </span>
      </label>
    </section>

    <section class="dst-section">
      <h2 class="dst-section-title">Archive retention</h2>

      <label class="dst-field">
        <span class="dst-label">Days before archived entries are purged</span>
        <Input
          type="number"
          min="0"
          max="3650"
          bind:value={settings.archiveRetentionDays}
        />
        <span class="dst-hint">
          0 = keep forever. Default 90.
        </span>
      </label>
    </section>

    <section class="dst-section">
      <h2 class="dst-section-title">Vault (curator agent)</h2>

      <label class="dst-field dst-field-row">
        <input
          type="checkbox"
          bind:checked={settings.autoSeedSuggestions}
          class="dst-checkbox"
        />
        <span>
          <strong>Auto-seed suggestions</strong>
          <span class="dst-hint">
            Vault posts up to 3 reorganization suggestions per day to
            <code>#drive-feed</code>.
          </span>
        </span>
      </label>
    </section>

    <footer class="dst-footer">
      <div class="dst-actions">
        <Button type="button" onclick={reset}>Reset to defaults</Button>
        <Button type="submit">
          <Save size={14} aria-hidden="true" />
          Save
        </Button>
        {#if savedAt}
          <span class="dst-saved" aria-live="polite">Saved at {savedAt}</span>
        {/if}
      </div>
      <p class="dst-local-notice">
        Settings saved locally. Server-side persistence coming in a future update.
      </p>
    </footer>
  </form>
</div>

<style>
  .dst-page {
    padding: 1.5rem 2rem 4rem;
    max-width: 720px;
    color: var(--cnp-fg);
  }

  .dst-header {
    margin-bottom: 1.5rem;
  }

  .dst-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.75rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0 0 0.25rem;
  }

  .dst-subtitle {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0;
  }

  .dst-form {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  .dst-section {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
  }

  .dst-section-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 0.85rem;
  }

  .dst-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    margin-bottom: 1rem;
  }

  .dst-field:last-child {
    margin-bottom: 0;
  }

  .dst-field-row {
    flex-direction: row;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .dst-label {
    font-size: 0.85rem;
    font-weight: 500;
  }

  .dst-hint {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
  }

  .dst-select {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    font: inherit;
    padding: 0.4rem 0.5rem;
    max-width: 18rem;
  }

  .dst-checkbox {
    margin-top: 0.2rem;
  }

  .dst-footer {
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .dst-actions {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .dst-saved {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .dst-local-notice {
    font-size: 0.75rem;
    font-style: italic;
    color: var(--cnp-fg-muted);
    margin: 0;
    opacity: 0.8;
  }

  code {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.78rem;
    padding: 0.05rem 0.25rem;
    background: var(--cnp-bg);
    border-radius: 3px;
  }
</style>
