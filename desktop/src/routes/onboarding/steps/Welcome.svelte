<script lang="ts">
  import type { AdapterType } from '$lib/stores/onboarding.svelte';
  import { isTauri } from '$lib/utils/platform';

  interface Props {
    displayName: string;
    onImport: (result: {
      workspacePath: string;
      workspaceName: string;
      adapter: AdapterType;
      teamTemplate: 'solo' | 'dev-team' | 'research' | 'custom';
      agents: import('$lib/stores/onboarding.svelte').AgentTemplateData[];
      jumpToStep: number;
    }) => void;
  }

  let { displayName = $bindable(), onImport }: Props = $props();

  async function importWorkspace() {
    if (!isTauri()) {
      onImport({ workspacePath: '', workspaceName: '', adapter: 'osa', teamTemplate: 'custom', agents: [], jumpToStep: 3 });
      return;
    }
    try {
      const { open } = await import('@tauri-apps/plugin-dialog');
      const selected = await open({ directory: true, multiple: false, title: 'Import Existing Workspace' });
      if (!selected || typeof selected !== 'string') return;

      const { invoke } = await import('@tauri-apps/api/core');
      try {
        const workspace = await invoke('scan_canopy_dir', { path: selected }) as {
          name?: string;
          agents?: { id: string; name: string; adapter: string; role: string }[];
        };

        let adapter: AdapterType = 'osa';
        let agents: import('$lib/stores/onboarding.svelte').AgentTemplateData[] = [];

        if (workspace.agents && workspace.agents.length > 0) {
          adapter = (workspace.agents[0].adapter?.replace(/_/g, '-') as AdapterType) ?? 'osa';
          agents = workspace.agents.map(a => ({
            id: a.id,
            name: a.name,
            emoji: 'bot',
            role: a.role || 'engineer',
            adapter: a.adapter || 'osa',
            skills: [],
          }));
        }

        onImport({
          workspacePath: selected,
          workspaceName: workspace.name ?? '',
          adapter,
          teamTemplate: 'custom',
          agents,
          jumpToStep: 6,
        });
      } catch {
        onImport({ workspacePath: selected, workspaceName: '', adapter: 'osa', teamTemplate: 'custom', agents: [], jumpToStep: 3 });
      }
    } catch {
      // Dialog cancelled or unavailable — no action needed
    }
  }
</script>

<div class="ob-step">
  <div class="ob-logo-wrap">
    <video
      class="ob-logo-video"
      src="/MergedAnimationOS.mp4"
      autoplay
      muted
      playsinline
      onended={(e) => { const v = e.currentTarget as HTMLVideoElement; v.src = '/OSLoopingActiveMode.mp4'; v.loop = true; v.play(); }}
    ></video>
  </div>
  <h1 class="ob-title">Welcome to Canopy</h1>
  <p class="ob-subtitle">Your AI agent command center</p>
  <div class="ob-field">
    <label class="ob-label" for="ob-name">YOUR NAME</label>
    <input
      id="ob-name"
      class="ob-input"
      type="text"
      placeholder="e.g. Roberto"
      bind:value={displayName}
    />
  </div>
  <div class="ob-import-section">
    <span class="ob-import-divider">
      <span class="ob-import-divider-line"></span>
      <span class="ob-import-divider-text">or</span>
      <span class="ob-import-divider-line"></span>
    </span>
    <button class="ob-import-btn" onclick={importWorkspace}>
      <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="16" height="16"><path d="M3 10v5a2 2 0 002 2h10a2 2 0 002-2v-5"/><path d="M10 3v10M6 7l4-4 4 4"/></svg>
      Import existing workspace
    </button>
    <p class="ob-import-hint">Have a .canopy/ workspace already? Import it and we'll detect your config.</p>
  </div>
</div>

<style>
  .ob-step {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
    flex: 1;
    gap: 0;
  }

  .ob-logo-wrap {
    width: 140px;
    height: 140px;
    margin: 0 auto 1.25rem;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 28px;
    overflow: hidden;
  }

  .ob-logo-video {
    width: 140px;
    height: 140px;
    object-fit: contain;
    mix-blend-mode: lighten;
  }

  .ob-title {
    font-size: 1.625rem;
    font-weight: 700;
    color: #ffffff;
    margin: 0 0 0.375rem;
    letter-spacing: -0.02em;
  }

  .ob-subtitle {
    font-size: 0.875rem;
    color: rgba(255, 255, 255, 0.45);
    margin: 0 0 1.75rem;
  }

  .ob-label {
    display: block;
    font-size: 0.6875rem;
    font-weight: 600;
    letter-spacing: 0.08em;
    color: rgba(255, 255, 255, 0.35);
    margin-bottom: 0.375rem;
    text-align: left;
  }

  .ob-field {
    width: 100%;
    text-align: left;
    margin-bottom: 1rem;
  }

  .ob-input {
    width: 100%;
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 0.625rem 0.875rem;
    font-size: 0.9375rem;
    color: #f0f0f0;
    outline: none;
    transition: border-color 150ms ease;
    box-sizing: border-box;
  }

  .ob-input::placeholder {
    color: rgba(255, 255, 255, 0.2);
  }

  .ob-input:focus {
    border-color: rgba(59, 130, 246, 0.5);
  }

  .ob-import-section {
    width: 100%;
    max-width: 320px;
    margin-top: 1.25rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 0.5rem;
  }

  .ob-import-divider {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    width: 100%;
    margin-bottom: 0.25rem;
  }

  .ob-import-divider-line {
    flex: 1;
    height: 1px;
    background: rgba(255, 255, 255, 0.08);
  }

  .ob-import-divider-text {
    font-size: 0.75rem;
    color: rgba(255, 255, 255, 0.3);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .ob-import-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    border-radius: 9999px;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: rgba(255, 255, 255, 0.04);
    color: rgba(255, 255, 255, 0.6);
    font-size: 0.8125rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 150ms ease;
  }

  .ob-import-btn:hover {
    background: rgba(255, 255, 255, 0.08);
    color: rgba(255, 255, 255, 0.85);
    border-color: rgba(255, 255, 255, 0.18);
  }

  .ob-import-hint {
    font-size: 0.6875rem;
    color: rgba(255, 255, 255, 0.25);
    text-align: center;
    margin: 0;
    line-height: 1.4;
  }
</style>
