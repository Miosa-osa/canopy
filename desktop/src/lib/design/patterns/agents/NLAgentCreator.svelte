<script lang="ts">
  /**
   * NLAgentCreator — natural language to agent config generator.
   * Client-side parsing extracts name, slug, role, and skills from a description.
   * CSS prefix: nlac-
   */
  import { goto } from '$app/navigation';
  import { X, Sparkles, CheckCircle } from 'lucide-svelte';
  import { createAgent } from '$lib/api/queries/agents.js';
  import type { CreateAgentBody } from '$lib/api/queries/agents.js';
  import type { AgentCategory } from '$lib/domain/agents/types.js';

  interface Props {
    open: boolean;
    onClose: () => void;
  }

  let { open, onClose }: Props = $props();

  // ── Form state ─────────────────────────────────────────────────────────────
  let description = $state('');
  let preview = $state<CreateAgentBody | null>(null);
  let isPending = $state(false);
  let submitError = $state<string | null>(null);

  // ── NL parsing ─────────────────────────────────────────────────────────────

  /** Keyword → category mapping for client-side inference. */
  const CATEGORY_SIGNALS: Array<[string[], AgentCategory]> = [
    [['security', 'audit', 'vulnerability', 'pen test', 'owasp'], 'technology'],
    [['pr', 'pull request', 'review', 'code review', 'diff'], 'engineering'],
    [['test', 'qa', 'quality', 'spec', 'e2e'], 'testing'],
    [['deploy', 'ci', 'pipeline', 'devops', 'kubernetes', 'docker'], 'engineering'],
    [['sales', 'crm', 'lead', 'prospect', 'outreach'], 'sales'],
    [['market', 'content', 'social', 'blog', 'seo', 'copy'], 'marketing'],
    [['design', 'ui', 'ux', 'figma', 'wireframe'], 'design'],
    [['product', 'roadmap', 'feature', 'backlog', 'sprint'], 'product'],
    [['support', 'ticket', 'customer', 'help', 'issue'], 'support'],
    [['data', 'analytics', 'sql', 'report', 'dashboard'], 'technology'],
    [['executive', 'strategy', 'board', 'ceo', 'cto'], 'executive'],
    [['ops', 'operations', 'process', 'workflow', 'automation'], 'operations'],
  ];

  /** Extract a human-readable name from a description. */
  function parseName(desc: string): string {
    const lower = desc.toLowerCase();

    // Pattern: "an agent that <verb>s <noun>" → "<verb> <noun> agent"
    const that = lower.match(/agent\s+that\s+([\w\s]+?)(?:\s+and\s+|\s+or\s+|$)/);
    if (that?.[1]) {
      const phrase = that[1].trim().replace(/\s+/g, ' ');
      const words = phrase.split(' ').slice(0, 4);
      return words.map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') + ' Agent';
    }

    // Fallback: first 3 meaningful words + "Agent"
    const words = desc
      .replace(/[^\w\s]/g, '')
      .split(/\s+/)
      .filter((w) => w.length > 3)
      .slice(0, 3);

    if (words.length === 0) return 'Custom Agent';
    return words.map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') + ' Agent';
  }

  /** Convert name to a valid kebab-case slug. */
  function toSlug(name: string): string {
    return name
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\w-]/g, '')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 48);
  }

  /** Infer category from description keywords. */
  function inferCategory(desc: string): AgentCategory {
    const lower = desc.toLowerCase();
    for (const [signals, cat] of CATEGORY_SIGNALS) {
      if (signals.some((kw) => lower.includes(kw))) return cat;
    }
    return 'specialized';
  }

  /** Extract skill keywords as tool suggestions. */
  function extractTools(desc: string): string[] {
    const toolPatterns = [
      'github', 'jira', 'slack', 'notion', 'figma', 'linear',
      'postgres', 'mysql', 'redis', 'aws', 'gcp', 'azure',
      'bash', 'python', 'typescript', 'rust', 'elixir',
    ];
    const lower = desc.toLowerCase();
    return toolPatterns.filter((t) => lower.includes(t)).slice(0, 6);
  }

  function generateConfig(desc: string): CreateAgentBody {
    const name = parseName(desc);
    return {
      slug: toSlug(name),
      name,
      category: inferCategory(desc),
      description: desc.trim(),
      default_runtime: 'claude-local',
      tools: extractTools(desc),
    };
  }

  function handleGenerate(): void {
    if (!description.trim()) return;
    preview = generateConfig(description);
    submitError = null;
  }

  async function handleConfirm(): Promise<void> {
    if (!preview || isPending) return;
    isPending = true;
    submitError = null;
    try {
      const agent = await createAgent(preview);
      onClose();
      void goto(`/agents/${agent.slug}`);
    } catch (err) {
      submitError = err instanceof Error ? err.message : 'Failed to create agent.';
    } finally {
      isPending = false;
    }
  }

  function handleReset(): void {
    preview = null;
    submitError = null;
  }

  function handleBackdropClick(e: MouseEvent): void {
    if ((e.target as HTMLElement).classList.contains('nlac-backdrop')) onClose();
  }

  function handleKeydown(e: KeyboardEvent): void {
    if (e.key === 'Escape') onClose();
  }
</script>

<svelte:window onkeydown={handleKeydown} />

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div class="nlac-backdrop" onclick={handleBackdropClick}>
    <div
      class="nlac-modal"
      role="dialog"
      aria-modal="true"
      aria-label="Create agent with AI"
    >
      <!-- Header -->
      <header class="nlac-header">
        <div class="nlac-header__title">
          <Sparkles size={15} aria-hidden="true" class="nlac-sparkle-icon" />
          <span>Create with AI</span>
        </div>
        <button class="nlac-close" onclick={onClose} aria-label="Close">
          <X size={14} aria-hidden="true" />
        </button>
      </header>

      <!-- Body -->
      <div class="nlac-body">
        {#if !preview}
          <!-- Input step -->
          <p class="nlac-hint">
            Describe what you need and we'll generate an agent config.
          </p>
          <textarea
            class="nlac-textarea"
            placeholder='e.g. "I need an agent that reviews PRs and checks for security issues"'
            rows={4}
            bind:value={description}
            aria-label="Describe the agent"
          ></textarea>
        {:else}
          <!-- Preview step -->
          <div class="nlac-preview">
            <div class="nlac-preview__icon" aria-hidden="true">
              <CheckCircle size={16} />
            </div>
            <p class="nlac-preview__label">Generated config — review before creating:</p>
            <dl class="nlac-preview__fields">
              <div class="nlac-preview__row">
                <dt>Name</dt>
                <dd>{preview.name}</dd>
              </div>
              <div class="nlac-preview__row">
                <dt>Slug</dt>
                <dd class="nlac-mono">{preview.slug}</dd>
              </div>
              <div class="nlac-preview__row">
                <dt>Category</dt>
                <dd>{preview.category}</dd>
              </div>
              <div class="nlac-preview__row">
                <dt>Runtime</dt>
                <dd class="nlac-mono">{preview.default_runtime}</dd>
              </div>
              {#if preview.tools && preview.tools.length > 0}
                <div class="nlac-preview__row">
                  <dt>Tools</dt>
                  <dd>{preview.tools.join(', ')}</dd>
                </div>
              {/if}
            </dl>
          </div>
        {/if}

        {#if submitError}
          <p class="nlac-error" role="alert">{submitError}</p>
        {/if}
      </div>

      <!-- Footer -->
      <footer class="nlac-footer">
        {#if !preview}
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            type="button"
            onclick={onClose}
          >
            Cancel
          </button>
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            type="button"
            onclick={handleGenerate}
            disabled={!description.trim()}
          >
            <Sparkles size={12} aria-hidden="true" />
            Generate
          </button>
        {:else}
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            type="button"
            onclick={handleReset}
            disabled={isPending}
          >
            Back
          </button>
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            type="button"
            onclick={handleConfirm}
            disabled={isPending}
            aria-busy={isPending}
          >
            {isPending ? 'Creating…' : 'Create Agent'}
          </button>
        {/if}
      </footer>
    </div>
  </div>
{/if}

<style>
  .nlac-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 40%, transparent);
    backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 900;
    padding: var(--space-4);
  }

  .nlac-modal {
    width: 100%;
    max-width: 440px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl, 16px);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    box-shadow: 0 24px 80px color-mix(in oklch, black 28%, transparent);
  }

  /* ── Header ──────────────────────────────────────────────────────────────── */

  .nlac-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .nlac-header__title {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
  }

  :global(.nlac-sparkle-icon) {
    color: var(--cnp-accent, oklch(0.55 0.18 250));
    flex-shrink: 0;
  }

  .nlac-close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 28px;
    height: 28px;
    padding: 0;
    background: transparent;
    border: 1px solid transparent;
    border-radius: var(--radius-sm);
    color: var(--fg-muted);
    cursor: pointer;
    transition: background 0.1s, color 0.1s;
  }

  .nlac-close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
  }

  /* ── Body ────────────────────────────────────────────────────────────────── */

  .nlac-body {
    flex: 1;
    padding: var(--space-4) var(--space-5);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .nlac-hint {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .nlac-textarea {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    resize: vertical;
    outline: none;
    transition: border-color 0.1s;
    box-sizing: border-box;
  }

  .nlac-textarea:focus {
    border-color: var(--cnp-accent, oklch(0.55 0.18 250));
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--cnp-accent, oklch(0.55 0.18 250)) 18%, transparent);
  }

  .nlac-textarea::placeholder {
    color: var(--fg-subtle);
  }

  /* ── Preview ─────────────────────────────────────────────────────────────── */

  .nlac-preview {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .nlac-preview__icon {
    color: oklch(0.6 0.18 145);
    display: flex;
    align-items: center;
  }

  .nlac-preview__label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  .nlac-preview__fields {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: var(--space-3) var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    margin: 0;
  }

  .nlac-preview__row {
    display: flex;
    align-items: baseline;
    gap: var(--space-3);
  }

  .nlac-preview__row dt {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    min-width: 72px;
    flex-shrink: 0;
  }

  .nlac-preview__row dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    margin: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .nlac-mono {
    font-family: var(--font-mono) !important;
    font-size: 12px !important;
  }

  /* ── Error ───────────────────────────────────────────────────────────────── */

  .nlac-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--destructive, oklch(0.55 0.22 25));
    margin: 0;
  }

  /* ── Footer ──────────────────────────────────────────────────────────────── */

  .nlac-footer {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-3);
    padding: var(--space-3) var(--space-5) var(--space-4);
    border-top: 1px solid var(--border);
    flex-shrink: 0;
  }
</style>
