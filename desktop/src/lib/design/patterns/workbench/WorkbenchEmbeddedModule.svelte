<script lang="ts">
  import { onMount } from 'svelte';
  import {
    Bot,
    CheckCircle2,
    Clock3,
    Cpu,
    FileText,
    Folder,
    GitPullRequest,
    ListChecks,
    Play,
    Terminal,
  } from 'lucide-svelte';
  import { goto } from '$app/navigation';
  import { listAgents } from '$lib/api/queries/agents.js';
  import { listRuntimes } from '$lib/api/queries/runtimes.js';
  import { listSandboxes } from '$lib/api/queries/sandboxes.js';
  import { listSessions } from '$lib/api/queries/sessions.js';
  import { listSkills } from '$lib/api/queries/skills.js';
  import { listTasks } from '$lib/api/queries/tasks.js';
  import { listWorkspaces } from '$lib/api/queries/workspaces.js';

  interface Props {
    title: string;
    subtitle: string;
    route?: string;
    onAddTerminal: () => void;
    onAddAgent: () => void;
    onAddGit: () => void;
    onAddFiles: () => void;
    onAddMission: () => void;
  }

  let {
    title,
    subtitle,
    route,
    onAddTerminal,
    onAddAgent,
    onAddGit,
    onAddFiles,
    onAddMission,
  }: Props = $props();

  let loading = $state(false);
  let error = $state('');
  let rows = $state<Array<{ label: string; meta: string; tone?: 'good' | 'warn' | 'muted' }>>([]);

  const Icon = $derived(iconFor(route));
  const primaryAction = $derived(actionFor(route));

  onMount(() => {
    void load();
  });

  async function load(): Promise<void> {
    loading = true;
    error = '';
    try {
      if (route === '/sessions') {
        const sessions = await listSessions({ limit: 6 });
        rows = sessions.map((session) => ({
          label: session.prompt || session.cwd || session.id.slice(0, 8),
          meta: `${session.status} / ${session.runtimeType}`,
          tone: session.status === 'running' ? 'good' : session.status === 'error' ? 'warn' : 'muted',
        }));
      } else if (route === '/agents' || route === '/agent-control') {
        const agents = await listAgents({ hired: true });
        rows = agents.slice(0, 6).map((agent) => ({
          label: agent.name,
          meta: `${agent.category}${agent.defaultRuntime ? ` / ${agent.defaultRuntime}` : ''}`,
          tone: agent.hired ? 'good' : 'muted',
        }));
      } else if (route === '/tasks' || route === '/build' || route === '/review') {
        const tasks = await listTasks(route === '/tasks' ? undefined : { status: 'in_progress' });
        rows = tasks.slice(0, 6).map((task) => ({
          label: `${task.shortId} ${task.title}`,
          meta: `${task.status}${task.assigneeId ? ` / ${task.assigneeId}` : ''}`,
          tone: task.status === 'in_progress' ? 'good' : task.status === 'todo' ? 'warn' : 'muted',
        }));
      } else if (route === '/runtimes') {
        const runtimes = await listRuntimes();
        rows = runtimes.slice(0, 6).map((runtime) => ({
          label: runtime.name || runtime.type,
          meta: runtime.status,
          tone: runtime.status === 'installed' ? 'good' : runtime.status === 'not_installed' ? 'warn' : 'muted',
        }));
      } else if (route === '/workspaces') {
        const workspaces = await listWorkspaces();
        rows = workspaces.slice(0, 6).map((workspace) => ({
          label: workspace.name || workspace.slug,
          meta: workspace.rootPath,
          tone: workspace.deletedAt ? 'warn' : 'good',
        }));
      } else if (route === '/skills') {
        const skills = await listSkills();
        rows = skills.slice(0, 6).map((skill) => ({
          label: skill.name || skill.slug,
          meta: `${skill.source}${skill.enabled ? ' / enabled' : ' / disabled'}`,
          tone: skill.enabled ? 'good' : 'muted',
        }));
      } else if (route === '/sandboxes') {
        const response = await listSandboxes();
        rows = response.data.slice(0, 6).map((sandbox) => ({
          label: sandbox.sandbox_id,
          meta: `${sandbox.status}${sandbox.url ? ` / ${sandbox.url}` : ''}`,
          tone: sandbox.status === 'ready' ? 'good' : sandbox.status === 'failed' ? 'warn' : 'muted',
        }));
      } else {
        rows = [];
      }
    } catch (err) {
      error = err instanceof Error ? err.message : 'Failed to load module';
      rows = [];
    } finally {
      loading = false;
    }
  }

  function iconFor(value?: string): typeof Terminal {
    if (value === '/agents' || value === '/agent-control') return Bot;
    if (value === '/tasks' || value === '/build') return ListChecks;
    if (value === '/review') return GitPullRequest;
    if (value === '/files' || value === '/docs') return Folder;
    if (value === '/runtimes') return Cpu;
    if (value === '/sessions') return Terminal;
    if (value === '/workspaces') return Folder;
    if (value === '/skills') return ListChecks;
    if (value === '/sandboxes') return Cpu;
    return FileText;
  }

  function actionFor(value?: string): { label: string; run: () => void } {
    if (value === '/sessions') return { label: 'Add terminal', run: onAddTerminal };
    if (value === '/agents' || value === '/agent-control') return { label: 'Add agent', run: onAddAgent };
    if (value === '/review') return { label: 'Add git review', run: onAddGit };
    if (value === '/files' || value === '/docs') return { label: 'Add files', run: onAddFiles };
    if (value === '/tasks' || value === '/build' || value === '/goals' || value === '/projects') return { label: 'Add mission', run: onAddMission };
    return { label: 'Add terminal', run: onAddTerminal };
  }
</script>

<div class="wem-root">
  <div class="wem-head">
    <Icon size={18} aria-hidden="true" />
    <div>
      <strong>{title}</strong>
      <span>{subtitle}</span>
    </div>
  </div>

  <div class="wem-list" aria-label="{title} embedded module rows">
    {#if loading}
      <div class="wem-state"><Clock3 size={14} aria-hidden="true" /> Loading module...</div>
    {:else if error}
      <div class="wem-state wem-state--error">{error}</div>
    {:else if rows.length === 0}
      <div class="wem-state">No embedded data endpoint is wired for this module yet.</div>
    {:else}
      {#each rows as row}
        <div class="wem-row">
          <span class:wem-dot--good={row.tone === 'good'} class:wem-dot--warn={row.tone === 'warn'}></span>
          <div>
            <strong>{row.label}</strong>
            <small>{row.meta}</small>
          </div>
        </div>
      {/each}
    {/if}
  </div>

  <div class="wem-actions">
    <button type="button" class="wem-primary" onclick={primaryAction.run}>
      <Play size={12} aria-hidden="true" /> {primaryAction.label}
    </button>
    <button type="button" class="wem-secondary" onclick={load}>
      <CheckCircle2 size={12} aria-hidden="true" /> Refresh
    </button>
    {#if route}
      <button type="button" class="wem-secondary" onclick={() => goto(route!)}>
        Open
      </button>
    {/if}
  </div>
</div>

<style>
  .wem-root {
    display: grid;
    grid-template-rows: auto 1fr auto;
    gap: 10px;
    min-height: 0;
    height: 100%;
  }

  .wem-head {
    display: flex;
    align-items: center;
    gap: 9px;
    min-width: 0;
  }

  .wem-head div {
    display: grid;
    gap: 2px;
    min-width: 0;
  }

  .wem-head strong,
  .wem-row strong {
    overflow: hidden;
    color: var(--fg);
    font-size: 12px;
    line-height: 1.25;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .wem-head span,
  .wem-row small,
  .wem-state {
    color: var(--fg-subtle);
    font-size: 11px;
    line-height: 1.35;
  }

  .wem-list {
    display: grid;
    align-content: start;
    gap: 5px;
    min-height: 0;
    overflow: auto;
  }

  .wem-row {
    display: grid;
    grid-template-columns: 8px 1fr;
    align-items: center;
    gap: 8px;
    min-width: 0;
    padding: 7px 8px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .wem-row span {
    width: 7px;
    height: 7px;
    border-radius: 999px;
    background: var(--fg-subtle);
  }

  .wem-row .wem-dot--good {
    background: var(--success, oklch(0.72 0.18 145));
  }

  .wem-row .wem-dot--warn {
    background: oklch(0.78 0.16 75);
  }

  .wem-row div {
    display: grid;
    gap: 1px;
    min-width: 0;
  }

  .wem-state {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px;
  }

  .wem-state--error {
    color: var(--destructive, oklch(0.65 0.22 25));
  }

  .wem-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .wem-primary,
  .wem-secondary {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    min-height: 26px;
    padding: 0 9px;
    border: 1px solid var(--border);
    border-radius: 6px;
    font: inherit;
    font-size: 11px;
    cursor: pointer;
  }

  .wem-primary {
    color: var(--fg);
    background: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 20%, transparent);
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 42%, var(--border));
  }

  .wem-secondary {
    color: var(--fg-muted);
    background: transparent;
  }
</style>
