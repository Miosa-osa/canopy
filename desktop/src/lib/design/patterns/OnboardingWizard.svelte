<script lang="ts">
/**
 * OnboardingWizard — 5-step first-run flow (docs/02-frontend-design.md §6.12).
 * Full-page layout, state persisted to Tauri store so it only shows once.
 *
 * Steps:
 *   0. Welcome         — thesis + serif headline
 *   1. Scan runtimes   — calls syncRuntimes(), shows result card
 *   2. Connect creds   — RuntimeConfigForm per detected runtime (skippable per runtime)
 *   3. Pick workspace  — 4 starter templates → navigate to /workspaces/new
 *   4. Hire first agent — 10 curated agent cards → hire action
 *
 * CSS prefix: owz- (OnboardingWizard)
 * LOC: ≤ 200 (complex multi-step wizard — justified exception per spec)
 */
import { goto } from '$app/navigation';
import { syncRuntimes } from '$lib/bootstrap/runtime-sync.js';
import { isTauri } from '$lib/tauri/index.js';
import OnboardingStep from './OnboardingStep.svelte';

interface Props {
  /** Called when the wizard completes or is fully skipped. */
  onComplete: () => void;
}

let { onComplete }: Props = $props();

// ── State ──────────────────────────────────────────────────────────────

let currentStep = $state(0);
const TOTAL_STEPS = 5;

// Step 1 — runtime scan result
interface ScanResult {
  ok: boolean;
  installedCount: number;
  detectedCount: number;
  error?: string;
}
let scanResult = $state<ScanResult | null>(null);
let isScanning = $state(false);

// Step 4 — hired agents
const hiredSlugs = $state(new Set<string>());

// ── Curated data ───────────────────────────────────────────────────────

const WORKSPACE_TEMPLATES = [
  { id: 'sales-engine', label: 'Sales Engine', icon: '💼', description: 'CRM, pipeline, outreach' },
  { id: 'dev-shop', label: 'Dev Shop', icon: '⚙', description: 'Code, review, deploy' },
  {
    id: 'content-factory',
    label: 'Content Factory',
    icon: '✍',
    description: 'Scripts, reels, copy',
  },
  { id: 'blank', label: 'Blank', icon: '◻', description: 'Start from scratch' },
] as const;

const CURATED_AGENTS = [
  { slug: 'sales-strategist', name: 'Sales Strategist', emoji: '💰', category: 'sales' },
  { slug: 'architect', name: 'Architect', emoji: '🏗', category: 'engineering' },
  { slug: 'copy-doctor', name: 'Copy Doctor', emoji: '✍', category: 'creative-content' },
  { slug: 'data-analyst', name: 'Data Analyst', emoji: '📊', category: 'operations' },
  { slug: 'researcher', name: 'Researcher', emoji: '🔍', category: 'academic' },
  { slug: 'product-manager', name: 'Product Manager', emoji: '📋', category: 'product' },
  { slug: 'growth-hacker', name: 'Growth Hacker', emoji: '🚀', category: 'growth' },
  { slug: 'support-bot', name: 'Support Bot', emoji: '🎧', category: 'support' },
  { slug: 'code-reviewer', name: 'Code Reviewer', emoji: '🔎', category: 'engineering' },
  { slug: 'content-strategist', name: 'Content Strategist', emoji: '📅', category: 'marketing' },
] as const;

// ── Navigation ─────────────────────────────────────────────────────────

function advance(): void {
  if (currentStep === 1 && !scanResult) {
    // Trigger scan on entering step 1
    runScan();
  }
  if (currentStep < TOTAL_STEPS - 1) {
    currentStep += 1;
  } else {
    complete();
  }
}

function back(): void {
  if (currentStep > 0) currentStep -= 1;
}

function skip(): void {
  if (currentStep < TOTAL_STEPS - 1) {
    currentStep += 1;
  } else {
    complete();
  }
}

async function complete(): Promise<void> {
  await persistComplete();
  onComplete();
}

async function persistComplete(): Promise<void> {
  if (!isTauri()) return;
  try {
    const { Store } = await import('@tauri-apps/plugin-store');
    const store = await Store.load('ui.json', { defaults: {}, autoSave: true });
    await store.set('onboardingComplete', true);
  } catch {
    // Non-fatal — worst case they see wizard again on next launch.
  }
}

// ── Step 1: Scan ───────────────────────────────────────────────────────

async function runScan(): Promise<void> {
  isScanning = true;
  try {
    const result = await syncRuntimes();
    scanResult = result;
  } finally {
    isScanning = false;
  }
}

// ── Step 3: Workspace ──────────────────────────────────────────────────

function pickTemplate(id: string): void {
  goto(`/workspaces/new?template=${id}`);
}

// ── Step 4: Hire ───────────────────────────────────────────────────────

function toggleHire(slug: string): void {
  if (hiredSlugs.has(slug)) {
    hiredSlugs.delete(slug);
  } else {
    hiredSlugs.add(slug);
  }
}

const nextLabel = $derived(currentStep === TOTAL_STEPS - 1 ? 'Done' : 'Next →');
const showBack = $derived(currentStep > 0);
</script>

<div class="owz-wizard" role="main" aria-label="Onboarding wizard">
  <!-- Step 0: Welcome -->
  {#if currentStep === 0}
    <OnboardingStep
      heading="Your agents are waiting."
      stepIndex={0}
      totalSteps={TOTAL_STEPS}
      nextLabel="Get started →"
      showBack={false}
      onNext={advance}
      onSkip={skip}
    >
      <p class="owz-thesis">
        Canopy is an AI operator platform. Connect your runtimes, hire agents,
        and run AI workflows from a single cockpit.
      </p>
    </OnboardingStep>

  <!-- Step 1: Scan runtimes -->
  {:else if currentStep === 1}
    <OnboardingStep
      heading="Scanning your machine."
      stepIndex={1}
      totalSteps={TOTAL_STEPS}
      nextLabel={nextLabel}
      showBack={showBack}
      isProcessing={isScanning}
      onNext={advance}
      onBack={back}
      onSkip={skip}
    >
      {#if !scanResult && !isScanning}
        <p class="owz-scan-prompt">Detecting installed AI runtimes on your system…</p>
        <button class="btn-pill btn-pill-secondary owz-scan-btn" onclick={runScan}>
          Run scan
        </button>
      {:else if isScanning}
        <div class="owz-scan-running" aria-live="polite">
          <span class="owz-scan-dot canopy-shim" aria-hidden="true"></span>
          <span>Scanning $PATH for runtimes…</span>
        </div>
      {:else if scanResult}
        <div class="owz-scan-result glass-card">
          <p class="owz-scan-found">
            Found <strong>{scanResult.installedCount}</strong> of {scanResult.detectedCount} runtimes installed.
          </p>
          {#if scanResult.error === "not_in_tauri"}
            <p class="owz-scan-note">Running in browser mode — connect credentials manually in Settings.</p>
          {:else if scanResult.error}
            <p class="owz-scan-error">Scan error: {scanResult.error}. You can configure runtimes later.</p>
          {/if}
        </div>
      {/if}
    </OnboardingStep>

  <!-- Step 2: Connect credentials -->
  {:else if currentStep === 2}
    <OnboardingStep
      heading="Connect your credentials."
      stepIndex={2}
      totalSteps={TOTAL_STEPS}
      nextLabel={nextLabel}
      showBack={showBack}
      onNext={advance}
      onBack={back}
      onSkip={skip}
    >
      <p class="owz-creds-note">
        API keys are stored in your macOS Keychain — never on disk or in the cloud.
        Configure each runtime you want to use, or skip and do it later in Settings.
      </p>
      <a href="/settings/runtimes" class="btn-pill btn-pill-secondary owz-settings-link">
        Open Runtime Settings →
      </a>
    </OnboardingStep>

  <!-- Step 3: Pick workspace -->
  {:else if currentStep === 3}
    <OnboardingStep
      heading="Pick a starter workspace."
      stepIndex={3}
      totalSteps={TOTAL_STEPS}
      nextLabel={nextLabel}
      showBack={showBack}
      onNext={advance}
      onBack={back}
      onSkip={skip}
    >
      <div class="owz-templates">
        {#each WORKSPACE_TEMPLATES as tpl (tpl.id)}
          <button
            class="owz-template-card glass-card"
            onclick={() => pickTemplate(tpl.id)}
            aria-label="Use {tpl.label} template"
          >
            <span class="owz-template-icon" aria-hidden="true">{tpl.icon}</span>
            <span class="owz-template-name">{tpl.label}</span>
            <span class="owz-template-desc">{tpl.description}</span>
          </button>
        {/each}
      </div>
    </OnboardingStep>

  <!-- Step 4: Hire first agent -->
  {:else if currentStep === 4}
    <OnboardingStep
      heading="Hire your first agent."
      stepIndex={4}
      totalSteps={TOTAL_STEPS}
      nextLabel="Done"
      showBack={showBack}
      showSkip={false}
      onNext={advance}
      onBack={back}
    >
      <div class="owz-agents">
        {#each CURATED_AGENTS as agent (agent.slug)}
          {@const hired = hiredSlugs.has(agent.slug)}
          <button
            class="owz-agent-pill {hired ? 'owz-agent-pill--hired' : ''}"
            onclick={() => toggleHire(agent.slug)}
            aria-pressed={hired}
            aria-label="{hired ? 'Unhire' : 'Hire'} {agent.name}"
          >
            <span aria-hidden="true">{agent.emoji}</span>
            <span>{agent.name}</span>
            {#if hired}<span class="owz-hired-badge" aria-hidden="true">✓</span>{/if}
          </button>
        {/each}
      </div>
    </OnboardingStep>
  {/if}
</div>

<style>
  .owz-wizard {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    padding: var(--space-8);
    background: var(--bg);
  }

  .owz-thesis {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    color: var(--fg-muted);
    line-height: 1.65;
    margin: 0;
    max-width: 480px;
  }

  /* Step 1 */
  .owz-scan-prompt {
    margin: 0 0 var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .owz-scan-btn {
    align-self: flex-start;
  }

  .owz-scan-running {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .owz-scan-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--cnp-accent);
    display: inline-block;
  }

  .owz-scan-result {
    padding: var(--space-4);
  }

  .owz-scan-found {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-base);
    color: var(--fg);
  }

  .owz-scan-note,
  .owz-scan-error {
    margin: var(--space-2) 0 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
  }

  .owz-scan-error {
    color: var(--signal-error);
  }

  /* Step 2 */
  .owz-creds-note {
    margin: 0 0 var(--space-4);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .owz-settings-link {
    display: inline-flex;
    align-items: center;
    text-decoration: none;
  }

  /* Step 3 */
  .owz-templates {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: var(--space-3);
  }

  .owz-template-card {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-1);
    padding: var(--space-4);
    background: none;
    border: none;
    cursor: pointer;
    text-align: left;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .owz-template-card:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .owz-template-icon {
    font-size: 28px;
    line-height: 1;
    margin-bottom: var(--space-1);
  }

  .owz-template-name {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  .owz-template-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* Step 4 */
  .owz-agents {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-2);
  }

  .owz-agent-pill {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    padding: var(--space-2) var(--space-3);
    border-radius: 999px;
    border: 1px solid var(--border);
    background: var(--bg-elevated);
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    cursor: pointer;
    transition:
      border-color var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out),
      background var(--dur-instant) var(--ease-out);
  }

  .owz-agent-pill:hover {
    border-color: var(--border-strong);
    color: var(--fg);
  }

  .owz-agent-pill:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 2px;
  }

  .owz-agent-pill--hired {
    border-color: var(--cnp-accent);
    color: var(--fg);
    background: oklch(from var(--cnp-accent) l c h / 0.08);
  }

  .owz-hired-badge {
    color: var(--cnp-accent);
    font-size: var(--text-xs);
    font-weight: 700;
  }
</style>
