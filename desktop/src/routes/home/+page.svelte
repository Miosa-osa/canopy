<script lang="ts">
import GreetingHeadline from '$lib/design/patterns/home/GreetingHeadline.svelte';
import HomeComposer from '$lib/design/patterns/home/HomeComposer.svelte';
import QuickActionChips from '$lib/design/patterns/home/QuickActionChips.svelte';
import OnboardingWizard from '$lib/design/patterns/onboarding/OnboardingWizard.svelte';

const LS_KEY = 'canopy:onboarding.completed';

let showOnboarding = $state(typeof localStorage !== 'undefined' && !localStorage.getItem(LS_KEY));

let composerEl = $state<{ submitPrompt: (p: string) => void } | null>(null);

function handleChipSelect(prompt: string): void {
  composerEl?.submitPrompt(prompt);
}

function markComplete(): void {
  showOnboarding = false;
}
</script>

{#if showOnboarding}
  <OnboardingWizard onComplete={markComplete} />
{/if}

<div class="hp-root">
  <main class="hp-content" aria-label="Home">
    <GreetingHeadline />
    <HomeComposer bind:this={composerEl} />
    <QuickActionChips onSelect={handleChipSelect} />
  </main>
</div>

<style>
  .hp-root {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow-y: auto;
    background: var(--bg);
    padding: var(--space-8, 32px) var(--space-4, 16px);
  }

  .hp-content {
    width: 100%;
    max-width: 620px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }
</style>
