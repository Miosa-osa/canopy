<script lang="ts">
/**
 * OnboardingWizard — 6-step first-run flow.
 * Full-viewport overlay with centered card (max-width 560px) + background blur.
 * Completion persisted to localStorage: canopy:onboarding.completed
 *
 * Steps: Welcome → Workspace → Runtimes → Agents → Theme → Complete
 *
 * CSS prefix: obw- (onboarding wizard)
 */
import WelcomeStep from './WelcomeStep.svelte';
import WorkspaceStep from './WorkspaceStep.svelte';
import RuntimeStep from './RuntimeStep.svelte';
import AgentStep from './AgentStep.svelte';
import ThemeStep from './ThemeStep.svelte';
import CompleteStep from './CompleteStep.svelte';

interface Props {
  onComplete: () => void;
}

let { onComplete }: Props = $props();

const TOTAL = 6;
let step = $state(0);

function next(): void  { if (step < TOTAL - 1) step += 1; }
function back(): void  { if (step > 0) step -= 1; }
function skip(): void  { if (step < TOTAL - 1) step += 1; }

function finish(): void {
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('canopy:onboarding.completed', '1');
  }
  onComplete();
}

const progressPct = $derived(((step + 1) / TOTAL) * 100);

const STEP_LABELS = ['Welcome', 'Workspace', 'Runtimes', 'Agents', 'Theme', 'Complete'];
</script>

<div class="obw-overlay" role="dialog" aria-modal="true" aria-label="Canopy onboarding wizard">
  <div class="obw-card" aria-label="Step {step + 1} of {TOTAL}: {STEP_LABELS[step]}">

    <!-- Dot indicator -->
    <div class="obw-dots" aria-hidden="true" role="presentation">
      {#each { length: TOTAL } as _, i}
        <span class="obw-dot {i === step ? 'obw-dot--active' : i < step ? 'obw-dot--done' : ''}"></span>
      {/each}
    </div>

    <!-- Progress bar -->
    <div class="obw-progress" role="progressbar" aria-valuenow={step + 1} aria-valuemin={1} aria-valuemax={TOTAL} aria-label="Step {step + 1} of {TOTAL}">
      <div class="obw-progress__fill" style="width: {progressPct}%"></div>
    </div>

    <!-- Step label -->
    <p class="obw-step-label">Step {step + 1} of {TOTAL} — {STEP_LABELS[step]}</p>

    <!-- Step content (lazy via {#if} blocks) -->
    <div class="obw-content">
      {#key step}
        <div class="obw-content__inner">
          {#if step === 0}
            <WelcomeStep onNext={next} />
          {:else if step === 1}
            <WorkspaceStep onNext={next} onBack={back} onSkip={skip} />
          {:else if step === 2}
            <RuntimeStep onNext={next} onBack={back} onSkip={skip} />
          {:else if step === 3}
            <AgentStep onNext={next} onBack={back} onSkip={skip} />
          {:else if step === 4}
            <ThemeStep onNext={next} onBack={back} onSkip={skip} />
          {:else if step === 5}
            <CompleteStep onComplete={finish} onBack={back} />
          {/if}
        </div>
      {/key}
    </div>

  </div>
</div>

<style>
  .obw-overlay {
    position: fixed;
    inset: 0;
    z-index: 9000;
    display: flex;
    align-items: center;
    justify-content: center;
    background: oklch(0 0 0 / 0.55);
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    padding: var(--space-4, 16px);
  }

  .obw-card {
    width: 100%;
    max-width: 560px;
    background: var(--surface, var(--bg));
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: var(--space-8, 32px);
    display: flex;
    flex-direction: column;
    gap: var(--space-4, 16px);
    box-shadow: 0 24px 64px oklch(0 0 0 / 0.35);
    max-height: calc(100vh - 48px);
    overflow-y: auto;
    color: var(--fg);
  }

  .obw-dots {
    display: flex;
    justify-content: center;
    gap: var(--space-2, 8px);
  }

  .obw-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--border);
    transition: background 200ms ease, transform 200ms ease;
    flex-shrink: 0;
  }

  .obw-dot--active {
    background: var(--cnp-accent);
    transform: scale(1.25);
  }

  .obw-dot--done {
    background: oklch(from var(--cnp-accent, #6b8cf7) l c h / 0.4);
  }

  .obw-progress {
    height: 2px;
    background: var(--border);
    border-radius: 1px;
    overflow: hidden;
  }

  .obw-progress__fill {
    height: 100%;
    background: var(--cnp-accent);
    border-radius: 1px;
    transition: width 240ms cubic-bezier(0.16, 1, 0.3, 1);
  }

  .obw-step-label {
    margin: 0;
    font-family: var(--font-sans, sans-serif);
    font-size: var(--text-xs, 0.75rem);
    color: var(--fg-subtle);
    letter-spacing: 0.06em;
    text-transform: uppercase;
    text-align: center;
  }

  .obw-content { width: 100%; }

  .obw-content__inner {
    animation: obw-fadein 200ms cubic-bezier(0.16, 1, 0.3, 1) both;
  }

  @keyframes obw-fadein {
    from { opacity: 0; transform: translateY(6px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  @media (prefers-reduced-motion: reduce) {
    .obw-content__inner { animation: none; }
    .obw-dot { transition: none; }
    .obw-progress__fill { transition: none; }
  }
</style>
