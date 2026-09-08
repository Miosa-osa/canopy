<script lang="ts">
/**
 * AgentConversationPane — per-pane conversation surface.
 *
 * Replaces the global build composer with a self-contained conversation
 * that lives inside a Mosaic tile. Architecture:
 *
 *   ┌──────────────────────────────┐
 *   │ transcript (BlockStream)     │  ← when sessionId present, no embed
 *   │   or                         │
 *   │ EmbeddedRuntime              │  ← when pane.config.embeddedRuntime set
 *   │   or                         │
 *   │ ConversationIntroCard        │  ← empty state (with SlashCommands)
 *   ├──────────────────────────────┤
 *   │ ShellCommandHint (optional)  │
 *   ├──────────────────────────────┤
 *   │ Composer (reused, hideable)  │
 *   ├──────────────────────────────┤
 *   │ ComposerChips                │
 *   └──────────────────────────────┘
 *
 * Reuses primitives — does NOT re-implement @mention / agent picker /
 * runtime picker / blocks / slash command palette / xterm.
 *
 * Owns: input draft, agent vs shell mode, optional sessionId for the
 * transcript, optional embeddedRuntime config. The transcript itself
 * is a Canopy.Sessions.Session of kind="agent_conversation" — created
 * lazily on first submit.
 *
 * CSS prefix: acp-
 */

import type { CreateQueryOptions } from '@tanstack/svelte-query';
import { createMutation, createQuery, useQueryClient } from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import { blocksListQuery } from '$lib/api/queries/blocks.js';
import type { BuildCommand } from '$lib/api/queries/build-commands.js';
import { createDriveEntry } from '$lib/api/queries/drive.js';
import { createSession, sessionDetailQuery } from '$lib/api/queries/sessions.js';
import BlockStream from '$lib/design/patterns/blocks/BlockStream.svelte';
import type { Block } from '$lib/domain/blocks/types.js';
import type { Session, SessionDetail } from '$lib/domain/sessions/types.js';
import { mosaicLayout } from '$lib/stores/mosaic-layout.svelte.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import AgentStatusBar from './agent-conversation/AgentStatusBar.svelte';
import CompactionIndicator from './agent-conversation/CompactionIndicator.svelte';
import ConversationComposer from './agent-conversation/ConversationComposer.svelte';
import ConversationIntroCard from './agent-conversation/ConversationIntroCard.svelte';
import EmbeddedRuntime from './agent-conversation/EmbeddedRuntime.svelte';
import WrapUpSignal from './agent-conversation/WrapUpSignal.svelte';

/**
 * Embedded runtime descriptor — when set, the pane's transcript area
 * is replaced by a live runtime terminal (Claude Code / Codex / Gemini /
 * etc.) rendered via the existing TerminalSession primitive. Stored on
 * pane.config so it survives reloads via the mosaicLayout persistence.
 */
export interface EmbeddedRuntimeConfig {
  type: string;
  sessionId: string;
  /** ON = composer above the runtime; OFF = raw passthrough mode. */
  richInputOn: boolean;
  /** Per-runtime notification toggle (visual until backend wires up). */
  notificationsOn?: boolean;
}

interface Props {
  /** Existing session to attach to. When absent, the pane shows the
   *  intro card and creates a session on first submit. */
  sessionId?: string;
  workspaceSlug: string;
  /** Working directory shown in chips + intro card. */
  cwd?: string;
  /** Model identifier shown in the model chip. */
  model?: string;
  /** Runtime used when the pane creates a new agent conversation session. */
  runtimeType?: string;
  /** Pane id — used to write back the new sessionId to the layout
   *  store after the first submit, mirroring the terminal pane. */
  paneId?: string;
  tileId?: string;
  /** Optional embedded runtime config. When present, the transcript
   *  area renders <EmbeddedRuntime/> instead of <BlockStream/>. */
  embeddedRuntime?: EmbeddedRuntimeConfig;
}

let {
  sessionId: initialSessionId,
  workspaceSlug,
  cwd = '~',
  model = 'auto (cost-efficient)',
  runtimeType = 'claude-local',
  paneId,
  tileId,
  embeddedRuntime: initialEmbedded,
}: Props = $props();

// ── Local state ────────────────────────────────────────────────────────────

let sessionId = $state<string | null>(initialSessionId ?? null);
let draft = $state('');
let remoteControl = $state(false);
let createError = $state<string | null>(null);
let startingRuntime = $state(false);
let pendingRuntimeInput = $state<string | null>(null);

/** Embedded runtime — copied into local state so toggles re-render
 *  immediately. Persisted onto pane.config on every change. */
let embedded = $state<EmbeddedRuntimeConfig | null>(initialEmbedded ?? null);

/** Captured by EmbeddedRuntime via onSendInputReady — used to pipe
 *  raw keystrokes / batched prompts from the pane to the runtime. */
let runtimeSendInput = $state<((data: string) => void) | null>(null);

// ── Session detail + blocks (for CompactionIndicator + WrapUpSignal) ──────

const sessionDetailOptsStore = writable(
  sessionDetailQuery(sessionId ?? '') as CreateQueryOptions<SessionDetail>
);
$effect(() => {
  sessionDetailOptsStore.set(
    sessionDetailQuery(sessionId ?? '') as CreateQueryOptions<SessionDetail>
  );
});
const sessionDetailResult = createQuery<SessionDetail>(sessionDetailOptsStore);
const sessionData = $derived<Session | null>(
  sessionId ? (($sessionDetailResult.data as SessionDetail | undefined)?.session ?? null) : null
);

const blocksOptsStore = writable(
  blocksListQuery(sessionId ?? '', { limit: 50 }) as CreateQueryOptions<Block[]>
);
$effect(() => {
  blocksOptsStore.set(
    blocksListQuery(sessionId ?? '', { limit: 50 }) as CreateQueryOptions<Block[]>
  );
});
const blocksResult = createQuery<Block[]>(blocksOptsStore);
const latestBlocks = $derived<Block[]>(
  sessionId ? (($blocksResult.data as Block[] | undefined) ?? []) : []
);
const queryClient = useQueryClient();

/** Intro card hides as soon as we have a transcript or runtime. */
const showIntro = $derived(!sessionId && !embedded);

/** Persist any pane.config-relevant change back into the layout store. */
function persistConfig(): void {
  if (!paneId || !tileId) return;
  const tile = mosaicLayout.allTiles().find((t) => t.id === tileId);
  const pane = tile?.panes.find((p) => p.id === paneId);
  if (!pane) return;
  pane.config = {
    ...(pane.config ?? {}),
    sessionId: sessionId ?? undefined,
    cwd,
    model,
    embeddedRuntime: embedded ?? undefined,
  };
  if (sessionId) pane.ref = sessionId;
  mosaicLayout.save();
}

// ── Session creation ───────────────────────────────────────────────────────

const createConversation = createMutation<Session, Error, { prompt: string }>({
  mutationFn: async ({ prompt }) => {
    void prompt;
    // Conversations ARE Sessions — kind/runtime distinguishes them.
    return createSession({
      runtimeType,
      workspaceSlug,
      cwd: cwd || '~',
      prompt,
      kind: 'agent_conversation',
      interactive: false,
    });
  },
  onSuccess: (s) => {
    const id =
      (s as unknown as { sessionId?: string; id?: string }).sessionId ??
      (s as unknown as { id?: string }).id ??
      null;
    if (!id) {
      createError = 'Session created without an id';
      return;
    }
    sessionId = id;
    // Persist sessionId back onto the pane so reloading the layout
    // reattaches to the same conversation.
    persistConfig();
    void queryClient.invalidateQueries({ queryKey: ['agent-conversations'] });
  },
  onError: (err) => {
    createError = err instanceof Error ? err.message : 'Failed to start conversation';
  },
});

async function ensureConversationSession(
  prompt: string,
  selectedRuntime: string | null
): Promise<string> {
  if (sessionId) return sessionId;

  const session = await createSession({
    runtimeType: runtimeFromShell(prompt, selectedRuntime),
    workspaceSlug,
    cwd: cwd || '~',
    prompt,
    kind: 'agent_conversation',
    interactive: false,
  });
  const id =
    (session as unknown as { sessionId?: string; id?: string }).sessionId ??
    (session as unknown as { id?: string }).id ??
    null;
  if (!id) throw new Error('Conversation session created without an id');
  sessionId = id;
  persistConfig();
  await queryClient.invalidateQueries({ queryKey: ['agent-conversations'] });
  return id;
}

// ── Handlers ───────────────────────────────────────────────────────────────

function handleSubmit(
  prompt: string,
  mode: 'agent' | 'shell',
  agentSlug: string | null,
  runtime: string | null,
  mentions: string[]
): void {
  void agentSlug;
  void mentions;
  if (!prompt.trim()) return;

  if (prompt.trim().startsWith('/')) {
    void (async () => {
      const handled = await handleSlashSubmit(prompt);
      if (!handled) createError = `Unknown command: ${prompt.trim().split(/\s+/)[0]}`;
    })();
    return;
  }

  // When a runtime is embedded + Rich Input is ON, treat submit as a
  // batched send to the runtime's stdin via the existing PtyBridge
  // transport (TerminalSession#sendInput).
  if (embedded) {
    const payload = `${prompt}\n`;
    if (runtimeSendInput) {
      runtimeSendInput(payload);
    } else {
      pendingRuntimeInput = `${pendingRuntimeInput ?? ''}${payload}`;
    }
    return;
  }

  if (mode === 'shell') {
    void startRuntimeForShell(prompt, runtime);
    return;
  }

  if (!sessionId) {
    void startRuntimeForShell(prompt, runtime);
    return;
  }
  // Subsequent submits route through the existing chat pipeline —
  // BlockStream listens to the same session via TanStack Query.
}

function runtimeFromShell(prompt: string, selectedRuntime: string | null): string {
  const firstToken = prompt.trim().split(/\s+/)[0]?.toLowerCase() ?? '';
  if (firstToken === 'claude' || firstToken === 'claude-code') return 'claude-local';
  if (firstToken === 'codex') return selectedRuntime === 'codex' ? 'codex' : 'codex-local';
  if (firstToken === 'gemini') return 'gemini-local';
  if (firstToken === 'opencode') return 'opencode-local';
  if (firstToken === 'aider') return 'aider-local';
  if (selectedRuntime?.endsWith('-local')) return selectedRuntime;
  if (selectedRuntime === 'claude-code') return 'claude-local';
  if (selectedRuntime === 'codex') return 'codex';
  if (selectedRuntime === 'gemini') return 'gemini-local';
  if (selectedRuntime === 'aider') return 'aider';
  return runtimeType;
}

function shouldInjectShellPrompt(prompt: string): boolean {
  const firstToken = prompt.trim().split(/\s+/)[0]?.toLowerCase() ?? '';
  return !['claude', 'claude-code', 'codex', 'gemini', 'opencode', 'aider'].includes(firstToken);
}

async function startRuntimeForShell(prompt: string, selectedRuntime: string | null): Promise<void> {
  if (startingRuntime) return;
  const trimmed = prompt.trim();
  const nextRuntimeType = runtimeFromShell(trimmed, selectedRuntime);
  startingRuntime = true;
  createError = null;
  try {
    const conversationId = await ensureConversationSession(trimmed, selectedRuntime);
    const session = await createSession({
      runtimeType: nextRuntimeType,
      workspaceSlug,
      cwd: cwd || '~',
      prompt: '',
      kind: 'terminal',
      interactive: true,
    });
    const id =
      (session as unknown as { sessionId?: string; id?: string }).sessionId ??
      (session as unknown as { id?: string }).id ??
      null;
    if (!id) throw new Error('Runtime session created without an id');
    embedded = {
      type: nextRuntimeType,
      sessionId: id,
      richInputOn: true,
      notificationsOn: false,
    };
    pendingRuntimeInput = shouldInjectShellPrompt(trimmed) ? `${trimmed}\n` : null;
    sessionId = conversationId;
    persistConfig();
  } catch (err) {
    createError = err instanceof Error ? err.message : 'Failed to start runtime';
  } finally {
    startingRuntime = false;
  }
}

function handleCwdOpen(): void {
  // No-op until the tauri shell-open bridge ships; chip is harmless to
  // click in the meantime.
}

function handleCwdChange(newCwd: string): void {
  cwd = newCwd || '~';
  persistConfig();
  // Backend gap: Canopy.Runtimes.set_cwd does not exist yet. As a
  // fallback, when a runtime is embedded send `cd <path>` over PTY.
  // See wiring/embedded-runtime-wiring.md → "Backend gaps".
  if (embedded && runtimeSendInput && newCwd) {
    runtimeSendInput(`cd ${newCwd}\n`);
  }
}

function handleRichInputToggle(): void {
  if (!embedded) return;
  embedded = { ...embedded, richInputOn: !embedded.richInputOn };
  persistConfig();
}

function handlePickFile(path: string): void {
  if (embedded && !embedded.richInputOn && runtimeSendInput) {
    // Rich Input OFF + runtime active → pipe a `cat <path>` so the
    // picked file lands in the runtime's scrollback.
    runtimeSendInput(`cat ${path}\n`);
    return;
  }
  // Rich Input ON → append the path to the draft. The internal
  // Composer is contenteditable, so we stage it textually.
  draft = draft ? `${draft} ${path}` : path;
}

function handleNotificationsToggle(): void {
  if (!embedded) return;
  embedded = {
    ...embedded,
    notificationsOn: !(embedded.notificationsOn ?? false),
  };
  persistConfig();
  // Backend gap: no runtime notification setter today.
}

function handleEndRuntime(): void {
  embedded = null;
  runtimeSendInput = null;
  persistConfig();
}

function commandTail(name: string, prompt: string): string {
  return prompt.slice(name.length).trim();
}

function slugify(value: string, fallback: string): string {
  const slug = value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 64);
  return slug || fallback;
}

async function createPromptEntry(kind: 'prompt' | 'rule', text: string): Promise<void> {
  const title =
    text.split('\n')[0]?.trim().slice(0, 80) || (kind === 'prompt' ? 'New prompt' : 'New rule');
  const slug = `${kind}-${slugify(title, Date.now().toString(36))}`;
  await createDriveEntry({
    slug,
    name: title,
    kind,
    scope: 'personal',
    body: kind === 'prompt' ? { body: text } : { body: text, applies_to: [] },
    tags: ['build'],
  });
  toasts.success(`${kind === 'prompt' ? 'Prompt' : 'Rule'} saved to Drive`);
}

function handleSlashCommand(command: BuildCommand): boolean {
  const name = command.name;
  if (command.source === 'runtime') {
    draft = name.startsWith('/') ? `${name.slice(1)} ` : `${name} `;
    return true;
  }
  if (
    command.source === 'drive_prompt' ||
    command.source === 'template' ||
    command.source === 'skill'
  ) {
    draft = `${name} `;
    return false;
  }

  switch (name) {
    case '/agent':
      sessionId = null;
      embedded = null;
      runtimeSendInput = null;
      draft = '';
      persistConfig();
      toasts.info('Ready for a new agent prompt');
      return true;
    case '/plan':
      draft = 'Make a concise implementation plan for: ';
      return true;
    case '/review':
      void goto('/review');
      return true;
    case '/open-file':
      void goto('/files');
      return true;
    case '/conversations':
      void goto('/sessions');
      return true;
    case '/prompts':
      void goto('/drive');
      return true;
    case '/add-prompt':
      draft = '/add-prompt ';
      return false;
    case '/add-rule':
      draft = '/add-rule ';
      return false;
    case '/add-mcp':
      void goto('/settings/build');
      return true;
    case '/create-environment':
      void goto('/sandboxes-ng');
      return true;
    default:
      return false;
  }
}

async function handleSlashSubmit(prompt: string): Promise<boolean> {
  const trimmed = prompt.trim();
  if (trimmed.startsWith('/add-prompt')) {
    const body = commandTail('/add-prompt', trimmed);
    if (!body) {
      createError = 'Add prompt needs text after /add-prompt';
      return true;
    }
    try {
      await createPromptEntry('prompt', body);
      createError = null;
    } catch (err) {
      createError = err instanceof Error ? err.message : 'Failed to save prompt';
    }
    return true;
  }
  if (trimmed.startsWith('/add-rule')) {
    const body = commandTail('/add-rule', trimmed);
    if (!body) {
      createError = 'Add rule needs text after /add-rule';
      return true;
    }
    try {
      await createPromptEntry('rule', body);
      createError = null;
    } catch (err) {
      createError = err instanceof Error ? err.message : 'Failed to save rule';
    }
    return true;
  }
  if (trimmed.startsWith('/plan')) {
    void startRuntimeForShell(
      `Create an implementation plan. ${commandTail('/plan', trimmed)}`,
      null
    );
    return true;
  }
  if (trimmed === '/agent') {
    sessionId = null;
    embedded = null;
    runtimeSendInput = null;
    persistConfig();
    toasts.info('Ready for a new agent prompt');
    return true;
  }
  if (trimmed === '/review') {
    void goto('/review');
    return true;
  }
  if (trimmed === '/open-file') {
    void goto('/files');
    return true;
  }
  if (trimmed === '/conversations') {
    void goto('/sessions');
    return true;
  }
  if (trimmed === '/prompts') {
    void goto('/drive');
    return true;
  }
  if (trimmed === '/add-mcp') {
    void goto('/settings/build');
    return true;
  }
  if (trimmed === '/create-environment') {
    void goto('/sandboxes-ng');
    return true;
  }
  return false;
}
</script>

<div class="acp-root" data-session-id={sessionId ?? ''}>
  <!-- Compaction indicator — only when session is active and token data available -->
  {#if sessionId && sessionData}
    <CompactionIndicator session={sessionData} />
  {/if}

  <!-- Transcript / runtime / empty state -->
  <div class="acp-stream" role="region" aria-label="Conversation transcript">
    {#if embedded}
      <EmbeddedRuntime
        runtimeType={embedded.type}
        sessionId={embedded.sessionId}
        onSendInputReady={(send) => {
          runtimeSendInput = send;
          if (pendingRuntimeInput) {
            send(pendingRuntimeInput);
            pendingRuntimeInput = null;
          }
        }}
        onEnd={handleEndRuntime}
      />
    {:else if sessionId}
      <BlockStream sessionId={sessionId} />
    {:else if showIntro}
      <ConversationIntroCard {cwd} />
    {/if}

    {#if createError}
      <p class="acp-error" role="alert">{createError}</p>
    {/if}
  </div>

  <!-- Wrap-up signal — slides up when agent reaches a natural stopping point -->
  {#if sessionId}
    <WrapUpSignal
      blocks={latestBlocks}
      onNewTask={() => { sessionId = null; draft = ''; }}
      onReview={() => { /* caller can open diff pane */ }}
      onDismiss={() => { /* handled inside WrapUpSignal */ }}
    />
  {/if}

  <!-- Agent status bar — hidden when idle, visible when agent is active -->
  {#if sessionId}
    <AgentStatusBar sessionId={sessionId} />
  {/if}

  <!-- Composer (always-on; textarea hides in passthrough mode) -->
  <ConversationComposer
    {cwd}
    {model}
    {remoteControl}
    {workspaceSlug}
    embeddedRuntimeType={embedded?.type ?? null}
    richInputOn={embedded?.richInputOn ?? true}
    notificationsOn={embedded?.notificationsOn ?? false}
    bind:draft
    onSubmit={handleSubmit}
    onCwdClick={() => {}}
    onCwdOpen={handleCwdOpen}
    onCwdChange={handleCwdChange}
    onModelClick={() => {}}
    onRemoteToggle={() => (remoteControl = !remoteControl)}
    onMicClick={() => {}}
    onAttach={() => {}}
    onRichInputToggle={handleRichInputToggle}
    onPickFile={handlePickFile}
    onNotificationsToggle={handleNotificationsToggle}
    onSlashCommand={handleSlashCommand}
  />
</div>

<style>
  .acp-root {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    flex: 1;
    background: var(--bg);
  }

  .acp-stream {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    overscroll-behavior: contain;
    display: flex;
    flex-direction: column;
    position: relative;
  }

  /* When the slash palette renders here it shouldn't claim full height —
     anchor it near the top with comfortable spacing. */
  .acp-slash-host {
    position: relative;
    padding: 24px 24px 0;
  }

  .acp-error {
    margin: 12px 24px;
    padding: 8px 12px;
    border-radius: var(--radius-sm, 4px);
    background: color-mix(in oklch, var(--signal-error, oklch(0.55 0.22 25)) 12%, transparent);
    color: var(--signal-error, oklch(0.55 0.22 25));
    font-family: var(--font-sans);
    font-size: 12px;
  }
</style>
