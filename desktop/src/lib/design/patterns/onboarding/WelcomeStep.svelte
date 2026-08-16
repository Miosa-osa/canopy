<script lang="ts">
/**
 * WelcomeStep — step 0 of OnboardingWizard.
 * "Welcome to Canopy" greeting + brief description. Name input pre-fills profile.
 * CSS prefix: obw- (shared onboarding wizard prefix)
 */
import { profile } from '$lib/stores/profile.svelte.js';

interface Props {
  onNext: () => void;
}

let { onNext }: Props = $props();

let nameInput = $state(profile.displayName);

function handleNext(): void {
  if (nameInput.trim()) {
    profile.setDisplayName(nameInput.trim());
  }
  onNext();
}
</script>

<div class="obw-welcome">
  <div class="obw-welcome__icon" aria-hidden="true">
    <svg width="48" height="48" viewBox="0 0 48 48" fill="none">
      <rect width="48" height="48" rx="12" fill="var(--cnp-accent)" opacity="0.12"/>
      <path d="M14 24 L24 14 L34 24 L24 34 Z" stroke="var(--cnp-accent)" stroke-width="2" fill="none" stroke-linejoin="round"/>
      <circle cx="24" cy="24" r="3" fill="var(--cnp-accent)"/>
    </svg>
  </div>

  <h1 class="obw-welcome__heading">Welcome to Canopy</h1>

  <p class="obw-welcome__desc">
    Your AI operator platform. Connect runtimes, hire agents, and run
    intelligent workflows — all from one cockpit.
  </p>

  <label class="obw-welcome__label" for="obw-name">
    What should we call you?
  </label>
  <input
    id="obw-name"
    class="obw-welcome__input"
    type="text"
    placeholder="Your name"
    bind:value={nameInput}
    onkeydown={(e) => e.key === 'Enter' && handleNext()}
    autocomplete="given-name"
  />

  <button
    class="obw-btn-primary"
    onclick={handleNext}
    aria-label="Continue to workspace setup"
  >
    Get started →
  </button>
</div>

<style>
  .obw-welcome {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-5, 20px);
    text-align: center;
    padding: var(--space-4, 16px) 0;
  }

  .obw-welcome__heading {
    margin: 0;
    font-family: var(--font-serif, serif);
    font-size: clamp(1.75rem, 4vw, 2.25rem);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.15;
    letter-spacing: -0.02em;
  }

  .obw-welcome__desc {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-base, 1rem);
    color: var(--fg-muted);
    line-height: 1.6;
    max-width: 380px;
  }

  .obw-welcome__label {
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    color: var(--fg-muted);
    align-self: stretch;
    text-align: left;
    max-width: 360px;
    margin: 0 auto;
    width: 100%;
  }

  .obw-welcome__input {
    width: 100%;
    max-width: 360px;
    padding: 10px 14px;
    border-radius: 8px;
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    color: var(--fg);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-base, 1rem);
    outline: none;
    transition: border-color 120ms ease;
  }

  .obw-welcome__input:focus {
    border-color: var(--cnp-accent);
  }

  .obw-btn-primary {
    padding: 10px 24px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent);
    color: var(--user-accent-fg, #fff);
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-sm, 0.875rem);
    font-weight: 600;
    cursor: pointer;
    transition: opacity 120ms ease;
  }

  .obw-btn-primary:hover { opacity: 0.88; }
  .obw-btn-primary:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 3px;
  }
</style>
