<script lang="ts">
  /**
   * ComposerChips — strip of contextual chips that sits below the
   * Composer textarea inside an Agent Conversation pane.
   *
   * Layout:
   *   📁 cwd (popover) · model · 📡 remote · ✨ Rich Input · 🌳 Files
   *   · 🔔 runtime notifications (only when embeddedRuntime set)
   *   · 🎤 mic · ➕ attach
   *
   * Stateless presentation — every chip emits an event and the parent
   * (`ConversationComposer`) owns the source of truth.
   *
   * CSS prefix: cnp-chips-
   */
  import {
    Box,
    Calendar,
    ChevronDown,
    Clock,
    FolderOpen,
    LayoutTemplate,
    Folder,
    Mic,
    Plus,
    Radio,
    Sparkles,
    SquareArrowOutUpRight,
    Zap,
  } from 'lucide-svelte';
  import CwdPickerPopover from './CwdPickerPopover.svelte';
  import FileExplorerChip from './FileExplorerChip.svelte';
  import RichInputToggle from './RichInputToggle.svelte';
  import RuntimeNotificationChip from './RuntimeNotificationChip.svelte';
  import DrivePickerPopover from './module-launchers/DrivePickerPopover.svelte';
  import SkillsPickerPopover from './module-launchers/SkillsPickerPopover.svelte';
  import TemplatesPickerPopover from './module-launchers/TemplatesPickerPopover.svelte';
  import SandboxQuickActions from './module-launchers/SandboxQuickActions.svelte';
  import ScheduleQuickActions from './module-launchers/ScheduleQuickActions.svelte';
  import type { DriveEntry } from '$lib/domain/drive/types.js';
  import type { Skill } from '$lib/domain/skills/types.js';
  import type { Template } from '$lib/domain/templates/types.js';

  interface Props {
    cwd: string;
    model: string;
    remoteControl?: boolean;

    /** Workspace slug — required for the cwd picker + file explorer chips. */
    workspaceSlug?: string;

    /** Set when the pane is hosting an embedded runtime — unlocks the
     *  rich-input toggle + notification chip. */
    embeddedRuntimeType?: string | null;
    /** Two-way: ON = composer visible; OFF = passthrough to runtime. */
    richInputOn?: boolean;
    /** Per-runtime notification preference. */
    notificationsOn?: boolean;

    onCwdClick?: () => void;
    onCwdOpen?: () => void;
    /** Fires when the user picks a new working directory in the popover. */
    onCwdChange?: (newCwd: string) => void;
    onModelClick?: () => void;
    onRemoteToggle?: () => void;
    onMicClick?: () => void;
    onAttach?: () => void;
    onRichInputToggle?: () => void;
    /** Fires when the user picks a file in the explorer popover. */
    onPickFile?: (path: string) => void;
    onNotificationsToggle?: () => void;

    // ── Module-launcher hooks (Drive / Skills / Templates / Sandbox / Schedule)
    /** Drive picker — fires with a reference string (e.g. `"@drive:foo "`)
     *  to insert into the composer. */
    onPickDriveEntry?: (reference: string, entry: DriveEntry) => void;
    /** Skills picker — fires with the chosen skill so the parent can dispatch
     *  an `apply_skill` event to the embedded runtime. */
    onApplySkill?: (skill: Skill) => void;
    /** Templates picker — fires with the chosen template so the parent can
     *  navigate to /templates/[slug] or kick off `instantiate_template`. */
    onPickTemplate?: (template: Template) => void;
    /** Sandbox picker — emits the sandbox id selected. */
    onPickSandbox?: (sandboxId: string) => void;
    /** Sandbox picker — emits when "+ New" is clicked. */
    onNewSandbox?: () => void;
    /** Schedule — emits when "Schedule this conversation" is clicked. */
    onScheduleConversation?: () => void;
    /** Schedule — emits the spec slug picked from the recent list. */
    onPickSpec?: (slug: string) => void;
  }

  let {
    cwd,
    model,
    remoteControl = false,
    workspaceSlug,
    embeddedRuntimeType = null,
    richInputOn = true,
    notificationsOn = false,
    onCwdClick,
    onCwdOpen,
    onCwdChange,
    onModelClick,
    onRemoteToggle,
    onMicClick,
    onAttach,
    onRichInputToggle,
    onPickFile,
    onNotificationsToggle,
    onPickDriveEntry,
    onApplySkill,
    onPickTemplate,
    onPickSandbox,
    onNewSandbox,
    onScheduleConversation,
    onPickSpec,
  }: Props = $props();

  /** Truncate a working directory path for display. */
  function shortenCwd(p: string): string {
    if (!p) return '~';
    if (p.length <= 36) return p;
    const segs = p.split('/').filter(Boolean);
    if (segs.length <= 2) return p;
    return `…/${segs.slice(-2).join('/')}`;
  }

  const cwdShort = $derived(shortenCwd(cwd));

  // ── cwd popover state ──────────────────────────────────────────────────────
  let cwdPopOpen = $state(false);
  let cwdChipEl = $state<HTMLButtonElement | null>(null);

  function toggleCwdPop(): void {
    cwdPopOpen = !cwdPopOpen;
    onCwdClick?.();
  }

  // ── Module-launcher popover state ──────────────────────────────────────────
  // One slot — open at most one popover at a time. Cleaner than 5 booleans
  // when chips share a row.
  type LauncherSlot =
    | null
    | 'drive'
    | 'skills'
    | 'templates'
    | 'sandboxes'
    | 'schedule';

  let launcherOpen = $state<LauncherSlot>(null);

  function toggleLauncher(slot: Exclude<LauncherSlot, null>): void {
    launcherOpen = launcherOpen === slot ? null : slot;
  }

  function closeLauncher(): void {
    launcherOpen = null;
  }
</script>

<div class="cnp-chips" role="toolbar" aria-label="Conversation context">
  <!-- Working directory (popover) -->
  <div class="cnp-cwd-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={cwdPopOpen}
      onclick={toggleCwdPop}
      bind:this={cwdChipEl}
      aria-haspopup="dialog"
      aria-expanded={cwdPopOpen}
      aria-label="Working directory: {cwd}"
      title={cwd}
    >
      <Folder size={11} aria-hidden="true" />
      <span class="cnp-chip__label">{cwdShort}</span>
      <span
        class="cnp-chip__icon-action"
        role="button"
        tabindex="-1"
        aria-label="Open working directory in finder"
        onclick={(e) => {
          e.stopPropagation();
          onCwdOpen?.();
        }}
        onkeydown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            e.stopPropagation();
            onCwdOpen?.();
          }
        }}
      >
        <SquareArrowOutUpRight size={10} aria-hidden="true" />
      </span>
    </button>

    {#if cwdPopOpen && workspaceSlug}
      <div class="cnp-cwd-pop">
        <CwdPickerPopover
          workspaceSlug={workspaceSlug}
          {cwd}
          onPick={(newCwd) => onCwdChange?.(newCwd)}
          onClose={() => (cwdPopOpen = false)}
        />
      </div>
    {/if}
  </div>

  <!-- Model picker -->
  <button
    type="button"
    class="cnp-chip"
    onclick={onModelClick}
    aria-label="Model: {model}"
    title="Switch model — /model"
  >
    <Sparkles size={11} aria-hidden="true" />
    <span class="cnp-chip__label">{model}</span>
    <ChevronDown size={9} aria-hidden="true" />
  </button>

  <!-- Remote control toggle -->
  <button
    type="button"
    class="cnp-chip"
    class:cnp-chip--on={remoteControl}
    onclick={onRemoteToggle}
    aria-pressed={remoteControl}
    aria-label="Toggle remote control"
    title="Remote control — /remote-control"
  >
    <Radio size={11} aria-hidden="true" />
    <span class="cnp-chip__label">/remote-c…</span>
  </button>

  <!-- Rich Input toggle (only relevant when a runtime is embedded) -->
  {#if embeddedRuntimeType}
    <RichInputToggle
      on={richInputOn}
      enabled={true}
      onToggle={() => onRichInputToggle?.()}
    />
  {/if}

  <!-- File explorer (workspace-scoped) -->
  {#if workspaceSlug}
    <FileExplorerChip
      workspaceSlug={workspaceSlug}
      onPickFile={(path) => onPickFile?.(path)}
    />
  {/if}

  <!-- Per-runtime notification chip -->
  {#if embeddedRuntimeType}
    <RuntimeNotificationChip
      runtimeType={embeddedRuntimeType}
      on={notificationsOn}
      onToggle={() => onNotificationsToggle?.()}
    />
  {/if}

  <!-- ── Module launchers ─────────────────────────────────────────────────── -->
  <!-- Drive -->
  <div class="cnp-launcher-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={launcherOpen === 'drive'}
      onclick={() => toggleLauncher('drive')}
      aria-haspopup="dialog"
      aria-expanded={launcherOpen === 'drive'}
      aria-label="Drive entries"
      title="Drive — workflows, prompts, notebooks"
    >
      <FolderOpen size={11} aria-hidden="true" />
      <span class="cnp-chip__label">Drive</span>
    </button>
    {#if launcherOpen === 'drive'}
      <div class="cnp-launcher-pop">
        <DrivePickerPopover
          onPick={(reference, entry) => onPickDriveEntry?.(reference, entry)}
          onClose={closeLauncher}
        />
      </div>
    {/if}
  </div>

  <!-- Skills -->
  <div class="cnp-launcher-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={launcherOpen === 'skills'}
      onclick={() => toggleLauncher('skills')}
      aria-haspopup="dialog"
      aria-expanded={launcherOpen === 'skills'}
      aria-label="Apply skill"
      title="Skills"
    >
      <Zap size={11} aria-hidden="true" />
      <span class="cnp-chip__label">Skills</span>
    </button>
    {#if launcherOpen === 'skills'}
      <div class="cnp-launcher-pop">
        <SkillsPickerPopover
          onPick={(skill) => onApplySkill?.(skill)}
          onClose={closeLauncher}
        />
      </div>
    {/if}
  </div>

  <!-- Templates -->
  <div class="cnp-launcher-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={launcherOpen === 'templates'}
      onclick={() => toggleLauncher('templates')}
      aria-haspopup="dialog"
      aria-expanded={launcherOpen === 'templates'}
      aria-label="Instantiate template"
      title="Templates"
    >
      <LayoutTemplate size={11} aria-hidden="true" />
      <span class="cnp-chip__label">Templates</span>
    </button>
    {#if launcherOpen === 'templates'}
      <div class="cnp-launcher-pop">
        <TemplatesPickerPopover
          onPick={(template) => onPickTemplate?.(template)}
          onClose={closeLauncher}
        />
      </div>
    {/if}
  </div>

  <!-- Sandboxes -->
  <div class="cnp-launcher-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={launcherOpen === 'sandboxes'}
      onclick={() => toggleLauncher('sandboxes')}
      aria-haspopup="dialog"
      aria-expanded={launcherOpen === 'sandboxes'}
      aria-label="Sandboxes"
      title="Sandboxes"
    >
      <Box size={11} aria-hidden="true" />
      <span class="cnp-chip__label">Sandboxes</span>
    </button>
    {#if launcherOpen === 'sandboxes'}
      <div class="cnp-launcher-pop">
        <SandboxQuickActions
          {workspaceSlug}
          onPickSandbox={(id) => onPickSandbox?.(id)}
          onNewSandbox={() => onNewSandbox?.()}
          onClose={closeLauncher}
        />
      </div>
    {/if}
  </div>

  <!-- Schedule -->
  <div class="cnp-launcher-host">
    <button
      type="button"
      class="cnp-chip"
      class:cnp-chip--on={launcherOpen === 'schedule'}
      onclick={() => toggleLauncher('schedule')}
      aria-haspopup="dialog"
      aria-expanded={launcherOpen === 'schedule'}
      aria-label="Schedule"
      title="Schedule"
    >
      <Clock size={11} aria-hidden="true" />
      <span class="cnp-chip__label">Schedule</span>
    </button>
    {#if launcherOpen === 'schedule'}
      <div class="cnp-launcher-pop">
        <ScheduleQuickActions
          {workspaceSlug}
          onScheduleConversation={() => onScheduleConversation?.()}
          onPickSpec={(slug) => onPickSpec?.(slug)}
          onClose={closeLauncher}
        />
      </div>
    {/if}
  </div>

  <!-- Spacer -->
  <span class="cnp-chips__spacer"></span>

  <!-- Mic -->
  <button
    type="button"
    class="cnp-chip cnp-chip--icon"
    onclick={onMicClick}
    aria-label="Voice input"
    title="Voice input"
  >
    <Mic size={12} aria-hidden="true" />
  </button>

  <!-- Attach / plus -->
  <button
    type="button"
    class="cnp-chip cnp-chip--icon"
    onclick={onAttach}
    aria-label="Attach file"
    title="Attach"
  >
    <Plus size={12} aria-hidden="true" />
  </button>
</div>

<style>
  .cnp-chips {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px 8px;
    flex-wrap: wrap;
  }

  .cnp-chips__spacer {
    flex: 1;
  }

  .cnp-cwd-host {
    position: relative;
    display: inline-flex;
  }

  .cnp-cwd-pop {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 0;
    z-index: 50;
  }

  .cnp-launcher-host {
    position: relative;
    display: inline-flex;
  }

  .cnp-launcher-pop {
    position: absolute;
    bottom: calc(100% + 6px);
    left: 0;
    z-index: 50;
  }

  .cnp-chip {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 3px 8px;
    height: 22px;
    border: 1px solid var(--border, rgba(255, 255, 255, 0.10));
    background: color-mix(in oklch, var(--fg) 4%, transparent);
    border-radius: 999px;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    transition: background 80ms ease-out, color 80ms ease-out, border-color 80ms ease-out;
  }

  .cnp-chip:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    color: var(--fg);
    border-color: color-mix(in oklch, var(--fg) 18%, transparent);
  }

  .cnp-chip--on {
    color: var(--cnp-accent, oklch(0.72 0.18 145));
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 40%, transparent);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 12%, transparent);
  }

  .cnp-chip--icon {
    width: 22px;
    height: 22px;
    padding: 0;
    justify-content: center;
  }

  .cnp-chip__label {
    max-width: 220px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .cnp-chip__icon-action {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 16px;
    height: 16px;
    margin-left: 2px;
    border-radius: 999px;
    color: var(--fg-subtle);
    transition: background 80ms ease-out, color 80ms ease-out;
  }

  .cnp-chip__icon-action:hover {
    background: color-mix(in oklch, var(--fg) 14%, transparent);
    color: var(--fg);
  }
</style>
