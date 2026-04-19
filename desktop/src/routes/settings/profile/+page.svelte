<script lang="ts">
/**
 * Settings › Profile — placeholder until multi-user auth lands in Week 17.
 * All inputs are disabled; no backend calls.
 */
</script>

<div class="pf-page">
  <p class="pf-desc">
    Profile settings ship when multi-user authentication lands in Week 17.
  </p>

  <div class="pf-form">
    <!-- Avatar placeholder -->
    <div class="pf-avatar-row">
      <div class="pf-avatar" aria-hidden="true">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
          <circle cx="12" cy="7" r="4"/>
        </svg>
      </div>
      <div class="pf-avatar-meta">
        <span class="pf-field-label">Avatar</span>
        <span class="pf-coming">Upload available in Week 17</span>
      </div>
    </div>

    <!-- Display name -->
    <div class="pf-field">
      <label class="pf-field-label" for="pf-display-name">Display name</label>
      <input
        id="pf-display-name"
        type="text"
        class="pf-input"
        placeholder="Your name"
        disabled
        aria-disabled="true"
      />
    </div>

    <!-- Email (placeholder) -->
    <div class="pf-field">
      <label class="pf-field-label" for="pf-email">Email</label>
      <input
        id="pf-email"
        type="email"
        class="pf-input"
        placeholder="you@example.com"
        disabled
        aria-disabled="true"
      />
    </div>
  </div>
</div>

<style>
  .pf-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    max-width: 720px;
  }

  .pf-desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    padding: var(--space-3) var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    background: color-mix(in oklch, var(--fg) 3%, transparent 97%);
  }

  /* ── Form ────────────────────────────────────────────────────────────────── */

  .pf-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    opacity: 0.5;
  }

  /* ── Avatar ──────────────────────────────────────────────────────────────── */

  .pf-avatar-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .pf-avatar {
    width: 48px;
    height: 48px;
    border-radius: 50%;
    border: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 5%, transparent 95%);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .pf-avatar-meta {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .pf-coming {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* ── Field ───────────────────────────────────────────────────────────────── */

  .pf-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .pf-field-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
  }

  .pf-input {
    width: 100%;
    max-width: 400px;
    padding: var(--space-2) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg-inset);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    cursor: not-allowed;
  }

  .pf-input:disabled {
    opacity: 0.6;
  }
</style>
