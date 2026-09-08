<script lang="ts">
/**
 * OpenInEditorButton — opens a filesystem path in the user's preferred editor.
 * CSS prefix: oeb-
 * Uses @tauri-apps/plugin-shell Command if available; falls back to clipboard.
 * LOC target: ≤ 110.
 */

interface EditorOption {
  command: string;
  name: string;
  /** Deep-link URI scheme, e.g. vscode://file/{path} — used when Tauri shell fails */
  deepLink?: (path: string) => string;
}

interface Props {
  path: string;
  class?: string;
}

let { path, class: className = '' }: Props = $props();

const STORAGE_KEY = 'canopy.default_editor';

const EDITORS: EditorOption[] = [
  {
    command: 'code',
    name: 'VS Code',
    deepLink: (p) => `vscode://file/${encodeURIComponent(p)}`,
  },
  {
    command: 'cursor',
    name: 'Cursor',
    deepLink: (p) => `cursor://file/${encodeURIComponent(p)}`,
  },
  {
    command: 'webstorm',
    name: 'WebStorm',
    deepLink: (p) =>
      `jetbrains://web-storm/navigate/reference?project=canopy&path=${encodeURIComponent(p)}`,
  },
  {
    command: 'idea',
    name: 'IDEA',
    deepLink: (p) =>
      `jetbrains://idea/navigate/reference?project=canopy&path=${encodeURIComponent(p)}`,
  },
  { command: 'subl', name: 'Sublime Text' },
  { command: 'vim', name: 'Vim' },
];

// ── State ───────────────────────────────────────────────────────────────────

let dropdownOpen = $state(false);
let copied = $state(false);

let defaultEditor = $state<string>(
  typeof localStorage !== 'undefined' ? (localStorage.getItem(STORAGE_KEY) ?? 'code') : 'code'
);

const currentEditor = $derived(EDITORS.find((e) => e.command === defaultEditor) ?? EDITORS[0]);

function setDefaultEditor(command: string): void {
  defaultEditor = command;
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, command);
  }
  dropdownOpen = false;
}

// ── Open logic ──────────────────────────────────────────────────────────────

async function openInEditor(editorCommand: string): Promise<void> {
  const editor = EDITORS.find((e) => e.command === editorCommand) ?? EDITORS[0];
  try {
    const { Command } = await import('@tauri-apps/plugin-shell');
    const cmd = Command.create(editorCommand, [path]);
    await cmd.spawn();
  } catch {
    // Tauri unavailable — try deep-link URI first, then clipboard fallback
    if (editor.deepLink) {
      try {
        window.open(editor.deepLink(path), '_self');
        dropdownOpen = false;
        return;
      } catch {
        // fall through to clipboard
      }
    }
    const shellCmd = `${editorCommand} "${path}"`;
    try {
      await navigator.clipboard.writeText(shellCmd);
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch {
      // clipboard also unavailable — silently fail
    }
  }
  dropdownOpen = false;
}

function handleKeydown(e: KeyboardEvent): void {
  if (e.key === 'Escape') dropdownOpen = false;
}
</script>

<svelte:window onkeydown={handleKeydown} />

<div class="oeb-wrap {className}">
  <button
    class="oeb-main btn-compact btn-compact-ghost"
    onclick={() => openInEditor(currentEditor.command)}
    title="Open {path} in {currentEditor.name}"
    aria-label="Open in {currentEditor.name}"
    disabled={!path}
  >
    {#if copied}
      Command copied
    {:else}
      Open in {currentEditor.name}
    {/if}
  </button>

  <button
    class="oeb-caret btn-compact btn-compact-ghost"
    onclick={() => { dropdownOpen = !dropdownOpen; }}
    aria-haspopup="listbox"
    aria-expanded={dropdownOpen}
    aria-label="Choose editor"
    title="Choose editor"
  >▾</button>

  {#if dropdownOpen}
    <div class="oeb-dropdown" role="listbox" aria-label="Editor options">
      {#each EDITORS as editor (editor.command)}
        <button
          class="oeb-option"
          class:oeb-option--active={editor.command === defaultEditor}
          role="option"
          aria-selected={editor.command === defaultEditor}
          onclick={() => { setDefaultEditor(editor.command); openInEditor(editor.command); }}
        >
          {editor.name}
        </button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .oeb-wrap {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 0;
  }

  .oeb-main {
    font-size: var(--text-xs);
    border-radius: var(--radius-sm) 0 0 var(--radius-sm);
    border-right: 1px solid var(--border);
  }

  .oeb-caret {
    font-size: var(--text-xs);
    padding: 0 var(--space-1);
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
    line-height: 1;
  }

  .oeb-dropdown {
    position: absolute;
    top: calc(100% + 4px);
    right: 0;
    z-index: 50;
    min-width: 140px;
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    box-shadow: 0 4px 16px color-mix(in oklch, var(--fg) 12%, transparent);
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .oeb-option {
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    background: transparent;
    border: none;
    text-align: left;
    cursor: pointer;
    transition: background 0.1s ease, color 0.1s ease;
  }

  .oeb-option:hover { background: color-mix(in oklch, var(--fg) 6%, transparent); color: var(--fg); }
  .oeb-option--active { color: var(--fg); font-weight: 600; }
</style>
