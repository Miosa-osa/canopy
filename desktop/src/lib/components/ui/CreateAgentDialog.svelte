<!-- src/lib/components/ui/CreateAgentDialog.svelte -->
<!--
  Sprint 02: Filesystem-based agent deployment.
  Writes .canopy/agents/[id].md via @tauri-apps/plugin-fs.
  4 fields: name, role, adapter, system_prompt.
  CSS prefix: cad- (Create Agent Dialog)
-->
<script lang="ts">
  import { isTauri } from '$lib/utils/platform';
  import { workspaceStore } from '$lib/stores/workspace.svelte';
  import { toastStore } from '$lib/stores/toasts.svelte';

  interface Props {
    open: boolean;
    onClose: () => void;
  }

  let { open, onClose }: Props = $props();

  // Form state
  let name = $state('');
  let role = $state('');
  let adapter = $state<'claude_code' | 'codex' | 'osa' | 'openai' | 'anthropic'>('claude_code');
  let systemPrompt = $state('');
  let isSubmitting = $state(false);
  let errors = $state<Record<string, string>>({});

  const ADAPTERS = [
    { value: 'claude_code', label: 'Claude Code' },
    { value: 'osa', label: 'OSA' },
    { value: 'codex', label: 'Codex' },
    { value: 'openai', label: 'OpenAI' },
    { value: 'anthropic', label: 'Anthropic' },
  ] as const;

  function deriveId(n: string): string {
    return n.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-_]/g, '');
  }

  let agentId = $derived(deriveId(name));

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!name.trim()) {
      e.name = 'Name is required';
    } else if (!agentId) {
      e.name = 'Name must contain at least one letter or number';
    }
    if (!role.trim()) e.role = 'Role is required';
    errors = e;
    return Object.keys(e).length === 0;
  }

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault();
    if (!validate()) return;

    const workspacePath = workspaceStore.activeWorkspace?.path;
    if (!workspacePath) {
      toastStore.error('No workspace', 'Set an active workspace first.');
      return;
    }

    isSubmitting = true;
    try {
      const id = agentId;
      const content = `---
name: ${name.trim()}
id: ${id}
role: ${role.trim()}
adapter: ${adapter}
model: claude-sonnet-4-6
skills: []
context_tier: l1
---

# ${name.trim()}

${systemPrompt.trim() || `AI agent for ${role.trim()} tasks.`}
`;

      const agentsDir = `${workspacePath}/.canopy/agents`;
      const filePath = `${agentsDir}/${id}.md`;

      if (isTauri()) {
        const { writeTextFile, mkdir } = await import('@tauri-apps/plugin-fs');
        // Ensure .canopy/agents/ exists
        try {
          await mkdir(agentsDir, { recursive: true });
        } catch {
          // Directory may already exist — continue
        }
        await writeTextFile(filePath, content);
      } else {
        // Dev/browser fallback: log what would be written
        console.log('[CreateAgentDialog] Would write to:', filePath);
        console.log(content);
      }

      // Reload agents from the workspace filesystem
      await workspaceStore.scanAndLoadAgents(workspacePath);

      toastStore.success('Agent deployed', `${name.trim()} written to .canopy/agents/${id}.md`);
      resetForm();
      onClose();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      toastStore.error('Deploy failed', msg);
    } finally {
      isSubmitting = false;
    }
  }

  function resetForm() {
    name = '';
    role = '';
    adapter = 'claude_code';
    systemPrompt = '';
    errors = {};
  }

  function handleBackdrop(e: MouseEvent) {
    if ((e.target as HTMLElement).classList.contains('cad-overlay')) onClose();
  }

  function handleKeyDown(e: KeyboardEvent) {
    if (e.key === 'Escape') onClose();
  }
</script>

{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="cad-overlay"
    onclick={handleBackdrop}
    onkeydown={handleKeyDown}
    role="dialog"
    aria-modal="true"
    aria-label="Deploy a new agent"
    tabindex="-1"
  >
    <div class="cad-modal">
      <header class="cad-header">
        <h2 class="cad-title">Deploy Agent</h2>
        <button class="cad-close" onclick={onClose} aria-label="Close dialog">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        </button>
      </header>

      <form class="cad-form" onsubmit={handleSubmit} novalidate>
        <!-- Name -->
        <div class="cad-field">
          <label class="cad-label" for="cad-name">
            Name
            {#if agentId && name.trim()}
              <span class="cad-id-preview">id: {agentId}</span>
            {/if}
          </label>
          <input
            id="cad-name"
            class="cad-input"
            class:cad-input--error={!!errors.name}
            type="text"
            placeholder="e.g. Frontend Dev"
            autocomplete="off"
            bind:value={name}
            aria-describedby={errors.name ? 'cad-name-err' : undefined}
          />
          {#if errors.name}
            <span class="cad-error" id="cad-name-err" role="alert">{errors.name}</span>
          {/if}
        </div>

        <!-- Role -->
        <div class="cad-field">
          <label class="cad-label" for="cad-role">Role</label>
          <input
            id="cad-role"
            class="cad-input"
            class:cad-input--error={!!errors.role}
            type="text"
            placeholder="e.g. Writes and reviews Svelte components"
            autocomplete="off"
            bind:value={role}
            aria-describedby={errors.role ? 'cad-role-err' : undefined}
          />
          {#if errors.role}
            <span class="cad-error" id="cad-role-err" role="alert">{errors.role}</span>
          {/if}
        </div>

        <!-- Adapter -->
        <div class="cad-field">
          <label class="cad-label" for="cad-adapter">Adapter</label>
          <select id="cad-adapter" class="cad-select" bind:value={adapter}>
            {#each ADAPTERS as opt (opt.value)}
              <option value={opt.value}>{opt.label}</option>
            {/each}
          </select>
        </div>

        <!-- System Prompt -->
        <div class="cad-field">
          <label class="cad-label" for="cad-prompt">
            System Prompt
            <span class="cad-optional">(optional)</span>
          </label>
          <textarea
            id="cad-prompt"
            class="cad-textarea"
            placeholder="Describe what this agent should do and how it should behave…"
            rows="4"
            bind:value={systemPrompt}
          ></textarea>
        </div>

        <footer class="cad-footer">
          <button
            type="button"
            class="cad-btn cad-btn--secondary"
            onclick={onClose}
            aria-label="Cancel"
          >
            Cancel
          </button>
          <button
            type="submit"
            class="cad-btn cad-btn--primary"
            disabled={isSubmitting}
            aria-label="Deploy agent"
            aria-busy={isSubmitting}
          >
            {#if isSubmitting}
              <span class="cad-spinner" aria-hidden="true"></span>
              Deploying…
            {:else}
              Deploy Agent
            {/if}
          </button>
        </footer>
      </form>
    </div>
  </div>
{/if}

<style>
  .cad-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    padding: 24px;
  }

  .cad-modal {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-xl, 12px);
    width: 100%;
    max-width: 480px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 24px 80px rgba(0, 0, 0, 0.5);
    overflow: hidden;
  }

  .cad-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 18px 20px;
    border-bottom: 1px solid var(--border-default);
    flex-shrink: 0;
  }

  .cad-title {
    font-size: 15px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
  }

  .cad-close {
    width: 28px;
    height: 28px;
    border-radius: var(--radius-xs, 4px);
    border: 1px solid transparent;
    background: transparent;
    color: var(--text-tertiary);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 120ms ease;
  }

  .cad-close:hover {
    background: var(--bg-elevated);
    border-color: var(--border-default);
    color: var(--text-primary);
  }

  .cad-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 20px;
  }

  .cad-field {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .cad-label {
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .cad-id-preview {
    font-size: 11px;
    color: var(--text-tertiary);
    font-weight: 400;
    font-family: var(--font-mono, monospace);
  }

  .cad-optional {
    font-size: 11px;
    color: var(--text-tertiary);
    font-weight: 400;
  }

  .cad-input,
  .cad-select {
    height: 34px;
    padding: 0 10px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm, 6px);
    color: var(--text-primary);
    font-size: 13px;
    font-family: var(--font-sans, sans-serif);
    outline: none;
    transition: border-color 120ms ease;
    width: 100%;
    box-sizing: border-box;
  }

  .cad-input:focus,
  .cad-select:focus {
    border-color: rgba(99, 102, 241, 0.6);
  }

  .cad-input--error {
    border-color: rgba(239, 68, 68, 0.6);
  }

  .cad-input--error:focus {
    border-color: rgba(239, 68, 68, 0.8);
  }

  .cad-select {
    appearance: none;
    cursor: pointer;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='rgba(255,255,255,0.4)' stroke-width='2'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E");
    background-repeat: no-repeat;
    background-position: right 10px center;
    padding-right: 32px;
  }

  .cad-textarea {
    padding: 8px 10px;
    background: var(--bg-secondary);
    border: 1px solid var(--border-default);
    border-radius: var(--radius-sm, 6px);
    color: var(--text-primary);
    font-size: 13px;
    font-family: var(--font-sans, sans-serif);
    outline: none;
    resize: vertical;
    min-height: 80px;
    transition: border-color 120ms ease;
    width: 100%;
    box-sizing: border-box;
    line-height: 1.5;
  }

  .cad-textarea:focus {
    border-color: rgba(99, 102, 241, 0.6);
  }

  .cad-error {
    font-size: 11px;
    color: #fca5a5;
  }

  .cad-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    border-top: 1px solid var(--border-default);
    background: var(--bg-secondary);
    margin: 0 -20px -20px;
  }

  .cad-btn {
    height: 34px;
    padding: 0 16px;
    border-radius: var(--radius-sm, 6px);
    font-size: 13px;
    font-weight: 500;
    font-family: var(--font-sans, sans-serif);
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 6px;
    transition: all 120ms ease;
    border: 1px solid transparent;
  }

  .cad-btn--secondary {
    background: transparent;
    border-color: var(--border-default);
    color: var(--text-secondary);
  }

  .cad-btn--secondary:hover {
    background: var(--bg-elevated);
    border-color: var(--border-hover);
    color: var(--text-primary);
  }

  .cad-btn--primary {
    background: rgba(99, 102, 241, 0.2);
    border-color: rgba(99, 102, 241, 0.5);
    color: #a5b4fc;
  }

  .cad-btn--primary:hover:not(:disabled) {
    background: rgba(99, 102, 241, 0.3);
    border-color: rgba(99, 102, 241, 0.7);
    color: #c7d2fe;
  }

  .cad-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .cad-spinner {
    width: 12px;
    height: 12px;
    border: 2px solid rgba(165, 180, 252, 0.3);
    border-top-color: #a5b4fc;
    border-radius: 50%;
    animation: cad-spin 0.7s linear infinite;
    flex-shrink: 0;
  }

  @keyframes cad-spin {
    to { transform: rotate(360deg); }
  }
</style>
