<script lang="ts">
  /**
   * /routines — recurring automations. Fires scheduled prompts into agents.
   * CSS prefix: rt- (routines).
   */
  import { createMutation, createQuery, useQueryClient } from "@tanstack/svelte-query";
  import { writable } from "svelte/store";
  import { untrack } from "svelte";
  import { Repeat, Plus, Play, Pause, Flame, X } from "lucide-svelte";
  import {
    routinesQuery,
    createRoutineMutation,
    enableRoutineMutation,
    disableRoutineMutation,
    fireRoutineMutation,
  } from "$lib/api/queries/routines.js";
  import { hiredAgentsQuery } from "$lib/api/queries/agents.js";
  import type { Routine, CreateRoutineBody, RoutineCreates } from "$lib/domain/routines/types.js";
  import type { Agent } from "$lib/domain/agents/types.js";

  const queryClient = useQueryClient();

  // ── Routines query ─────────────────────────────────────────────────────────

  const optsStore = writable(untrack(() => routinesQuery()));
  const routinesQ = createQuery<Routine[]>(optsStore);
  const routines = $derived(($routinesQ.data ?? []) as Routine[]);

  const backendUnavailable = $derived(
    $routinesQ.isError &&
      String(($routinesQ.error as Error)?.message ?? "").includes("404"),
  );

  // ── Hired agents for target agent select ──────────────────────────────────

  const agentsOptsStore = writable(untrack(() => hiredAgentsQuery()));
  const agentsQ = createQuery<Agent[]>(agentsOptsStore);
  const hiredAgents = $derived(($agentsQ.data ?? []) as Agent[]);

  // ── Row action mutations ───────────────────────────────────────────────────

  const enableMut = createMutation(enableRoutineMutation());
  const disableMut = createMutation(disableRoutineMutation());
  const fireMut = createMutation(fireRoutineMutation());

  function invalidate(): void {
    queryClient.invalidateQueries({ queryKey: ["routines"] });
  }

  function toggle(r: Routine): void {
    if (r.enabled) $disableMut.mutate(r.shortId, { onSuccess: invalidate });
    else $enableMut.mutate(r.shortId, { onSuccess: invalidate });
  }

  function fire(r: Routine): void {
    $fireMut.mutate(r.shortId, { onSuccess: invalidate });
  }

  // ── Create modal ───────────────────────────────────────────────────────────

  const EMPTY_DRAFT: CreateRoutineBody = {
    name: "",
    description: "",
    cron: "",
    promptTemplate: "",
    creates: "task",
    targetAgentSlug: "",
  };

  let modalOpen = $state(false);
  let draft = $state<CreateRoutineBody>({ ...EMPTY_DRAFT });
  let createError = $state<string | null>(null);

  const createMut = createMutation(createRoutineMutation());

  async function submitRoutine() {
    if (!draft.name.trim()) return;
    createError = null;
    try {
      const body: CreateRoutineBody = { name: draft.name.trim() };
      if (draft.description?.trim()) body.description = draft.description.trim();
      if (draft.cron?.trim()) body.cron = draft.cron.trim();
      if (draft.promptTemplate?.trim()) body.promptTemplate = draft.promptTemplate.trim();
      if (draft.creates) body.creates = draft.creates;
      if (draft.targetAgentSlug?.trim()) body.targetAgentSlug = draft.targetAgentSlug.trim();
      await $createMut.mutateAsync(body);
      await queryClient.invalidateQueries({ queryKey: ["routines"] });
      modalOpen = false;
      draft = { ...EMPTY_DRAFT };
    } catch (err) {
      createError = err instanceof Error ? err.message : "Failed to create routine";
    }
  }

  function openModal() {
    createError = null;
    draft = { ...EMPTY_DRAFT };
    modalOpen = true;
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  function relTime(iso: string | null): string {
    if (!iso) return "never";
    const diff = Date.now() - new Date(iso).getTime();
    const m = Math.floor(diff / 60_000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h / 24)}d ago`;
  }

  function decodeCron(cron: string | null): string {
    if (!cron) return "—";
    const map: Record<string, string> = {
      "0 9 * * 1": "Every Monday at 9:00",
      "0 9 * * *": "Every day at 9:00",
      "0 0 * * *": "Every day at midnight",
      "*/15 * * * *": "Every 15 minutes",
      "0 * * * *": "Every hour",
    };
    return map[cron] ?? cron;
  }

  // ── Example seed data (shown when no real routines) ────────────────────────

  type ExRoutine = Routine & { _triggerType?: string; _lastRunStatus?: string };

  const EXAMPLE_ROUTINES: ExRoutine[] = [
    {
      id: "ex-r1",
      shortId: "ci-monitor",
      name: "CI Monitor",
      description: "Watches for failing CI and auto-fixes flaky tests",
      cron: "*/15 * * * *",
      promptTemplate: "Check all CI runs in the last 15 minutes. If any are failing, identify the root cause and attempt an auto-fix.",
      creates: "task" as RoutineCreates,
      targetAgentSlug: "forge",
      enabled: true,
      runCount: 247,
      lastRunAt: new Date(Date.now() - 900000).toISOString(),
      _triggerType: "cron",
      _lastRunStatus: "completed",
    },
    {
      id: "ex-r2",
      shortId: "inbox-triage",
      name: "Inbox Triage",
      description: "Monitors inbox and categorizes by priority and project",
      cron: "0 * * * *",
      promptTemplate: "Check the inbox for new items. Categorize each by priority (high/medium/low) and assign to the relevant project tag.",
      creates: "task" as RoutineCreates,
      targetAgentSlug: "conductor",
      enabled: true,
      runCount: 89,
      lastRunAt: new Date(Date.now() - 3600000).toISOString(),
      _triggerType: "cron",
      _lastRunStatus: "completed",
    },
    {
      id: "ex-r3",
      shortId: "code-formatter",
      name: "Code Formatter",
      description: "Runs on file save to format code and fix lint warnings",
      cron: null,
      promptTemplate: "Format the changed files using the project's style config. Fix any auto-fixable lint warnings.",
      creates: "task" as RoutineCreates,
      targetAgentSlug: "iris",
      enabled: true,
      runCount: 1024,
      lastRunAt: new Date(Date.now() - 120000).toISOString(),
      _triggerType: "event",
      _lastRunStatus: "completed",
    },
    {
      id: "ex-r4",
      shortId: "security-scanner",
      name: "Security Scanner",
      description: "Continuous vulnerability scanning across all dependencies",
      cron: "0 3 * * *",
      promptTemplate: "Run a full security scan: CVE lookups, SAST analysis, secret detection. Report any new findings.",
      creates: "issue" as RoutineCreates,
      targetAgentSlug: "conductor",
      enabled: false,
      runCount: 14,
      lastRunAt: new Date(Date.now() - 86400000).toISOString(),
      _triggerType: "cron",
      _lastRunStatus: "completed",
    },
  ] as unknown as ExRoutine[];

  const isExample = $derived(routines.length === 0 && !$routinesQ.isLoading);
  const displayRoutines = $derived(isExample ? EXAMPLE_ROUTINES : (routines as ExRoutine[]));

  // ── Trigger type in create modal ───────────────────────────────────────────
  let formTriggerType = $state<"cron" | "event">("cron");
  let formEventTrigger = $state("on_push");

  const EVENT_TRIGGERS = [
    { value: "on_push", label: "On push" },
    { value: "on_pr", label: "On pull request" },
    { value: "on_file_save", label: "On file save" },
    { value: "on_workspace_change", label: "On workspace change" },
    { value: "on_issue_created", label: "On issue created" },
  ];
</script>

<div class="rt-page">
  <header class="rt-header">
    <div>
      <h1 class="rt-title"><Repeat size={20} aria-hidden="true" /> Routines</h1>
      <p class="rt-sub">Always-on automations that monitor, react, and maintain your workspace.</p>
    </div>
    <button class="rt-btn rt-btn--primary" onclick={openModal}>
      <Plus size={14} aria-hidden="true" />
      New routine
    </button>
  </header>

  <div class="rt-info-banner">
    <Repeat size={13} aria-hidden="true" />
    <span><strong>Routines</strong> — Always-on automations. Persistent background processes that monitor, react, and maintain your workspace.</span>
  </div>

  {#if backendUnavailable}
    <div class="rt-banner rt-banner--warn">
      Routines backend module not yet deployed — list will populate once it ships.
    </div>
  {:else if $routinesQ.isLoading}
    <div class="rt-skeleton">Loading routines…</div>
  {:else}
    {#if isExample}
      <div class="rt-example-banner" role="status">
        These are example routines. Create your first routine to get started.
      </div>
    {/if}

    <table class="rt-table">
      <thead>
        <tr>
          <th>Name</th>
          <th>Trigger</th>
          <th>Agent</th>
          <th>Last run</th>
          <th>Runs</th>
          <th>Status</th>
          <th aria-label="Actions"></th>
        </tr>
      </thead>
      <tbody>
        {#each displayRoutines as r (r.id)}
          <tr class="rt-row" class:rt-row--disabled={!r.enabled}>
            <td>
              <div class="rt-name-wrap">
                <span class="rt-name">{r.name}</span>
                {#if isExample}
                  <span class="rt-example-badge">Example</span>
                {/if}
              </div>
              {#if r.description}
                <div class="rt-desc">{r.description}</div>
              {/if}
              <div class="rt-short">{r.shortId}</div>
            </td>
            <td class="rt-mono" title={r.cron ?? ""}>
              {#if (r as ExRoutine)._triggerType === "event"}
                <span class="rt-trigger-badge rt-trigger-badge--event">Event</span>
              {:else}
                <span class="rt-trigger-badge rt-trigger-badge--cron">Cron</span>
              {/if}
              <div class="rt-trigger-detail">{decodeCron(r.cron)}</div>
            </td>
            <td class="rt-muted">{r.targetAgentSlug || "—"}</td>
            <td class="rt-muted">{relTime(r.lastRunAt)}</td>
            <td class="rt-muted">{r.runCount}</td>
            <td>
              <span class="rt-status-pill" class:rt-status-pill--on={r.enabled} class:rt-status-pill--off={!r.enabled}>
                {r.enabled ? "Enabled" : "Disabled"}
              </span>
            </td>
            <td class="rt-actions">
              <button class="rt-icon" onclick={() => !isExample && fire(r)} title="Fire now" aria-label="Fire {r.name}" disabled={isExample}>
                <Flame size={14} aria-hidden="true" />
              </button>
              <button class="rt-icon" onclick={() => !isExample && toggle(r)} title={r.enabled ? "Disable" : "Enable"} aria-label="{r.enabled ? 'Disable' : 'Enable'} {r.name}" disabled={isExample}>
                {#if r.enabled}<Pause size={14} aria-hidden="true" />{:else}<Play size={14} aria-hidden="true" />{/if}
              </button>
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/if}
</div>

<!-- New routine modal -->
{#if modalOpen}
  <div class="rt-overlay" role="dialog" aria-modal="true" aria-label="New routine">
    <div class="rt-modal">
      <div class="rt-modal__head">
        <span class="rt-modal__label">New routine</span>
        <button
          class="rt-modal__close"
          onclick={() => { modalOpen = false; }}
          aria-label="Close"
        >
          <X size={14} aria-hidden="true" />
        </button>
      </div>

      <div class="rt-modal__body">
        <label class="rt-field">
          <span class="rt-field__label">Name</span>
          <input
            class="rt-input"
            type="text"
            placeholder="What does this routine do?"
            bind:value={draft.name}
            aria-required="true"
          />
        </label>

        <label class="rt-field">
          <span class="rt-field__label">Prompt template</span>
          <textarea
            class="rt-input rt-textarea"
            placeholder="The prompt that gets sent to the agent on each run…"
            bind:value={draft.promptTemplate}
            rows={3}
          ></textarea>
        </label>

        <div class="rt-row">
          <label class="rt-field rt-field--half">
            <span class="rt-field__label">Trigger type</span>
            <select class="rt-select" bind:value={formTriggerType} aria-label="Trigger type">
              <option value="cron">Cron (time-based)</option>
              <option value="event">Event (workspace change)</option>
            </select>
          </label>

          <label class="rt-field rt-field--half">
            <span class="rt-field__label">Creates</span>
            <select class="rt-select" bind:value={draft.creates}>
              <option value="task">Task</option>
              <option value="issue">Issue</option>
              <option value="goal">Goal</option>
            </select>
          </label>
        </div>

        {#if formTriggerType === "cron"}
          <label class="rt-field">
            <span class="rt-field__label">Cron expression</span>
            <input
              class="rt-input rt-mono-input"
              type="text"
              placeholder="0 9 * * *"
              bind:value={draft.cron}
            />
          </label>
        {:else}
          <label class="rt-field">
            <span class="rt-field__label">Event trigger</span>
            <select class="rt-select" bind:value={formEventTrigger} aria-label="Event trigger">
              {#each EVENT_TRIGGERS as ev (ev.value)}
                <option value={ev.value}>{ev.label}</option>
              {/each}
            </select>
          </label>
        {/if}

        <label class="rt-field">
          <span class="rt-field__label">Target agent <span class="rt-field__opt">(optional)</span></span>
          <select class="rt-select" bind:value={draft.targetAgentSlug}>
            <option value="">— none —</option>
            {#each hiredAgents as agent (agent.slug)}
              <option value={agent.slug}>{agent.name}</option>
            {/each}
          </select>
        </label>

        {#if createError}
          <p class="rt-error">{createError}</p>
        {/if}
      </div>

      <div class="rt-modal__foot">
        <button
          class="rt-modal-btn rt-modal-btn--ghost"
          onclick={() => { modalOpen = false; }}
          disabled={$createMut.isPending}
        >
          Cancel
        </button>
        <button
          class="rt-modal-btn rt-modal-btn--primary"
          onclick={submitRoutine}
          disabled={$createMut.isPending || !draft.name.trim()}
        >
          {$createMut.isPending ? "Creating…" : "Create routine"}
        </button>
      </div>
    </div>
  </div>
{/if}

<style>
  /* ── Page layout ─────────────────────────────────────────────────────────── */
  .rt-page { padding: var(--space-4); display: flex; flex-direction: column; gap: var(--space-4); }
  .rt-header { display: flex; justify-content: space-between; align-items: flex-end; }
  .rt-title { display: flex; align-items: center; gap: var(--space-2); font-size: var(--text-xl); font-weight: 600; margin: 0; }
  .rt-sub { color: var(--fg-subtle); font-size: var(--text-sm); margin: 4px 0 0; }

  /* ── Header button ───────────────────────────────────────────────────────── */
  .rt-btn { display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; border-radius: var(--radius-md); border: 1px solid var(--border); background: var(--bg-subtle); color: var(--fg); font-size: var(--text-sm); font-family: var(--font-sans); cursor: pointer; }
  .rt-btn--primary { background: var(--cnp-accent); color: var(--cnp-accent-foreground); border-color: var(--cnp-accent); }
  .rt-btn--primary:hover { filter: brightness(1.05); }

  /* ── Status / loading ────────────────────────────────────────────────────── */
  .rt-banner { padding: var(--space-3); border-radius: var(--radius-md); border: 1px solid var(--border); background: var(--bg-subtle); font-size: var(--text-sm); }
  .rt-banner--warn { border-color: color-mix(in oklch, var(--priority) 50%, var(--border) 50%); color: var(--priority); }
  .rt-skeleton { color: var(--fg-subtle); font-size: var(--text-sm); padding: var(--space-4); }
  .rt-empty { display: flex; flex-direction: column; align-items: center; gap: var(--space-2); padding: var(--space-8); color: var(--fg-subtle); font-size: var(--text-sm); }

  /* ── Table ───────────────────────────────────────────────────────────────── */
  .rt-table { width: 100%; border-collapse: collapse; font-size: var(--text-sm); }
  .rt-table th { text-align: left; font-weight: 600; color: var(--fg-subtle); padding: 8px 12px; border-bottom: 1px solid var(--border); font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em; }
  .rt-row { border-bottom: 1px solid var(--border-subtle); }
  .rt-row td { padding: 10px 12px; vertical-align: middle; }
  .rt-row--disabled { opacity: 0.55; }
  .rt-name { color: var(--fg); text-decoration: none; font-weight: 500; }
  .rt-name:hover { color: var(--cnp-accent); }
  .rt-short { color: var(--fg-subtle); font-family: var(--font-mono); font-size: 11px; }
  .rt-mono { font-family: var(--font-mono); font-size: var(--text-xs); }
  .rt-pill { display: inline-block; padding: 2px 8px; border-radius: 9999px; background: var(--bg-subtle); font-size: 11px; text-transform: lowercase; }
  .rt-actions { display: flex; gap: 4px; justify-content: flex-end; }
  .rt-icon { background: transparent; border: 1px solid transparent; border-radius: var(--radius-sm); padding: 4px; cursor: pointer; color: var(--fg-muted); }
  .rt-icon:hover { background: var(--bg-subtle); color: var(--fg); border-color: var(--border); }

  /* ── Modal overlay + card ────────────────────────────────────────────────── */
  .rt-overlay {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, var(--bg) 60%, transparent 40%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }

  .rt-modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border-strong);
    border-radius: var(--radius-xl);
    width: 100%;
    max-width: 480px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 20px 60px color-mix(in oklch, var(--bg) 0%, transparent 70%);
  }

  .rt-modal__head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4) var(--space-5);
    border-bottom: 1px solid var(--border);
  }

  .rt-modal__label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .rt-modal__close {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    background: transparent;
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    color: var(--fg-muted);
  }

  .rt-modal__close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .rt-modal__body {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5);
  }

  .rt-modal__foot {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding: var(--space-4) var(--space-5);
    border-top: 1px solid var(--border);
  }

  /* ── Form fields ─────────────────────────────────────────────────────────── */
  .rt-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rt-field--half {
    flex: 1;
  }

  .rt-field__label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .rt-field__opt {
    font-weight: 400;
    text-transform: none;
    letter-spacing: 0;
    color: var(--fg-subtle);
  }

  .rt-row {
    display: flex;
    gap: var(--space-3);
  }

  .rt-input,
  .rt-select {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    width: 100%;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .rt-input:focus,
  .rt-select:focus {
    border-color: var(--border-strong);
  }

  .rt-textarea {
    resize: vertical;
    min-height: 72px;
  }

  .rt-mono-input {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .rt-error {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: #f87171;
    margin: 0;
  }

  /* ── Info + example banners ─────────────────────────────────────────────── */
  .rt-info-banner {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.55rem 0.85rem;
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 7%, var(--bg-elevated, var(--bg)));
    border: 1px solid color-mix(in oklch, var(--cnp-accent, #6366f1) 20%, var(--border));
    border-radius: 7px;
    font-size: 0.82rem;
    color: var(--fg-muted);
  }
  .rt-info-banner strong { color: var(--fg); }

  .rt-example-banner {
    padding: 0.55rem 0.85rem;
    background: color-mix(in oklch, #d97706 7%, var(--bg));
    border: 1px solid color-mix(in oklch, #d97706 25%, var(--border));
    border-radius: 7px;
    font-size: 0.82rem;
    color: #d97706;
    margin-bottom: 0.75rem;
  }

  .rt-example-badge {
    display: inline-block;
    padding: 0.1rem 0.4rem;
    border-radius: 4px;
    font-size: 0.65rem;
    font-weight: 600;
    background: color-mix(in oklch, #d97706 14%, transparent);
    color: #d97706;
    margin-left: 0.4rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  /* ── Name + description cell ─────────────────────────────────────────────── */
  .rt-name-wrap { display: flex; align-items: center; }
  .rt-desc { color: var(--fg-subtle); font-size: 11px; margin-top: 2px; }
  .rt-muted { color: var(--fg-muted); font-size: var(--text-sm); }

  /* ── Trigger badges ──────────────────────────────────────────────────────── */
  .rt-trigger-badge {
    display: inline-block;
    padding: 0.1rem 0.45rem;
    border-radius: 4px;
    font-size: 0.68rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .rt-trigger-badge--cron {
    background: color-mix(in oklch, var(--cnp-accent, #6366f1) 14%, transparent);
    color: var(--cnp-accent, #6366f1);
  }
  .rt-trigger-badge--event {
    background: color-mix(in oklch, #059669 14%, transparent);
    color: #059669;
  }
  .rt-trigger-detail {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    margin-top: 2px;
  }

  /* ── Status pill ─────────────────────────────────────────────────────────── */
  .rt-status-pill {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 99px;
    font-size: 0.7rem;
    font-weight: 500;
  }
  .rt-status-pill--on {
    background: color-mix(in oklch, #059669 14%, transparent);
    color: #059669;
  }
  .rt-status-pill--off {
    background: color-mix(in oklch, #d97706 14%, transparent);
    color: #d97706;
  }

  /* ── Modal buttons ───────────────────────────────────────────────────────── */
  .rt-modal-btn {
    padding: var(--space-2) var(--space-4);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    transition: background var(--dur-instant) var(--ease-out);
    border: 1px solid transparent;
  }

  .rt-modal-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .rt-modal-btn--ghost {
    background: transparent;
    color: var(--fg-muted);
    border-color: var(--border);
  }

  .rt-modal-btn--ghost:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .rt-modal-btn--primary {
    background: color-mix(in oklch, var(--fg) 10%, transparent 90%);
    border-color: var(--border-strong);
    color: var(--fg);
  }

  .rt-modal-btn--primary:not(:disabled):hover {
    background: color-mix(in oklch, var(--fg) 16%, transparent 84%);
  }
</style>
