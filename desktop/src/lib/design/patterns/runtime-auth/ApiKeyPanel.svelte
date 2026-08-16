<script lang="ts">
/**
 * ApiKeyPanel — per-runtime API key management panel.
 *
 * Shows stored/not-stored state, masked input, Save + Test actions,
 * and a link to the provider's key-creation page.
 *
 * No blue. Monochrome + var(--cnp-accent) only on primary action.
 * CSS prefix: akp-
 */

interface TestResult {
  ok: boolean;
  model?: string;
  latency_ms?: number;
  error?: string;
}

interface Props {
  runtimeId: string;
  /** Whether a key is currently stored in vault */
  stored: boolean | null;
  /** Provider key-creation page URL */
  signupUrl?: string | null;
  /** Input placeholder, e.g. "sk-ant-..." */
  placeholder?: string;
  isSaving?: boolean;
  isTesting?: boolean;
  saveError?: string | null;
  testResult?: TestResult | null;
  onSave: (key: string) => void;
  onTest: (key: string) => void;
  onRevoke: () => void;
}

let {
  runtimeId,
  stored,
  signupUrl = null,
  placeholder = 'Paste your API key…',
  isSaving = false,
  isTesting = false,
  saveError = null,
  testResult = null,
  onSave,
  onTest,
  onRevoke,
}: Props = $props();

let key = $state('');
let revealed = $state(false);

const canSubmit = $derived(key.trim().length > 0);
</script>

<div class="akp-panel">
  <div class="akp-header">
    <span class="akp-label">API key</span>
    {#if stored === true}
      <span class="akp-badge akp-badge--ok">Stored</span>
    {:else if stored === false}
      <span class="akp-badge akp-badge--muted">Not stored</span>
    {:else}
      <span class="akp-badge akp-badge--muted">Unknown</span>
    {/if}
  </div>

  {#if stored === true}
    <p class="akp-body">
      An API key is stored in Canopy's vault for this runtime. It will be injected
      as an environment variable when spawning sessions.
    </p>
    <div class="akp-stored-actions">
      <button
        class="akp-btn"
        type="button"
        disabled={isTesting}
        onclick={() => onTest('')}
        aria-label="Test stored API key"
      >{isTesting ? 'Testing…' : 'Test'}</button>
      <button
        class="akp-btn akp-btn--danger"
        type="button"
        onclick={onRevoke}
        aria-label="Revoke stored API key"
      >Revoke</button>
    </div>
  {/if}

  <div class="akp-field">
    <label class="akp-field-label" for="akp-key-{runtimeId}">
      {stored ? 'Replace key' : 'Enter key'}
    </label>
    <div class="akp-input-row">
      <input
        id="akp-key-{runtimeId}"
        type={revealed ? 'text' : 'password'}
        class="akp-input"
        {placeholder}
        autocomplete="off"
        spellcheck={false}
        bind:value={key}
        aria-label="API key for {runtimeId}"
      />
      <button
        class="akp-reveal-btn"
        type="button"
        onclick={() => { revealed = !revealed; }}
        aria-label={revealed ? 'Hide key' : 'Reveal key'}
        aria-pressed={revealed}
      >
        {#if revealed}
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/>
            <path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/>
            <line x1="1" y1="1" x2="23" y2="23"/>
          </svg>
        {:else}
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
            <circle cx="12" cy="12" r="3"/>
          </svg>
        {/if}
      </button>
    </div>
  </div>

  <div class="akp-actions">
    <button
      class="akp-btn akp-btn--primary"
      type="button"
      disabled={!canSubmit || isSaving}
      onclick={() => onSave(key.trim())}
    >{isSaving ? 'Saving…' : 'Save'}</button>
    <button
      class="akp-btn"
      type="button"
      disabled={!canSubmit || isTesting}
      onclick={() => onTest(key.trim())}
    >{isTesting ? 'Testing…' : 'Test'}</button>
  </div>

  {#if saveError}
    <p class="akp-msg akp-msg--err">Save failed: {saveError}</p>
  {/if}

  {#if testResult}
    {#if testResult.ok}
      <p class="akp-msg akp-msg--ok">
        Connected{testResult.model ? ` · ${testResult.model}` : ''}{testResult.latency_ms != null ? ` · ${testResult.latency_ms}ms` : ''}
      </p>
    {:else}
      <p class="akp-msg akp-msg--err">
        Failed{testResult.error ? `: ${testResult.error}` : ''}
      </p>
    {/if}
  {/if}

  {#if signupUrl}
    <a
      href={signupUrl}
      target="_blank"
      rel="noopener noreferrer"
      class="akp-signup-link"
      aria-label="Create an API key at the provider's console"
    >Get an API key ↗</a>
  {/if}
</div>

<style>
  .akp-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .akp-header {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .akp-label {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    flex: 1;
  }

  .akp-badge {
    display: inline-flex;
    align-items: center;
    height: 18px;
    padding: 0 var(--space-2);
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .akp-badge--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 14%, transparent 86%);
    color: oklch(50% 0.15 145);
  }

  .akp-badge--muted {
    background: color-mix(in oklch, var(--fg) 7%, transparent 93%);
    color: var(--fg-subtle);
  }

  .akp-body {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .akp-stored-actions {
    display: flex;
    gap: var(--space-2);
  }

  .akp-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .akp-field-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .akp-input-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .akp-input {
    flex: 1;
    max-width: 360px;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .akp-input:focus {
    border-color: var(--cnp-accent);
  }

  .akp-reveal-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    flex-shrink: 0;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .akp-reveal-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .akp-reveal-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .akp-actions {
    display: flex;
    gap: var(--space-2);
  }

  .akp-btn {
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
    cursor: pointer;
    white-space: nowrap;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .akp-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .akp-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .akp-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .akp-btn--primary {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
    color: oklch(100% 0 0);
  }

  .akp-btn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    border-color: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }

  .akp-btn--danger:hover {
    background: color-mix(in oklch, oklch(65% 0.2 25) 10%, transparent 90%);
    color: oklch(50% 0.2 25);
    border-color: color-mix(in oklch, oklch(65% 0.2 25) 30%, transparent 70%);
  }

  .akp-msg {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
  }

  .akp-msg--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 12%, transparent 88%);
    color: oklch(50% 0.15 145);
  }

  .akp-msg--err {
    background: color-mix(in oklch, oklch(60% 0.2 25) 12%, transparent 88%);
    color: oklch(50% 0.2 25);
  }

  .akp-signup-link {
    align-self: flex-start;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    text-decoration: none;
    transition: color var(--dur-instant) var(--ease-out);
  }

  .akp-signup-link:hover {
    color: var(--fg);
  }

  .akp-signup-link:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
    border-radius: 2px;
  }
</style>
