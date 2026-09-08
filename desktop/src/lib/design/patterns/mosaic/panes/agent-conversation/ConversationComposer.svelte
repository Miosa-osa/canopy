<script lang="ts">
/**
 * ConversationComposer — pane-scoped wrapper around the existing
 * <Composer/> primitive.
 *
 * Adds:
 *   - the ChipRow underneath (cwd / model / remote / rich-input /
 *     files / runtime-notifications / mic / +)
 *   - a ShellCommandHint above the input when the draft looks shell-y
 *   - ⌘| to override the agent/shell decision
 *
 * When `embeddedRuntime` is set + `richInputOn` is false, the inner
 * <Composer/> hides — the embedded terminal becomes the focus and
 * keystrokes flow to the runtime via PtyBridge (parent owns the
 * actual stdin write; this component just hides the textarea and
 * keeps the chip strip visible).
 *
 * Keeps the inner @mention + agent picker + runtime picker by reusing
 * Composer.svelte verbatim — we just relay submit upward.
 *
 * CSS prefix: cnv-cmp-
 */

import type { BuildCommand } from '$lib/api/queries/build-commands.js';
import SlashCommands from '$lib/design/patterns/build/SlashCommands.svelte';
import Composer from '$lib/design/patterns/Composer.svelte';
import ComposerChips from './ComposerChips.svelte';
import ShellCommandHint from './ShellCommandHint.svelte';
import { looksLikeShellCommand } from './shell-detect.js';

interface Props {
  cwd: string;
  model: string;
  remoteControl?: boolean;
  /** Two-way: parent observes the draft so the IntroCard can swap to
   *  SlashCommands when the user types `/`. */
  draft?: string;
  placeholder?: string;

  /** Workspace slug — required for cwd picker + file explorer chips. */
  workspaceSlug?: string;

  /** Set when an embedded runtime is bound to the pane. */
  embeddedRuntimeType?: string | null;
  /** ON = composer textarea visible. OFF = hide and let runtime own input. */
  richInputOn?: boolean;
  /** Per-runtime notification preference (visual only until backend lands). */
  notificationsOn?: boolean;

  onSubmit?: (
    prompt: string,
    mode: 'agent' | 'shell',
    agentSlug: string | null,
    runtime: string | null,
    mentions: string[]
  ) => void;
  onCwdClick?: () => void;
  onCwdOpen?: () => void;
  onCwdChange?: (newCwd: string) => void;
  onModelClick?: () => void;
  onRemoteToggle?: () => void;
  onMicClick?: () => void;
  onAttach?: () => void;
  onRichInputToggle?: () => void;
  onPickFile?: (path: string) => void;
  onNotificationsToggle?: () => void;
  onSlashCommand?: (command: BuildCommand) => boolean | void;
}

let {
  cwd,
  model,
  remoteControl = false,
  draft = $bindable(''),
  placeholder = 'Ask, build, or run a shell command…',
  workspaceSlug,
  embeddedRuntimeType = null,
  richInputOn = true,
  notificationsOn = false,
  onSubmit,
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
  onSlashCommand,
}: Props = $props();

/** Heuristic detection — recomputed on every keystroke (cheap regex). */
const detectedShell = $derived(looksLikeShellCommand(draft));

/** Manual override — flips between treating shell-like input as a
 *  shell command vs. an agent prompt. Reset whenever the draft empties. */
let overridden = $state(false);

$effect(() => {
  if (draft.length === 0) overridden = false;
});

/** Effective send mode — what actually happens on ⌘↵. */
const sendMode = $derived<'agent' | 'shell'>(detectedShell && !overridden ? 'shell' : 'agent');

/** When richInputOn is false AND a runtime is embedded, hide the inner
 *  composer so the runtime owns the input surface. Chips stay visible. */
const composerVisible = $derived<boolean>(!embeddedRuntimeType || richInputOn);
const slashOpen = $derived(draft.startsWith('/'));

function handleSubmit(
  prompt: string,
  agentSlug: string | null,
  runtime: string | null,
  mentions?: string[]
): void {
  onSubmit?.(prompt, sendMode, agentSlug, runtime, mentions ?? []);
  draft = '';
  overridden = false;
}

function handleSlashPick(command: string, item?: BuildCommand): void {
  if (item && onSlashCommand?.(item) === true) {
    draft = '';
    return;
  }
  draft = command;
}

/** ⌘| toggles agent-prompt vs. shell-execute mode. */
function handleKeydown(e: KeyboardEvent): void {
  const meta = e.metaKey || e.ctrlKey;
  if (meta && e.key === '|') {
    e.preventDefault();
    overridden = !overridden;
  }
}

let wrapperEl: HTMLDivElement | undefined = $state();

function handleInput(e: Event): void {
  const target = e.target as HTMLElement | null;
  if (!target) return;
  if (target.isContentEditable) {
    draft = target.innerText.replace(/​/g, '');
  } else if (target instanceof HTMLTextAreaElement || target instanceof HTMLInputElement) {
    draft = target.value;
  }
}
</script>

<div
  class="cnv-cmp"
  bind:this={wrapperEl}
  oninput={handleInput}
  onkeydown={handleKeydown}
  role="group"
  aria-label="Conversation composer"
>
  {#if composerVisible}
    <ShellCommandHint
      visible={detectedShell}
      overridden={overridden}
      onToggle={() => (overridden = !overridden)}
    />

    {#if slashOpen}
      <SlashCommands query={draft.slice(1)} onpick={handleSlashPick} />
    {/if}

    <Composer {placeholder} bind:value={draft} onSubmit={handleSubmit} class="cnv-cmp__inner" />
  {/if}

  <ComposerChips
    {cwd}
    {model}
    {remoteControl}
    {workspaceSlug}
    {embeddedRuntimeType}
    {richInputOn}
    {notificationsOn}
    {onCwdClick}
    {onCwdOpen}
    {onCwdChange}
    {onModelClick}
    {onRemoteToggle}
    {onMicClick}
    {onAttach}
    {onRichInputToggle}
    {onPickFile}
    {onNotificationsToggle}
  />
</div>

<style>
  .cnv-cmp {
    position: relative;
    display: flex;
    flex-direction: column;
    border-top: 1px solid var(--border, rgba(255, 255, 255, 0.08));
    background: var(--bg-elev, var(--bg));
  }

  /* Strip the inner Composer's outer rounding — it's nested inside the
     pane border now and doesn't need its own pill shell. */
  :global(.cnv-cmp .cnv-cmp__inner) {
    border-radius: 0;
  }
</style>
