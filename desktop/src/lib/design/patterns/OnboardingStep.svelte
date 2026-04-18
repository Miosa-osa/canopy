<script lang="ts">
/**
 * OnboardingStep — single-step frame for the onboarding wizard.
 * Provides consistent heading, body slot, and nav footer (Back / Skip / Next).
 * CSS prefix: ows- (OnboardingStep)
 * LOC target: ≤ 100.
 */
import type { Snippet } from 'svelte';

interface Props {
  /** Step heading rendered in the serif editorial style. */
  heading: string;
  /** Current step index (0-based) for the progress indicator. */
  stepIndex: number;
  /** Total step count. */
  totalSteps: number;
  /** Label for the primary forward action button. Default "Next". */
  nextLabel?: string;
  /** Whether the primary action is in a loading/processing state. */
  isProcessing?: boolean;
  /** Whether the Back button is visible. False on step 0. */
  showBack?: boolean;
  /** Whether to show the "Skip for now" ghost button. */
  showSkip?: boolean;
  onNext: () => void;
  onBack?: () => void;
  onSkip?: () => void;
  children: Snippet;
}

let {
  heading,
  stepIndex,
  totalSteps,
  nextLabel = 'Next',
  isProcessing = false,
  showBack = false,
  showSkip = true,
  onNext,
  onBack,
  onSkip,
  children,
}: Props = $props();

const progressPercent = $derived(((stepIndex + 1) / totalSteps) * 100);
</script>

{#key stepIndex}
<section class="ows-step ows-step--enter" aria-label="Step {stepIndex + 1} of {totalSteps}: {heading}">
  <!-- Progress bar -->
  <div class="ows-progress" role="progressbar" aria-valuenow={stepIndex + 1} aria-valuemin={1} aria-valuemax={totalSteps}>
    <div class="ows-progress__bar" style="width: {progressPercent}%;"></div>
  </div>

  <!-- Step indicator -->
  <p class="ows-step-label">Step {stepIndex + 1} of {totalSteps}</p>

  <!-- Heading — serif editorial per §0 design principles -->
  <h1 class="ows-heading">{heading}</h1>

  <!-- Body content slot -->
  <div class="ows-body">
    {@render children()}
  </div>

  <!-- Footer nav -->
  <div class="ows-footer">
    <div class="ows-footer__left">
      {#if showBack}
        <button class="btn-compact btn-compact-ghost" onclick={onBack} disabled={isProcessing}>
          ← Back
        </button>
      {/if}
    </div>

    <div class="ows-footer__right">
      {#if showSkip}
        <button class="btn-compact btn-compact-ghost ows-skip" onclick={onSkip} disabled={isProcessing}>
          Skip for now
        </button>
      {/if}

      <button
        class="btn-pill btn-pill-primary"
        onclick={onNext}
        disabled={isProcessing}
        aria-busy={isProcessing}
      >
        {#if isProcessing}
          <span class="btn-pill-spinner" aria-hidden="true"></span>
          Working…
        {:else}
          {nextLabel}
        {/if}
      </button>
    </div>
  </div>
</section>
{/key}

<style>
  .ows-step {
    display: flex;
    flex-direction: column;
    gap: var(--space-6);
    width: 100%;
    max-width: 640px;
    margin: 0 auto;
  }

  .ows-progress {
    height: 2px;
    background: var(--border);
    border-radius: 1px;
    overflow: hidden;
  }

  .ows-progress__bar {
    height: 100%;
    background: var(--accent);
    border-radius: 1px;
    transition: width var(--dur-normal) var(--ease-out);
  }

  .ows-step-label {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .ows-heading {
    margin: 0;
    font-family: var(--font-serif);
    font-size: clamp(1.75rem, 4vw, 2.5rem);
    font-weight: 600;
    color: var(--fg);
    line-height: 1.15;
    letter-spacing: -0.02em;
  }

  .ows-body {
    flex: 1;
  }

  .ows-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: var(--space-4);
    border-top: 1px solid var(--border);
  }

  .ows-footer__left,
  .ows-footer__right {
    display: flex;
    align-items: center;
    gap: var(--space-3);
  }

  .ows-skip {
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  /* Step enter animation — fires on each {#key stepIndex} remount */
  .ows-step--enter {
    animation: fade-in-up var(--dur-normal, 240ms) var(--ease-out, cubic-bezier(0.16, 1, 0.3, 1)) both;
  }

  @keyframes fade-in-up {
    from {
      opacity: 0;
      transform: translateY(8px);
    }
    to {
      opacity: 1;
      transform: translateY(0);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .ows-step--enter {
      animation: none;
    }
  }
</style>
