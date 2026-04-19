<script lang="ts">
/**
 * Settings › MIOSA — configuration-only form.
 * No live backend endpoints exist for MIOSA config in this phase (Track #119).
 * Set MIOSA_API_URL and MIOSA_API_KEY env vars and restart the app.
 */

let apiUrl = $state('');
let apiKey = $state('');
</script>

<div class="ms-page">
  <p class="ms-desc">
    Connect Canopy to your MIOSA instance. Set the environment variables below and restart the app.
    Live configuration management is coming in a future release.
  </p>

  <div class="ms-form">
    <div class="ms-field">
      <label class="ms-field-label" for="ms-url">API URL</label>
      <input
        id="ms-url"
        type="url"
        class="ms-input"
        placeholder="https://api.miosa.io"
        bind:value={apiUrl}
        autocomplete="off"
        readonly
        aria-readonly="true"
      />
    </div>

    <div class="ms-field">
      <label class="ms-field-label" for="ms-key">API Key</label>
      <input
        id="ms-key"
        type="password"
        class="ms-input"
        placeholder="Set via MIOSA_API_KEY env var"
        bind:value={apiKey}
        autocomplete="off"
        readonly
        aria-readonly="true"
      />
    </div>
  </div>

  <div class="ms-env-block">
    <p class="ms-env-title">Environment variables (set before starting the app)</p>
    <pre class="ms-env-pre"><code>MIOSA_API_URL=https://api.miosa.io
MIOSA_API_KEY=your-api-key</code></pre>
  </div>
</div>

<style>
  .ms-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .ms-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Form ────────────────────────────────────────────────────────────────── */

  .ms-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-5);
  }

  .ms-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .ms-field-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .ms-input {
    width: 100%;
    max-width: 480px;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .ms-input:focus {
    border-color: var(--cnp-accent);
  }

  /* ── Env block ───────────────────────────────────────────────────────────── */

  .ms-env-block {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .ms-env-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
  }

  .ms-env-pre {
    margin: 0;
    padding: var(--space-3) var(--space-4);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    white-space: pre;
    overflow-x: auto;
    line-height: 1.7;
  }
</style>
