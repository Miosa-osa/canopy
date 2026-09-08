<script lang="ts">
/**
 * Settings › Profile — saves display name + email locally.
 * Full auth-backed profiles come later; this persists to localStorage now.
 */
import { Check } from 'lucide-svelte';
import { profile } from '$lib/stores/profile.svelte.js';

let name = $state(profile.displayName);
let email = $state(profile.email);
let saved = $state(false);

function handleSave(): void {
  profile.setDisplayName(name.trim());
  profile.setEmail(email.trim());
  saved = true;
  setTimeout(() => {
    saved = false;
  }, 2000);
}
</script>

<div class="pf-page">
  <div class="pf-form">
    <!-- Avatar placeholder -->
    <div class="pf-avatar-row">
      <div class="pf-avatar" aria-hidden="true">
        {#if name.trim()}
          <span class="pf-avatar__initial">{name.trim()[0].toUpperCase()}</span>
        {:else}
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
            <circle cx="12" cy="7" r="4"/>
          </svg>
        {/if}
      </div>
      <div class="pf-avatar-meta">
        <span class="pf-field-label">Avatar</span>
        <span class="pf-coming">Upload available in a future release</span>
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
        bind:value={name}
        onkeydown={(e) => { if (e.key === 'Enter') handleSave(); }}
      />
    </div>

    <!-- Email -->
    <div class="pf-field">
      <label class="pf-field-label" for="pf-email">Email</label>
      <input
        id="pf-email"
        type="email"
        class="pf-input"
        placeholder="you@example.com"
        bind:value={email}
        onkeydown={(e) => { if (e.key === 'Enter') handleSave(); }}
      />
    </div>

    <div class="pf-actions">
      <button class="pf-save" onclick={handleSave}>
        {#if saved}
          <Check size={14} aria-hidden="true" /> Saved
        {:else}
          Save profile
        {/if}
      </button>
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

  .pf-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
  }

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
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 15%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--fg-subtle);
    flex-shrink: 0;
  }

  .pf-avatar__initial {
    font-family: var(--font-sans);
    font-size: 18px;
    font-weight: 700;
    color: var(--cnp-accent, #6366f1);
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
    background: var(--bg-inset, var(--bg));
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    outline: none;
    transition: border-color 150ms;
  }

  .pf-input:focus {
    border-color: var(--cnp-accent, #6366f1);
  }

  .pf-actions {
    padding-top: var(--space-2);
  }

  .pf-save {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    border-radius: var(--radius-sm);
    border: 1px solid var(--cnp-accent, #6366f1);
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 14%, transparent);
    color: var(--cnp-accent, #6366f1);
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
    transition: background 120ms;
  }

  .pf-save:hover {
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 22%, transparent);
  }
</style>
