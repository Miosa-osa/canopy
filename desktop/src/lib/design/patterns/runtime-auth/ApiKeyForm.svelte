<script lang="ts">
/**
 * ApiKeyForm — paste API key, reveal/hide toggle, save + test.
 * CSS prefix: akf-
 */
interface Props {
  runtimeId: string;
  isSaving: boolean;
  isTesting: boolean;
  saveError: string | null;
  testResult: { ok: boolean; model?: string; latency_ms?: number; error?: string } | null;
  onSave: (key: string) => void;
  onTest: (key: string) => void;
}

let {
  runtimeId,
  isSaving,
  isTesting,
  saveError,
  testResult,
  onSave,
  onTest,
}: Props = $props();

let key = $state('');
let revealed = $state(false);

const canSubmit = $derived(key.trim().length > 0);
</script>

<div class="akf-form">
  <div class="akf-field">
    <label class="akf-label" for="akf-key-{runtimeId}">API key</label>
    <div class="akf-input-row">
      <input
        id="akf-key-{runtimeId}"
        type={revealed ? 'text' : 'password'}
        class="akf-input"
        placeholder="sk-…"
        autocomplete="off"
        spellcheck={false}
        bind:value={key}
        aria-label="API key for {runtimeId}"
      />
      <button
        class="akf-reveal-btn"
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

  <div class="akf-actions">
    <button
      class="akf-btn akf-btn--primary"
      type="button"
      disabled={!canSubmit || isSaving}
      onclick={() => onSave(key.trim())}
    >
      {isSaving ? 'Saving…' : 'Save'}
    </button>
    <button
      class="akf-btn"
      type="button"
      disabled={!canSubmit || isTesting}
      onclick={() => onTest(key.trim())}
    >
      {isTesting ? 'Testing…' : 'Test'}
    </button>
  </div>

  {#if saveError}
    <p class="akf-msg akf-msg--err">Save failed: {saveError}</p>
  {/if}

  {#if testResult}
    {#if testResult.ok}
      <p class="akf-msg akf-msg--ok">
        Connected{testResult.model ? ` · ${testResult.model}` : ''}{testResult.latency_ms != null ? ` · ${testResult.latency_ms}ms` : ''}
      </p>
    {:else}
      <p class="akf-msg akf-msg--err">
        Failed{testResult.error ? `: ${testResult.error}` : ''}
      </p>
    {/if}
  {/if}
</div>

<style>
  .akf-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .akf-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .akf-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .akf-input-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .akf-input {
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

  .akf-input:focus {
    border-color: var(--cnp-accent);
  }

  .akf-reveal-btn {
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

  .akf-reveal-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .akf-reveal-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .akf-actions {
    display: flex;
    gap: var(--space-2);
  }

  .akf-btn {
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

  .akf-btn:hover:not(:disabled) {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .akf-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }

  .akf-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .akf-btn--primary {
    background: var(--cnp-accent);
    border-color: var(--cnp-accent);
    color: oklch(100% 0 0);
  }

  .akf-btn--primary:hover:not(:disabled) {
    background: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    border-color: color-mix(in oklch, var(--cnp-accent) 85%, oklch(0% 0 0) 15%);
    color: oklch(100% 0 0);
  }

  .akf-msg {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
  }

  .akf-msg--ok {
    background: color-mix(in oklch, oklch(70% 0.15 145) 12%, transparent 88%);
    color: oklch(50% 0.15 145);
  }

  .akf-msg--err {
    background: color-mix(in oklch, oklch(60% 0.2 25) 12%, transparent 88%);
    color: oklch(50% 0.2 25);
  }
</style>
