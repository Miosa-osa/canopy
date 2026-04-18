<script lang="ts">
/**
 * /onboarding — first-run wizard route.
 *
 * Full-page, no sidebar chrome. Renders OnboardingWizard.
 * On completion, navigates to home (/). State (onboardingComplete) is
 * persisted to Tauri store inside OnboardingWizard so / can check it.
 *
 * Wiring TODO for +layout.svelte owner:
 *   The layout should NOT render the sidebar/shell chrome for this route.
 *   Either: (a) check `page.url.pathname === '/onboarding'` and skip sidebar,
 *   or (b) use a separate layout group (routes/(app)/+layout.svelte).
 */
import { goto } from '$app/navigation';
import OnboardingWizard from '$lib/design/patterns/OnboardingWizard.svelte';

function handleComplete(): void {
  goto('/');
}
</script>

<svelte:head>
  <title>Welcome — Canopy</title>
</svelte:head>

<OnboardingWizard onComplete={handleComplete} />
