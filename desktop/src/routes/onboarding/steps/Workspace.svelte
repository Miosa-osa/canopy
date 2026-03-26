<script lang="ts">
  import { isTauri } from '$lib/utils/platform';

  interface Props {
    workspacePath: string;
    workspaceName: string;
    workspaceDesc: string;
  }

  let {
    workspacePath = $bindable(),
    workspaceName = $bindable(),
    workspaceDesc = $bindable(),
  }: Props = $props();

  // Auto-fill workspace name from path only when the path actually changes
  // (not on the initial render). Using $state so the guard persists across
  // reactive re-runs within the same component instance.
  let lastAutoPath = $state(workspacePath);
  $effect(() => {
    const p = workspacePath;
    if (p === lastAutoPath) return;
    lastAutoPath = p;
    const parts = p.split('/');
    const last = parts[parts.length - 1];
    if (last && last !== '~' && last !== '.canopy') {
      workspaceName = last.replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
    } else if (p.includes('.canopy') || p === '~/.canopy') {
      workspaceName = 'My Workspace';
    }
  });

  async function choosePath() {
    if (!isTauri()) return;
    try {
      const { open } = await import('@tauri-apps/plugin-dialog');
      const selected = await open({ directory: true, multiple: false, title: 'Choose Workspace Directory' });
      if (selected && typeof selected === 'string') {
        workspacePath = selected;
      }
    } catch {
      // Dialog cancelled or unavailable — no action needed
    }
  }

  function dirBaseName(path: string): string {
    const trimmed = path.replace(/\/$/, '');
    return trimmed.split('/').pop() ?? trimmed;
  }
</script>

<div class="ob-step">
  <div class="ob-step-icon">
    <svg viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="28" height="28">
      <path d="M3 7a2 2 0 012-2h3.586a1 1 0 01.707.293L10.707 6.7A1 1 0 0011.414 7H15a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/>
    </svg>
  </div>
  <h1 class="ob-title">Workspace</h1>
  <p class="ob-subtitle">Where your agents live</p>

  <div class="ob-field">
    <label class="ob-label" for="ob-path">DIRECTORY PATH</label>
    <div class="ob-path-row">
      <input
        id="ob-path"
        class="ob-input ob-input--path"
        type="text"
        placeholder="~/.canopy"
        bind:value={workspacePath}
      />
      <button class="ob-btn ob-btn--secondary ob-btn--sm" onclick={choosePath}>
        <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" width="14" height="14"><path d="M2 4a1 1 0 011-1h3l1.5 1.5H13a1 1 0 011 1V12a1 1 0 01-1 1H3a1 1 0 01-1-1V4z"/></svg>
        Choose
      </button>
    </div>
  </div>

  <div class="ob-field">
    <label class="ob-label" for="ob-ws-name">WORKSPACE NAME</label>
    <input
      id="ob-ws-name"
      class="ob-input"
      type="text"
      placeholder="My Workspace"
      bind:value={workspaceName}
    />
  </div>

  <div class="ob-field">
    <label class="ob-label" for="ob-ws-desc">DESCRIPTION (OPTIONAL)</label>
    <input
      id="ob-ws-desc"
      class="ob-input"
      type="text"
      placeholder="What this workspace is for..."
      bind:value={workspaceDesc}
    />
  </div>

  <div class="ob-tree-wrap">
    <p class="ob-label">WILL CREATE</p>
    <pre class="ob-tree">{dirBaseName(workspacePath) || '.canopy'}/
├── .canopy/
│   ├── workspace.json
│   ├── agents/
│   │   └── (agent configs)
│   ├── sessions/
│   └── logs/</pre>
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

  .ob-step-icon {
    width: 52px;
    height: 52px;
    border-radius: 14px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.08);
    display: flex;
    align-items: center;
    justify-content: center;
    color: rgba(255, 255, 255, 0.6);
    margin: 0 auto 1.25rem;
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

  .ob-input--path {
    flex: 1;
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 0.8125rem;
  }

  .ob-path-row {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .ob-tree-wrap {
    width: 100%;
    margin-top: 0.25rem;
  }

  .ob-tree {
    background: rgba(0, 0, 0, 0.3);
    border: 1px solid rgba(255, 255, 255, 0.07);
    border-radius: 8px;
    padding: 0.875rem 1rem;
    font-size: 0.75rem;
    font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
    color: rgba(255, 255, 255, 0.45);
    margin: 0.375rem 0 0;
    line-height: 1.7;
    white-space: pre;
    overflow-x: auto;
  }

  .ob-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    cursor: pointer;
    border: none;
    padding: 0.625rem 1.25rem;
    transition: background 150ms ease, opacity 150ms ease, transform 150ms ease, box-shadow 150ms ease;
  }

  .ob-btn--secondary {
    background: rgba(255, 255, 255, 0.05);
    backdrop-filter: blur(10px);
    -webkit-backdrop-filter: blur(10px);
    color: #a1a1a6;
    border: 1px solid rgba(255, 255, 255, 0.1);
    box-shadow: 0 1px 0 0 rgba(255, 255, 255, 0.04) inset;
  }

  .ob-btn--secondary:not(:disabled):hover {
    background: rgba(255, 255, 255, 0.1);
    border-color: rgba(255, 255, 255, 0.15);
  }

  .ob-btn--sm {
    padding: 0.5rem 0.75rem;
    font-size: 0.8125rem;
    flex-shrink: 0;
  }
</style>
