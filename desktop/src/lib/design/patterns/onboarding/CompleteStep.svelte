<script lang="ts">
/**
 * CompleteStep — step 5 of OnboardingWizard.
 * "You're all set!" summary + "Open Build" CTA.
 * CSS prefix: obw-
 */
import { goto } from '$app/navigation';
import { profile } from '$lib/stores/profile.svelte.js';

interface Props {
  onComplete: () => void;
  onBack: () => void;
}

let { onComplete, onBack }: Props = $props();

function openBuild(): void {
  onComplete();
  goto('/build');
}
</script>

<div class="obw-complete">
  <div class="obw-complete__badge" aria-hidden="true">
    <svg width="52" height="52" viewBox="0 0 52 52" fill="none">
      <circle cx="26" cy="26" r="26" fill="var(--cnp-accent)" opacity="0.12"/>
      <path d="M16 26 L23 33 L36 19" stroke="var(--cnp-accent)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
    </svg>
  </div>

  <h1 class="obw-complete__heading">
    {profile.displayName ? `You're all set, ${profile.displayName}.` : "You're all set."}
  </h1>

  <p class="obw-complete__sub">
    Canopy is configured and ready. Your agents are standing by.
  </p>

  <div class="obw-complete__summary">
    <div class="obw-complete__summary-item">
      <span aria-hidden="true">✓</span> Workspace configured
    </div>
    <div class="obw-complete__summary-item">
      <span aria-hidden="true">✓</span> Runtimes detected
    </div>
    <div class="obw-complete__summary-item">
      <span aria-hidden="true">✓</span> Agents hired
    </div>
    <div class="obw-complete__summary-item">
      <span aria-hidden="true">✓</span> Theme selected
    </div>
  </div>

  <button class="obw-btn-primary obw-complete__cta" onclick={openBuild}>
    Open Build →
  </button>

  <div class="obw-nav">
    <button class="obw-btn-ghost" onclick={onBack}>← Back</button>
  </div>
</div>

<style>
  .obw-complete {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-5, 20px);
    text-align: center;
    padding: var(--space-2, 8px) 0;
  }

  .obw-complete__heading {
    margin: 0;
    font-family: var(--font-serif, serif);
    font-size: clamp(1.5rem, 3.5vw, 2rem);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.2;
    letter-spacing: -0.02em;
  }

  .obw-complete__sub {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .obw-complete__summary {
    display: flex;
    flex-direction: column;
    gap: var(--space-2, 8px);
    text-align: left;
    width: 100%;
    max-width: 280px;
  }

  .obw-complete__summary-item {
    display: flex;
    align-items: center;
    gap: var(--space-2, 8px);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    color: var(--fg-muted);
  }

  .obw-complete__summary-item span {
    color: var(--success, #78d97c);
    font-weight: 700;
  }

  .obw-complete__cta {
    width: 100%;
    max-width: 280px;
    justify-content: center;
  }

  .obw-btn-primary {
    display: flex;
    padding: 12px 24px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent);
    color: var(--user-accent-fg, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-base, 1rem);
    font-weight: 600;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .obw-btn-primary:hover { opacity: 0.88; }
  .obw-btn-primary:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 3px; }

  .obw-nav {
    width: 100%;
    display: flex;
    align-items: center;
    padding-top: var(--space-4, 16px);
    border-top: 1px solid var(--border);
  }

  .obw-btn-ghost {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
    transition: color 120ms ease;
  }

  .obw-btn-ghost:hover { color: var(--fg); }
  .obw-btn-ghost:focus-visible { outline: 2px solid var(--cnp-accent); outline-offset: 2px; }
</style>
