<script lang="ts">
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Activity, AlertCircle, CheckCircle2, Play, RefreshCw } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import {
  runWorkspaceEngineCommandMutation,
  workspaceEngineCommandsQuery,
  workspaceEngineHealthQuery,
} from '$lib/api/queries/engine.js';
import type {
  WorkspaceEngineCommand,
  WorkspaceEngineCommandsResponse,
  WorkspaceEngineHealth,
  WorkspaceEngineRunBody,
  WorkspaceEngineRunResult,
} from '$lib/domain/engine/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

interface Props {
  workspaceSlug: string;
}

let { workspaceSlug }: Props = $props();

const queryClient = useQueryClient();

const healthOptsStore = writable(
  untrack(
    () => workspaceEngineHealthQuery(workspaceSlug) as CreateQueryOptions<WorkspaceEngineHealth>
  )
);

$effect(() => {
  healthOptsStore.set(
    workspaceEngineHealthQuery(workspaceSlug) as CreateQueryOptions<WorkspaceEngineHealth>
  );
});

const commandsOptsStore = writable(
  untrack(
    () =>
      workspaceEngineCommandsQuery(
        workspaceSlug
      ) as CreateQueryOptions<WorkspaceEngineCommandsResponse>
  )
);

$effect(() => {
  commandsOptsStore.set(
    workspaceEngineCommandsQuery(
      workspaceSlug
    ) as CreateQueryOptions<WorkspaceEngineCommandsResponse>
  );
});

const healthQ = createQuery<WorkspaceEngineHealth>(healthOptsStore);
const commandsQ = createQuery<WorkspaceEngineCommandsResponse>(commandsOptsStore);

const runOptsStore = writable(
  untrack(
    () =>
      runWorkspaceEngineCommandMutation(workspaceSlug) as CreateMutationOptions<
        WorkspaceEngineRunResult,
        Error,
        WorkspaceEngineRunBody
      >
  )
);

$effect(() => {
  runOptsStore.set(
    runWorkspaceEngineCommandMutation(workspaceSlug) as CreateMutationOptions<
      WorkspaceEngineRunResult,
      Error,
      WorkspaceEngineRunBody
    >
  );
});

const runMut = createMutation<WorkspaceEngineRunResult, Error, WorkspaceEngineRunBody>(
  runOptsStore
);

let selectedCommandName = $state('');
let argsText = $state('');
let timeoutMs = $state(60_000);
let runResult = $state<WorkspaceEngineRunResult | null>(null);

const health = $derived(($healthQ.data ?? null) as WorkspaceEngineHealth | null);
const commands = $derived(($commandsQ.data?.commands ?? []) as WorkspaceEngineCommand[]);
const selectedCommand = $derived(
  commands.find((command) => command.name === selectedCommandName) ?? commands[0] ?? null
);
const isRunDisabled = $derived(
  !health?.available || !selectedCommand || $runMut.isPending || timeoutMs <= 0
);

$effect(() => {
  if (!selectedCommandName && commands.length > 0) {
    selectedCommandName = commands[0].name;
  }
});

function parseArgs(text: string): string[] {
  return text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
}

async function refresh(): Promise<void> {
  await Promise.all([
    queryClient.invalidateQueries({ queryKey: ['workspaces', workspaceSlug, 'engine', 'health'] }),
    queryClient.invalidateQueries({
      queryKey: ['workspaces', workspaceSlug, 'engine', 'commands'],
    }),
  ]);
}

async function runCommand(): Promise<void> {
  if (!selectedCommand || isRunDisabled) return;

  try {
    runResult = await $runMut.mutateAsync({
      command: selectedCommand.name,
      args: parseArgs(argsText),
      timeoutMs,
    });
    toasts.success('Engine command finished');
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Engine command failed';
    toasts.error(message);
  }
}
</script>

<div class="wet-panel">
  <section class="wet-section wet-section--status">
    <div class="wet-section-head">
      <div>
        <h2 class="wet-title">OptimalEngine</h2>
        <p class="wet-subtitle">Workspace-local execution from <span>.canopy/engine.yaml</span></p>
      </div>
      <button class="wet-icon-btn" type="button" title="Refresh" aria-label="Refresh engine state" onclick={() => void refresh()}>
        <RefreshCw size={15} />
      </button>
    </div>

    {#if $healthQ.isLoading}
      <div class="wet-skeleton"></div>
    {:else if health}
      <div class="wet-status-grid">
        <div class="wet-status-item">
          <span class:wet-ok={health.engineExists} class:wet-bad={!health.engineExists}>
            {#if health.engineExists}<CheckCircle2 size={14} />{:else}<AlertCircle size={14} />{/if}
          </span>
          <div>
            <strong>Engine</strong>
            <small>{health.enginePath}</small>
          </div>
        </div>
        <div class="wet-status-item">
          <span class:wet-ok={health.mixProject} class:wet-bad={!health.mixProject}>
            {#if health.mixProject}<CheckCircle2 size={14} />{:else}<AlertCircle size={14} />{/if}
          </span>
          <div>
            <strong>Mix project</strong>
            <small>engine/mix.exs</small>
          </div>
        </div>
        <div class="wet-status-item">
          <span class:wet-ok={health.manifestExists} class:wet-bad={!health.manifestExists}>
            {#if health.manifestExists}<CheckCircle2 size={14} />{:else}<AlertCircle size={14} />{/if}
          </span>
          <div>
            <strong>Manifest</strong>
            <small>{health.manifestPath}</small>
          </div>
        </div>
        <div class="wet-status-item">
          <span class:wet-ok={health.available} class:wet-bad={!health.available}>
            <Activity size={14} />
          </span>
          <div>
            <strong>{health.available ? 'Ready' : 'Not ready'}</strong>
            <small>{health.commandsCount} command{health.commandsCount === 1 ? '' : 's'}</small>
          </div>
        </div>
      </div>
    {:else}
      <p class="wet-muted">Engine health could not be loaded.</p>
    {/if}
  </section>

  <section class="wet-section">
    <div class="wet-section-head">
      <div>
        <h2 class="wet-title">Commands</h2>
        <p class="wet-subtitle">Only manifest-allowlisted optimal.* tasks can run.</p>
      </div>
    </div>

    {#if $commandsQ.isError}
      <div class="wet-empty">
        Create <span>.canopy/engine.yaml</span> and an <span>engine/mix.exs</span> project in this workspace.
      </div>
    {:else if commands.length === 0}
      <div class="wet-empty">No engine commands found.</div>
    {:else}
      <div class="wet-command-layout">
        <div class="wet-command-list" aria-label="Engine commands">
          {#each commands as command (command.name)}
            <button
              class="wet-command"
              class:wet-command--active={selectedCommandName === command.name}
              type="button"
              aria-pressed={selectedCommandName === command.name}
              onclick={() => { selectedCommandName = command.name; }}
            >
              <strong>{command.name}</strong>
              <small>{command.task}</small>
            </button>
          {/each}
        </div>

        <div class="wet-runner">
          {#if selectedCommand}
            <div class="wet-runner-head">
              <div>
                <h3>{selectedCommand.name}</h3>
                <p>{selectedCommand.description ?? selectedCommand.task}</p>
              </div>
              <button class="wet-run-btn" type="button" disabled={isRunDisabled} onclick={() => void runCommand()}>
                <Play size={14} />
                <span>{$runMut.isPending ? 'Running' : 'Run'}</span>
              </button>
            </div>

            {#if selectedCommand.args.length > 0}
              <div class="wet-manifest-args">
                <span>Manifest args</span>
                <code>{selectedCommand.args.join(' ')}</code>
              </div>
            {/if}

            <label class="wet-label" for="wet-args">Runtime args</label>
            <textarea
              id="wet-args"
              class="wet-textarea"
              bind:value={argsText}
              rows="4"
              placeholder="One argument per line"
            ></textarea>

            <label class="wet-label" for="wet-timeout">Timeout ms</label>
            <input id="wet-timeout" class="wet-input" type="number" min="1000" max="300000" step="1000" bind:value={timeoutMs} />
          {/if}
        </div>
      </div>
    {/if}
  </section>

  {#if runResult}
    <section class="wet-section">
      <div class="wet-section-head">
        <div>
          <h2 class="wet-title">Last Run</h2>
          <p class="wet-subtitle">{runResult.task} exited {runResult.exitCode} in {runResult.durationMs}ms</p>
        </div>
      </div>
      <dl class="wet-result-meta">
        <div><dt>Cwd</dt><dd>{runResult.cwd}</dd></div>
        <div><dt>Args</dt><dd>{runResult.args.join(' ')}</dd></div>
      </dl>
      <pre class="wet-output">{runResult.stdout || runResult.stderr || '(no output)'}</pre>
    </section>
  {/if}
</div>

<style>
  .wet-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
  }

  .wet-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .wet-section-head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .wet-title {
    margin: 0;
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .wet-subtitle {
    margin: var(--space-1) 0 0;
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .wet-subtitle span,
  .wet-empty span {
    font-family: var(--font-mono);
    color: var(--fg-muted);
  }

  .wet-icon-btn,
  .wet-run-btn,
  .wet-command {
    border: 1px solid var(--border);
    background: var(--bg-subtle);
    color: var(--fg-muted);
    cursor: pointer;
  }

  .wet-icon-btn {
    width: 30px;
    height: 30px;
    border-radius: var(--radius-sm);
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }

  .wet-icon-btn:hover,
  .wet-run-btn:hover:not(:disabled),
  .wet-command:hover {
    border-color: var(--border-strong);
    color: var(--fg);
  }

  .wet-status-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: var(--space-3);
  }

  .wet-status-item {
    min-width: 0;
    display: flex;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg-subtle);
  }

  .wet-status-item span {
    display: inline-flex;
    margin-top: 2px;
  }

  .wet-status-item strong {
    display: block;
    color: var(--fg);
    font-size: var(--text-sm);
  }

  .wet-status-item small {
    display: block;
    color: var(--fg-subtle);
    font-family: var(--font-mono);
    font-size: 10px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wet-ok { color: var(--success); }
  .wet-bad { color: var(--destructive, oklch(0.65 0.22 25)); }

  .wet-command-layout {
    display: grid;
    grid-template-columns: minmax(180px, 240px) minmax(0, 1fr);
    gap: var(--space-4);
  }

  .wet-command-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .wet-command {
    text-align: left;
    border-radius: var(--radius-sm);
    padding: var(--space-3);
  }

  .wet-command--active {
    border-color: var(--cnp-accent);
    color: var(--fg);
  }

  .wet-command strong,
  .wet-command small {
    display: block;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wet-command strong {
    font-size: var(--text-sm);
  }

  .wet-command small {
    margin-top: 3px;
    color: var(--fg-subtle);
    font-family: var(--font-mono);
    font-size: 10px;
  }

  .wet-runner {
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg-subtle);
  }

  .wet-runner-head {
    display: flex;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .wet-runner h3,
  .wet-runner p {
    margin: 0;
  }

  .wet-runner h3 {
    color: var(--fg);
    font-size: var(--text-base);
  }

  .wet-runner p {
    margin-top: var(--space-1);
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }

  .wet-run-btn {
    height: 32px;
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    border-radius: var(--radius-sm);
    padding: 0 var(--space-3);
    flex-shrink: 0;
  }

  .wet-run-btn:disabled {
    opacity: 0.55;
    cursor: not-allowed;
  }

  .wet-manifest-args {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    color: var(--fg-subtle);
    font-size: var(--text-xs);
  }

  .wet-manifest-args code {
    color: var(--fg-muted);
    font-family: var(--font-mono);
  }

  .wet-label {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .wet-textarea,
  .wet-input {
    width: 100%;
    box-sizing: border-box;
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    background: var(--bg);
    color: var(--fg);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .wet-textarea {
    resize: vertical;
    min-height: 88px;
    padding: var(--space-2);
  }

  .wet-input {
    max-width: 160px;
    height: 30px;
    padding: 0 var(--space-2);
  }

  .wet-result-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    margin: 0;
  }

  .wet-result-meta div {
    display: grid;
    grid-template-columns: 56px minmax(0, 1fr);
    gap: var(--space-2);
  }

  .wet-result-meta dt {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    text-transform: uppercase;
  }

  .wet-result-meta dd {
    margin: 0;
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wet-output {
    margin: 0;
    min-height: 160px;
    max-height: 360px;
    overflow: auto;
    padding: var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg);
    color: var(--fg-muted);
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.5;
    white-space: pre-wrap;
  }

  .wet-empty,
  .wet-muted,
  .wet-skeleton {
    padding: var(--space-4);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--bg-subtle);
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }

  .wet-skeleton {
    height: 84px;
    animation: wet-pulse 1.4s ease-in-out infinite;
  }

  @keyframes wet-pulse {
    0%, 100% { opacity: 0.35; }
    50% { opacity: 0.7; }
  }

  @media (max-width: 760px) {
    .wet-status-grid,
    .wet-command-layout {
      grid-template-columns: 1fr;
    }
  }
</style>
