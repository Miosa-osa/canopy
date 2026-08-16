<script lang="ts">
  /**
   * /schedule — Schedule super-module dashboard.
   * Powered by the Scheduling Agent via /api/v1/schedule/*.
   *
   * Sections:
   *   1. Stat tiles — active specs, runs (24h), miss/late counts, open incidents
   *   2. Scheduled Specs table — full spec list with create form + actions
   *   3. Run timeline — vertical timeline of recent runs with status indicators
   *   4. Overlap detection — pairs of runs that collided
   *   5. Heartbeat overlay — active specs with next_fire_at
   *   6. Incident banner — open alerts surface above the page
   *
   * CSS prefix: sc-
   */
  import {
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { untrack } from "svelte";
  import { writable } from "svelte/store";
  import {
    AlertTriangle,
    Archive,
    ArrowLeft,
    Calendar,
    CheckCircle2,
    Clock,
    Pencil,
    PauseCircle,
    PlayCircle,
    Plus,
    Timer,
    Trash2,
    XCircle,
    Zap,
  } from "lucide-svelte";
  import {
    acknowledgeAlert,
    alertsQuery,
    archiveSpec,
    createSpec,
    overlapsQuery,
    pauseSpec,
    runAggregateQuery,
    runsQuery,
    specsQuery,
    unpauseSpec,
  } from "$lib/api/queries/schedule.js";
  import { hiredAgentsQuery } from "$lib/api/queries/agents.js";
  import { listWorkspaces } from "$lib/api/queries/workspaces.js";
  import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
  import type {
    Alert,
    Overlap,
    OverlapPolicy,
    Run,
    RunBuckets,
    Spec,
    SpecCreate,
  } from "$lib/domain/schedule/types.js";
  import type { Agent } from "$lib/domain/agents/types.js";
  import type { Workspace } from "$lib/domain/workspaces/types.js";
  import { PROVIDERS } from "$lib/domain/runtimes/providers.js";
  import { runtimesQuery } from "$lib/api/queries/runtimes.js";
  import type { Runtime } from "$lib/domain/runtimes/types.js";

  const qc = useQueryClient();

  // ── View state ─────────────────────────────────────────────────────────────

  type MainTab = "list" | "calendar" | "timeline";
  let activeTab = $state<MainTab>("list");
  let showCreateModal = $state(false);
  let selectedSpecSlug = $state<string | null>(null);

  // Sort for spec table
  type SortKey = "nextFireAt" | "name" | "status";
  let sortKey = $state<SortKey>("nextFireAt");
  let sortAsc = $state(true);

  // ── Create modal form state ────────────────────────────────────────────────

  type Frequency = "manual" | "hourly" | "daily" | "weekdays" | "weekly" | "monthly" | "custom";

  let formName = $state("");
  let formDescription = $state("");
  let formPrompt = $state("");
  let formAgentSlug = $state("");
  let formWorkspaceSlug = $state("");
  let formPermissionMode = $state<"ask" | "auto">("ask");
  let formModel = $state("sonnet-4");
  let formFrequency = $state<Frequency>("daily");
  let formCustomCron = $state("0 9 * * *");
  let formError = $state<string | null>(null);
  let formSubmitting = $state(false);


  const FREQUENCY_CRONS: Record<Frequency, string[]> = {
    manual: [],
    hourly: ["0 * * * *"],
    daily: ["0 9 * * *"],
    weekdays: ["0 9 * * 1-5"],
    weekly: ["0 9 * * 1"],
    monthly: ["0 9 1 * *"],
    custom: [],
  };

  const FREQUENCY_LABELS: Record<Frequency, string> = {
    manual: "Manual (one-shot)",
    hourly: "Hourly",
    daily: "Daily",
    weekdays: "Weekdays",
    weekly: "Weekly",
    monthly: "Monthly",
    custom: "Custom cron",
  };

  // All models across providers for the model picker
  const ALL_MODELS = $derived(
    PROVIDERS.flatMap((p) => p.models.map((m) => ({ ...m, providerName: p.name }))),
  );

  // Workspaces query for the workspace picker
  const workspacesStore = writable(
    untrack(() => ({
      queryKey: ["workspaces"],
      queryFn: () => listWorkspaces(),
    } as CreateQueryOptions<Workspace[]>)),
  );
  const workspacesQ = createQuery<Workspace[]>(workspacesStore);
  const workspaces = $derived($workspacesQ.data ?? []);

  const OVERLAP_OPTIONS: Array<{ value: OverlapPolicy; label: string; desc: string }> = [
    { value: "skip", label: "Skip", desc: "Drop the incoming run if one is already running" },
    { value: "buffer_one", label: "Buffer one", desc: "Queue up to one run behind the active one" },
    { value: "cancel_other", label: "Cancel other", desc: "Cancel the running run and start the new one" },
    { value: "terminate_other", label: "Terminate other", desc: "Force-kill the running run and start fresh" },
  ];

  // ── Queries ────────────────────────────────────────────────────────────────

  const specsStore = writable(
    untrack(() => specsQuery({}) as CreateQueryOptions<Spec[]>),
  );
  const specsQ = createQuery<Spec[]>(specsStore);

  const hiredAgentsStore = writable(
    untrack(() => hiredAgentsQuery() as CreateQueryOptions<Agent[]>),
  );
  const hiredAgentsQ = createQuery<Agent[]>(hiredAgentsStore);

  const runsStore = writable(
    untrack(
      () =>
        runsQuery({
          since: twentyFourHoursAgo(),
          limit: 200,
        }) as CreateQueryOptions<Run[]>,
    ),
  );
  const runsQ = createQuery<Run[]>(runsStore);

  const aggregateStore = writable(
    untrack(
      () =>
        runAggregateQuery({
          granularity: "hour",
          from: twentyFourHoursAgo(),
        }) as CreateQueryOptions<RunBuckets>,
    ),
  );
  const aggregateQ = createQuery<RunBuckets>(aggregateStore);

  const overlapsStore = writable(
    untrack(
      () =>
        overlapsQuery({
          since: twentyFourHoursAgo(),
          toleranceSeconds: 60,
        }) as CreateQueryOptions<Overlap[]>,
    ),
  );
  const overlapsQ = createQuery<Overlap[]>(overlapsStore);

  const alertsStore = writable(
    untrack(() => alertsQuery({ status: "open" }) as CreateQueryOptions<Alert[]>),
  );
  const alertsQ = createQuery<Alert[]>(alertsStore);

  // ── Mutations ──────────────────────────────────────────────────────────────

  const ackMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => acknowledgeAlert(slug, "user"),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "alerts"] });
    },
  });

  const pauseMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => pauseSpec(slug, "manual"),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  const unpauseMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => unpauseSpec(slug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  const archiveMut = createMutation({
    mutationFn: ({ slug }: { slug: string }) => archiveSpec(slug),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
    },
  });

  function handleAck(slug: string) {
    $ackMut.mutate({ slug });
  }

  function handlePauseToggle(spec: Spec) {
    if (spec.status === "paused") {
      $unpauseMut.mutate({ slug: spec.slug });
    } else {
      $pauseMut.mutate({ slug: spec.slug });
    }
  }

  function handleArchive(spec: Spec) {
    if (!confirm(`Archive "${spec.name}"? This cannot be undone.`)) return;
    $archiveMut.mutate({ slug: spec.slug });
  }

  function frequencyHumanLabel(spec: Spec): string {
    const crons = spec.model?.crons ?? [];
    if (!crons.length) return "Manual only";
    const c = crons[0];
    if (c === "0 * * * *") return "Every hour";
    if (c === "0 9 * * *") return "Every day at 9am";
    if (c === "0 9 * * 1-5") return "Every weekday at 9am";
    if (c === "0 9 * * 1") return "Every Monday at 9am";
    if (c === "0 9 1 * *") return "1st of month at 9am";
    return crons.join(", ");
  }

  async function handleCreateSubmit() {
    formError = null;
    if (!formName.trim()) { formError = "Name is required"; return; }
    if (!formPrompt.trim()) { formError = "Prompt is required"; return; }

    const slug = slugifyName(formName);
    let crons: string[] = FREQUENCY_CRONS[formFrequency];
    if (formFrequency === "custom") {
      if (!formCustomCron.trim()) { formError = "Custom cron expression is required"; return; }
      crons = [formCustomCron.trim()];
    }

    const payload: SpecCreate = {
      slug,
      name: formName.trim(),
      description: formDescription.trim() || undefined,
      model: { crons },
      overlapPolicy: "skip",
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      graceSeconds: 30,
      jitterSeconds: 0,
      agentSlug: formAgentSlug || "conductor",
      ...(formWorkspaceSlug ? { workspaceSlug: formWorkspaceSlug } : {}),
    };

    formSubmitting = true;
    try {
      const created = await createSpec(payload);
      qc.invalidateQueries({ queryKey: ["schedule", "specs"] });
      showCreateModal = false;
      resetForm();
      // Navigate to detail view for the newly created spec
      selectedSpecSlug = created.slug;
    } catch (e: unknown) {
      formError = e instanceof Error ? e.message : "Failed to create spec";
    } finally {
      formSubmitting = false;
    }
  }

  function resetForm() {
    formName = "";
    formDescription = "";
    formPrompt = "";
    formAgentSlug = "";
    formWorkspaceSlug = "";
    formPermissionMode = "ask";
    formModel = "sonnet-4";
    formFrequency = "daily";
    formCustomCron = "0 9 * * *";
    formError = null;
  }

  function closeModal() {
    showCreateModal = false;
    resetForm();
  }

  function handleModalKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") closeModal();
  }

  function slugifyName(name: string): string {
    return name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
  }

  function cronDescription(expr: string): string {
    const parts = expr.trim().split(/\s+/);
    if (parts.length !== 5) return "";
    const [min, hr, , , dow] = parts;
    if (expr === "* * * * *") return "Every minute";
    if (min === "0" && hr === "*" && dow === "*") return "Every hour";
    if (min === "0" && hr === "0" && dow === "*") return "Every day at midnight";
    if (min === "0" && hr !== "*" && dow === "1-5") return `Weekdays at ${hr}:00`;
    if (min === "0" && hr !== "*" && dow === "1") return `Mondays at ${hr}:00`;
    return "";
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  const specs = $derived($specsQ.data ?? []);
  const hiredAgents = $derived($hiredAgentsQ.data ?? []);

  const runtimesStore = writable(
    untrack(() => runtimesQuery() as CreateQueryOptions<Runtime[]>),
  );
  const runtimesQ = createQuery<Runtime[]>(runtimesStore);
  const installedRuntimes = $derived(
    ($runtimesQ.data ?? []).filter((r: Runtime & { installed?: boolean }) =>
      r.installed === true || r.status === 'installed'
    ),
  );
  const runs = $derived($runsQ.data ?? []);
  const overlaps = $derived($overlapsQ.data ?? []);
  const alerts = $derived($alertsQ.data ?? []);
  const aggregate = $derived($aggregateQ.data?.rows ?? []);

  const activeSpecs = $derived(specs.filter((s) => s.status === "active"));
  const totalSpecs = $derived(activeSpecs.length);
  const totalRuns24h = $derived(runs.length);
  const missCount = $derived(runs.filter((r) => r.status === "missed").length);
  const lateCount = $derived(runs.filter((r) => r.status === "late").length);
  const failedCount = $derived(runs.filter((r) => r.status === "failed").length);
  const succeededCount = $derived(
    runs.filter((r) => r.status === "completed").length,
  );
  const openIncidents = $derived(alerts.length);

  // Sorted spec list (all statuses)
  const sortedSpecs = $derived(
    [...specs].sort((a, b) => {
      let cmp = 0;
      if (sortKey === "name") cmp = a.name.localeCompare(b.name);
      else if (sortKey === "status") cmp = a.status.localeCompare(b.status);
      else {
        const at = a.nextFireAt ? new Date(a.nextFireAt).getTime() : Infinity;
        const bt = b.nextFireAt ? new Date(b.nextFireAt).getTime() : Infinity;
        cmp = at - bt;
      }
      return sortAsc ? cmp : -cmp;
    }),
  );

  function toggleSort(key: SortKey) {
    if (sortKey === key) sortAsc = !sortAsc;
    else { sortKey = key; sortAsc = true; }
  }

  // Calendar month view
  let calendarYear = $state(new Date().getFullYear());
  let calendarMonth = $state(new Date().getMonth()); // 0-indexed

  const calendarDays = $derived(buildCalendarDays(calendarYear, calendarMonth));
  const calendarSpecDots = $derived(buildCalendarDots(specs, calendarYear, calendarMonth));

  function buildCalendarDays(y: number, m: number): Array<{ date: Date | null; key: string }> {
    const first = new Date(y, m, 1);
    const last = new Date(y, m + 1, 0);
    const startDow = first.getDay(); // 0=Sun
    const days: Array<{ date: Date | null; key: string }> = [];
    for (let i = 0; i < startDow; i++) days.push({ date: null, key: `pad-${i}` });
    for (let d = 1; d <= last.getDate(); d++) {
      days.push({ date: new Date(y, m, d), key: `${y}-${m}-${d}` });
    }
    return days;
  }

  function buildCalendarDots(
    specList: Spec[],
    y: number,
    m: number,
  ): Map<string, string[]> {
    const map = new Map<string, string[]>();
    for (const spec of specList) {
      if (spec.status === "archived") continue;
      if (!spec.nextFireAt) continue;
      const d = new Date(spec.nextFireAt);
      if (d.getFullYear() === y && d.getMonth() === m) {
        const key = `${y}-${m}-${d.getDate()}`;
        if (!map.has(key)) map.set(key, []);
        map.get(key)!.push(spec.slug);
      }
    }
    return map;
  }

  function fmtCalendarMonth(y: number, m: number): string {
    return new Date(y, m, 1).toLocaleString(undefined, { month: "long", year: "numeric" });
  }

  function prevMonth() {
    if (calendarMonth === 0) { calendarMonth = 11; calendarYear -= 1; }
    else calendarMonth -= 1;
  }

  function nextMonth() {
    if (calendarMonth === 11) { calendarMonth = 0; calendarYear += 1; }
    else calendarMonth += 1;
  }

  // Run timeline: group by spec_slug and show recent
  const groupedRuns = $derived(groupRuns(runs));

  function groupRuns(rows: Run[]): Array<{ slug: string; runs: Run[] }> {
    const map = new Map<string, Run[]>();
    for (const r of rows) {
      const key = r.specSlug ?? "(unknown)";
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(r);
    }
    return Array.from(map.entries()).map(([slug, rs]) => ({ slug, runs: rs }));
  }

  const HEAT_W = 720;
  const HEAT_H = 60;

  const heatBars = $derived(
    aggregate.map((b, i) => {
      const max = Math.max(...aggregate.map((x) => x.total), 1);
      const bw = HEAT_W / Math.max(aggregate.length, 1) - 2;
      const bh = Math.round((b.total / max) * (HEAT_H - 4));
      return {
        x: i * (HEAT_W / Math.max(aggregate.length, 1)) + 1,
        y: HEAT_H - bh,
        w: bw,
        h: bh,
        bucket: b.bucket,
        total: b.total,
        succeeded: b.succeeded,
        failed: b.failed,
        missed: b.missed,
        late: b.late,
        bad: b.failed + b.missed + b.late > 0,
      };
    }),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  function fmtRelative(iso: string | null): string {
    if (!iso) return "—";
    const ms = Date.now() - new Date(iso).getTime();
    const s = Math.floor(ms / 1000);
    if (s < 60) return `${s}s ago`;
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  }

  function fmtNextFire(iso: string | null): string {
    if (!iso) return "—";
    const ms = new Date(iso).getTime() - Date.now();
    if (ms < 0) return "due now";
    const s = Math.floor(ms / 1000);
    if (s < 60) return `in ${s}s`;
    if (s < 3600) return `in ${Math.floor(s / 60)}m`;
    if (s < 86400) return `in ${Math.floor(s / 3600)}h`;
    return `in ${Math.floor(s / 86400)}d`;
  }

  function fmtBucket(iso: string): string {
    return new Date(iso).toLocaleString(undefined, {
      hour: "numeric",
      minute: "2-digit",
    });
  }

  function twentyFourHoursAgo(): string {
    const d = new Date();
    d.setHours(d.getHours() - 24);
    return d.toISOString();
  }

  function statusClass(status: string): string {
    return `sc-st-${status.replace(/_/g, "-")}`;
  }

  function severityClass(severity: string): string {
    return `sc-sev-${severity}`;
  }

  const isLoading = $derived(
    $specsQ.isLoading || $runsQ.isLoading || $alertsQ.isLoading,
  );

  // ── Example seed data (shown when no real data) ────────────────────────────

  const EXAMPLE_SPECS: Spec[] = [
    {
      id: "ex-1",
      slug: "daily-briefing",
      name: "Daily Briefing",
      description: "Summarize calendar, inbox, and project status",
      status: "active",
      agentSlug: "conductor",
      overlapPolicy: "skip",
      timezone: "UTC",
      graceSeconds: 30,
      jitterSeconds: 0,
      model: { crons: ["0 9 * * 1-5"] },
      nextFireAt: new Date(Date.now() + 3600000).toISOString(),
      lastRunAt: new Date(Date.now() - 86400000).toISOString(),
    },
    {
      id: "ex-2",
      slug: "code-review-sweep",
      name: "Code Review Sweep",
      description: "Review all open PRs and flag issues",
      status: "active",
      agentSlug: "iris",
      overlapPolicy: "skip",
      timezone: "UTC",
      graceSeconds: 30,
      jitterSeconds: 0,
      model: { crons: ["0 14 * * 1-5"] },
      nextFireAt: new Date(Date.now() + 7200000).toISOString(),
      lastRunAt: new Date(Date.now() - 172800000).toISOString(),
    },
    {
      id: "ex-3",
      slug: "weekly-cleanup",
      name: "Weekly Cleanup",
      description: "Archive stale branches and close old issues",
      status: "active",
      agentSlug: "forge",
      overlapPolicy: "skip",
      timezone: "UTC",
      graceSeconds: 30,
      jitterSeconds: 0,
      model: { crons: ["0 17 * * 5"] },
      nextFireAt: new Date(Date.now() + 259200000).toISOString(),
      lastRunAt: new Date(Date.now() - 604800000).toISOString(),
    },
    {
      id: "ex-4",
      slug: "dependency-audit",
      name: "Dependency Audit",
      description: "Check for outdated packages and vulnerabilities",
      status: "paused",
      agentSlug: "conductor",
      overlapPolicy: "skip",
      timezone: "UTC",
      graceSeconds: 30,
      jitterSeconds: 0,
      model: { crons: ["0 6 1 * *"] },
      nextFireAt: null,
      lastRunAt: new Date(Date.now() - 2592000000).toISOString(),
    },
  ] as unknown as Spec[];

  const EXAMPLE_RUNS: Run[] = [
    { id: "er-1", specSlug: "daily-briefing", status: "completed", scheduledAt: new Date(Date.now() - 86400000).toISOString(), durationMs: 12400, latenessMs: 0 },
    { id: "er-2", specSlug: "daily-briefing", status: "completed", scheduledAt: new Date(Date.now() - 172800000).toISOString(), durationMs: 9800, latenessMs: 0 },
    { id: "er-3", specSlug: "code-review-sweep", status: "completed", scheduledAt: new Date(Date.now() - 172800000).toISOString(), durationMs: 31200, latenessMs: 0 },
    { id: "er-4", specSlug: "dependency-audit", status: "failed", scheduledAt: new Date(Date.now() - 2592000000).toISOString(), durationMs: 4200, latenessMs: 0 },
    { id: "er-5", specSlug: "weekly-cleanup", status: "completed", scheduledAt: new Date(Date.now() - 604800000).toISOString(), durationMs: 18700, latenessMs: 0 },
  ] as unknown as Run[];

  const isExample = $derived(specs.length === 0 && !$specsQ.isLoading);
  const displaySpecs = $derived(isExample ? EXAMPLE_SPECS : sortedSpecs);
  const displayRuns = $derived(isExample ? EXAMPLE_RUNS : runs);
  const displayGroupedRuns = $derived(isExample ? groupRuns(EXAMPLE_RUNS) : groupedRuns);
</script>

<div class="sc-page">
  <header class="sc-header">
    <div class="sc-header-left">
      <h1 class="sc-title">Schedule</h1>
      <span class="sc-subtitle">
        Powered by the Scheduling Agent · Last 24 hours
        {#if openIncidents > 0}
          · <span class="sc-badge">{openIncidents} open incident{openIncidents === 1 ? "" : "s"}</span>
        {/if}
      </span>
    </div>
    <div class="sc-header-actions">
      <button
        type="button"
        class="sc-btn-primary"
        aria-label="Create new schedule spec"
        onclick={() => { showCreateModal = true; }}
      >
        <Plus size={13} aria-hidden="true" />
        New Schedule
      </button>
      <a href="/settings/schedule" class="sc-settings-link">
        <Calendar size={14} aria-hidden="true" />
        Settings
      </a>
    </div>
  </header>

  <div class="sc-info-banner">
    <Clock size={13} aria-hidden="true" />
    <span><strong>Schedule</strong> — Time-triggered tasks. Set a schedule, write a prompt, pick an agent. Runs at the specified frequency.</span>
  </div>

  {#if isExample}
    <div class="sc-example-banner" role="status">
      These are example schedules. Create your first schedule to get started.
    </div>
  {/if}

  {#if openIncidents > 0}
    <section class="sc-incident-banner" role="alert" aria-labelledby="sc-incidents-label">
      <div class="sc-incident-banner-header">
        <AlertTriangle size={14} aria-hidden="true" />
        <h2 class="sc-incident-banner-title" id="sc-incidents-label">
          {openIncidents} open incident{openIncidents === 1 ? "" : "s"}
        </h2>
      </div>
      <ul class="sc-incident-list">
        {#each alerts as alert (alert.id)}
          <li class="sc-incident {severityClass(alert.severity)}">
            <div class="sc-incident-row">
              <span class="sc-incident-cat">{alert.category}</span>
              <span class="sc-incident-sev">{alert.severity}</span>
              <span class="sc-incident-time">{fmtRelative(alert.firstSeenAt)}</span>
            </div>
            <div class="sc-incident-summary">{alert.summary}</div>
            {#if alert.specSlug}
              <div class="sc-incident-spec">spec: {alert.specSlug}</div>
            {/if}
            <div class="sc-incident-actions">
              <button
                type="button"
                class="sc-incident-ack"
                aria-label={`Acknowledge incident ${alert.summary}`}
                onclick={() => handleAck(alert.slug)}
                disabled={$ackMut.isPending}
              >
                Acknowledge
              </button>
            </div>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  {#if isLoading}
    <div class="sc-loading">
      <SkeletonList count={4} height="5rem" gap="0.75rem" />
    </div>
  {:else}
    <!-- Stat tiles -->
    <div class="sc-tiles" role="list">
      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon"><Zap size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Active specs</span>
          <span class="sc-tile__value">{totalSpecs}</span>
        </div>
      </div>

      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon"><Clock size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Runs (24h)</span>
          <span class="sc-tile__value">{totalRuns24h}</span>
        </div>
      </div>

      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon sc-tile__icon--ok"><CheckCircle2 size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Succeeded</span>
          <span class="sc-tile__value">{succeededCount}</span>
        </div>
      </div>

      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon sc-tile__icon--warn"><Timer size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Late</span>
          <span class="sc-tile__value">{lateCount}</span>
        </div>
      </div>

      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon sc-tile__icon--err"><XCircle size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Missed</span>
          <span class="sc-tile__value">{missCount}</span>
        </div>
      </div>

      <div class="sc-tile" role="listitem">
        <div class="sc-tile__icon sc-tile__icon--err"><XCircle size={16} aria-hidden="true" /></div>
        <div class="sc-tile__body">
          <span class="sc-tile__label">Failed</span>
          <span class="sc-tile__value">{failedCount}</span>
        </div>
      </div>
    </div>

    <!-- Run heatmap -->
    <section class="sc-chart-card" aria-labelledby="sc-heat-label">
      <header class="sc-chart-header">
        <h2 class="sc-chart-title" id="sc-heat-label">Runs by hour (24h)</h2>
        <div class="sc-chart-legend">
          <span class="sc-legend"><span class="sc-legend-dot ok"></span>healthy</span>
          <span class="sc-legend"><span class="sc-legend-dot bad"></span>has miss/late/fail</span>
        </div>
      </header>
      {#if heatBars.length === 0}
        <p class="sc-chart-empty">No runs yet. Schedules begin firing once specs are created.</p>
      {:else}
        <div class="sc-chart-wrap" aria-hidden="true">
          <svg
            viewBox="0 0 {HEAT_W} {HEAT_H}"
            width="100%"
            height={HEAT_H}
            role="img"
            aria-label="Hourly run heatmap, last 24 hours"
          >
            {#each heatBars as bar, i (i)}
              <rect
                x={bar.x}
                y={bar.y}
                width={bar.w}
                height={bar.h}
                class={bar.bad ? "sc-heat-bar sc-heat-bar--bad" : "sc-heat-bar"}
              >
                <title>{fmtBucket(bar.bucket)}: {bar.total} runs ({bar.succeeded} ok, {bar.failed} failed, {bar.missed} missed, {bar.late} late)</title>
              </rect>
            {/each}
          </svg>
        </div>
      {/if}
    </section>

    <!-- ── Scheduled Specs — tabbed view ────────────────────────────────────── -->
    <section class="sc-section" aria-labelledby="sc-tabs-label">
      <header class="sc-section-header">
        <h2 class="sc-section-title" id="sc-tabs-label">
          <Zap size={14} aria-hidden="true" />
          Scheduled Specs
        </h2>
        <nav class="sc-tab-strip" aria-label="Specs view">
          <button
            type="button"
            class="sc-tab"
            class:active={activeTab === "list"}
            aria-selected={activeTab === "list"}
            onclick={() => activeTab = "list"}
          >List</button>
          <button
            type="button"
            class="sc-tab"
            class:active={activeTab === "calendar"}
            aria-selected={activeTab === "calendar"}
            onclick={() => activeTab = "calendar"}
          >Calendar</button>
          <button
            type="button"
            class="sc-tab"
            class:active={activeTab === "timeline"}
            aria-selected={activeTab === "timeline"}
            onclick={() => activeTab = "timeline"}
          >Timeline</button>
        </nav>
      </header>

      <!-- LIST TAB -->
      {#if activeTab === "list"}
        {#if selectedSpecSlug}
          {@const detailSpec = specs.find(s => s.slug === selectedSpecSlug)}
          {#if detailSpec}
            {@const specRuns = runs.filter(r => r.specSlug === detailSpec.slug).slice(0, 20)}
            <div class="sc-detail">
              <button
                type="button"
                class="sc-detail-back"
                onclick={() => selectedSpecSlug = null}
                aria-label="Back to all scheduled tasks"
              >
                <ArrowLeft size={13} aria-hidden="true" />
                All scheduled tasks
              </button>

              <div class="sc-detail-header">
                <div class="sc-detail-title-row">
                  <div>
                    <h3 class="sc-detail-name">{detailSpec.name}</h3>
                    <div class="sc-detail-slug">{detailSpec.slug}</div>
                  </div>
                  <div class="sc-detail-header-right">
                    <span class="sc-status-pill sc-status-pill--{detailSpec.status}">{detailSpec.status}</span>
                    <button
                      type="button"
                      class="sc-action-btn"
                      aria-label={`Edit ${detailSpec.name}`}
                      title="Edit"
                    >
                      <Pencil size={13} aria-hidden="true" />
                    </button>
                    <button
                      type="button"
                      class="sc-action-btn sc-action-btn--danger"
                      aria-label={`Archive ${detailSpec.name}`}
                      onclick={() => { handleArchive(detailSpec); selectedSpecSlug = null; }}
                      disabled={$archiveMut.isPending || detailSpec.status === "archived"}
                    >
                      <Trash2 size={13} aria-hidden="true" />
                    </button>
                    <button
                      type="button"
                      class="sc-btn-primary"
                      aria-label="Run now"
                      onclick={() => handlePauseToggle(detailSpec)}
                      disabled={detailSpec.status === "archived"}
                    >
                      Run now
                    </button>
                  </div>
                </div>
              </div>

              <div class="sc-detail-body">
                {#if detailSpec.description}
                  <div class="sc-detail-section">
                    <div class="sc-detail-section-title">Description</div>
                    <p class="sc-detail-text">{detailSpec.description}</p>
                  </div>
                {/if}

                <div class="sc-detail-section">
                  <div class="sc-detail-section-title">Repeats</div>
                  <p class="sc-detail-text">{frequencyHumanLabel(detailSpec)}</p>
                  {#if (detailSpec.model?.crons ?? []).length > 0}
                    <code class="sc-detail-cron">{detailSpec.model!.crons![0]}</code>
                  {/if}
                </div>

                <div class="sc-detail-section">
                  <div class="sc-detail-section-title">Permissions</div>
                  <div class="sc-detail-perms">
                    <CheckCircle2 size={13} class="sc-perms-icon" aria-hidden="true" />
                    <span>Always allowed</span>
                  </div>
                  <p class="sc-detail-muted">Approvals you grant during a run appear here.</p>
                </div>

                <div class="sc-detail-section">
                  <div class="sc-detail-section-title">Run history</div>
                  {#if specRuns.length === 0}
                    <p class="sc-empty">No runs yet for this spec.</p>
                  {:else}
                    <ul class="sc-run-list">
                      {#each specRuns as run (run.id)}
                        <li class="sc-run-item">
                          <span class="sc-status-pill sc-status-pill--{run.status === 'completed' ? 'active' : run.status === 'failed' || run.status === 'missed' ? 'archived' : 'paused'}">{run.status}</span>
                          <span class="sc-run-time">{fmtRelative(run.scheduledAt)}</span>
                          {#if run.durationMs}
                            <span class="sc-run-dur">{Math.round(run.durationMs / 1000)}s</span>
                          {/if}
                        </li>
                      {/each}
                    </ul>
                  {/if}
                </div>
              </div>
            </div>
          {:else}
            <p class="sc-empty">Spec not found.</p>
          {/if}
        {:else}
          <div class="sc-spec-table-wrap">
            <table class="sc-spec-table" aria-label="Scheduled specs">
              <thead>
                <tr>
                  <th class="sc-th sc-th--name">
                    <button type="button" class="sc-sort-btn" onclick={() => toggleSort("name")}>
                      Name {sortKey === "name" ? (sortAsc ? "↑" : "↓") : ""}
                    </button>
                  </th>
                  <th class="sc-th">Type</th>
                  <th class="sc-th">
                    <button type="button" class="sc-sort-btn" onclick={() => toggleSort("nextFireAt")}>
                      Next fire {sortKey === "nextFireAt" ? (sortAsc ? "↑" : "↓") : ""}
                    </button>
                  </th>
                  <th class="sc-th">
                    <button type="button" class="sc-sort-btn" onclick={() => toggleSort("status")}>
                      Status {sortKey === "status" ? (sortAsc ? "↑" : "↓") : ""}
                    </button>
                  </th>
                  <th class="sc-th">Agent</th>
                  <th class="sc-th">Overlap</th>
                  <th class="sc-th sc-th--actions">Actions</th>
                </tr>
              </thead>
              <tbody>
                {#each displaySpecs as spec (spec.id)}
                  <tr
                    class="sc-spec-row"
                    class:sc-spec-row--paused={spec.status === "paused"}
                    class:sc-spec-row--archived={spec.status === "archived"}
                    onclick={() => selectedSpecSlug = spec.slug}
                    style="cursor: pointer;"
                  >
                    <td class="sc-td">
                      <div class="sc-spec-name">
                        {spec.name}
                        {#if isExample}
                          <span class="sc-example-badge">Example</span>
                        {/if}
                      </div>
                      <div class="sc-spec-slug">{spec.slug}</div>
                    </td>
                    <td class="sc-td">
                      {#if spec.model?.crons?.length}
                        <span class="sc-type-badge sc-type-badge--cron" title="Cron">Cron</span>
                      {:else if spec.model?.intervals?.length}
                        <span class="sc-type-badge sc-type-badge--interval" title="Interval">Interval</span>
                      {:else if spec.model?.calendars?.length}
                        <span class="sc-type-badge sc-type-badge--calendar" title="Calendar">Calendar</span>
                      {:else}
                        <span class="sc-type-badge">—</span>
                      {/if}
                    </td>
                    <td class="sc-td sc-td--mono">{fmtNextFire(spec.nextFireAt)}</td>
                    <td class="sc-td">
                      <span class="sc-status-pill sc-status-pill--{spec.status}">{spec.status}</span>
                    </td>
                    <td class="sc-td sc-td--muted">{spec.agentSlug ?? "—"}</td>
                    <td class="sc-td">
                      <span class="sc-overlap-badge">{spec.overlapPolicy}</span>
                    </td>
                    <td class="sc-td sc-td--actions" onclick={(e) => e.stopPropagation()}>
                      <button
                        type="button"
                        class="sc-action-btn"
                        aria-label={spec.status === "paused" ? `Unpause ${spec.name}` : `Pause ${spec.name}`}
                        onclick={() => handlePauseToggle(spec)}
                        disabled={$pauseMut.isPending || $unpauseMut.isPending || spec.status === "archived"}
                      >
                        {#if spec.status === "paused"}
                          <PlayCircle size={13} aria-hidden="true" />
                        {:else}
                          <PauseCircle size={13} aria-hidden="true" />
                        {/if}
                      </button>
                      <button
                        type="button"
                        class="sc-action-btn sc-action-btn--danger"
                        aria-label={`Archive ${spec.name}`}
                        onclick={() => handleArchive(spec)}
                        disabled={$archiveMut.isPending || spec.status === "archived"}
                      >
                        <Archive size={13} aria-hidden="true" />
                      </button>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}

      <!-- CALENDAR TAB -->
      {:else if activeTab === "calendar"}
        <div class="sc-cal">
          <div class="sc-cal-nav" aria-label="Month navigation">
            <button type="button" class="sc-icon-btn" aria-label="Previous month" onclick={prevMonth}>&#8249;</button>
            <span class="sc-cal-month">{fmtCalendarMonth(calendarYear, calendarMonth)}</span>
            <button type="button" class="sc-icon-btn" aria-label="Next month" onclick={nextMonth}>&#8250;</button>
          </div>
          <div class="sc-cal-grid" role="grid" aria-label="Monthly schedule view">
            {#each ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"] as dow}
              <div class="sc-cal-dow" role="columnheader">{dow}</div>
            {/each}
            {#each calendarDays as day (day.key)}
              {#if day.date === null}
                <div class="sc-cal-cell sc-cal-cell--pad" role="gridcell" aria-hidden="true"></div>
              {:else}
                {@const dateKey = `${calendarYear}-${calendarMonth}-${day.date.getDate()}`}
                {@const dots = calendarSpecDots.get(dateKey) ?? []}
                <div
                  class="sc-cal-cell"
                  class:sc-cal-cell--today={day.date.toDateString() === new Date().toDateString()}
                  role="gridcell"
                  aria-label={`${day.date.toLocaleDateString()}${dots.length ? `, ${dots.length} spec${dots.length === 1 ? "" : "s"} scheduled` : ""}`}
                >
                  <span class="sc-cal-date">{day.date.getDate()}</span>
                  {#if dots.length > 0}
                    <div class="sc-cal-dots">
                      {#each dots.slice(0, 3) as slug (slug)}
                        <span class="sc-cal-dot" title={slug}></span>
                      {/each}
                      {#if dots.length > 3}
                        <span class="sc-cal-dot-more">+{dots.length - 3}</span>
                      {/if}
                    </div>
                  {/if}
                </div>
              {/if}
            {/each}
          </div>
        </div>

      <!-- TIMELINE TAB -->
      {:else}
        <header class="sc-section-header" style="margin-top:0.5rem">
          <span class="sc-section-meta">{displayRuns.length} runs · {isExample ? "example" : "24h"}</span>
        </header>
        {#if displayGroupedRuns.length === 0}
          <p class="sc-empty">No runs in the last 24 hours.</p>
        {:else}
          <ul class="sc-timeline">
            {#each displayGroupedRuns as group (group.slug)}
              <li class="sc-timeline-row">
                <div class="sc-timeline-label">{group.slug}</div>
                <div class="sc-timeline-track">
                  {#each group.runs as run (run.id)}
                    <span
                      class="sc-tick {statusClass(run.status)}"
                      aria-label={`${run.status} run at ${fmtRelative(run.scheduledAt)}`}
                    >
                      <title>{run.status} · scheduled {fmtRelative(run.scheduledAt)}{run.latenessMs ? ` · late ${run.latenessMs}ms` : ""}</title>
                    </span>
                  {/each}
                </div>
              </li>
            {/each}
          </ul>
        {/if}
      {/if}
    </section>

    <!-- Overlap detection (hide in spec detail view) -->
    {#if selectedSpecSlug}{:else}
    <section class="sc-section" aria-labelledby="sc-overlap-label">
      <header class="sc-section-header">
        <h2 class="sc-section-title" id="sc-overlap-label">
          <AlertTriangle size={14} aria-hidden="true" />
          Overlap detection
        </h2>
        <span class="sc-section-meta">{overlaps.length} collisions</span>
      </header>
      {#if overlaps.length === 0}
        <p class="sc-empty">No overlaps detected. Good — no two ticks fired into the same window.</p>
      {:else}
        <ul class="sc-overlap-list">
          {#each overlaps as overlap (overlap.incomingRunId)}
            <li class="sc-overlap">
              <div class="sc-overlap-row">
                <span class="sc-overlap-spec">{overlap.specSlug ?? overlap.specId}</span>
                <span class="sc-overlap-gap">gap {overlap.gapSeconds}s</span>
                <span class="sc-overlap-time">{fmtRelative(overlap.detectedAt)}</span>
              </div>
            </li>
          {/each}
        </ul>
      {/if}
    </section>
    {/if}
  {/if}
</div>

<!-- ── Create Modal ──────────────────────────────────────────────────────── -->
{#if showCreateModal}
  <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
  <div
    class="sc-modal-backdrop"
    role="dialog"
    aria-modal="true"
    aria-labelledby="sc-modal-title"
    onkeydown={handleModalKeydown}
  >
    <div
      class="sc-modal-backdrop-click"
      onclick={closeModal}
      role="presentation"
    ></div>
    <div class="sc-modal">
      <header class="sc-modal-header">
        <h2 class="sc-modal-title" id="sc-modal-title">New scheduled task</h2>
        <button
          type="button"
          class="sc-icon-btn"
          aria-label="Close modal"
          onclick={closeModal}
        >
          <XCircle size={15} aria-hidden="true" />
        </button>
      </header>

      <form class="sc-modal-form" onsubmit={(e) => { e.preventDefault(); handleCreateSubmit(); }}>
        <!-- Name -->
        <div class="sc-form-row">
          <label class="sc-label" for="sc-m-name">Name <span class="sc-req">*</span></label>
          <input
            id="sc-m-name"
            class="sc-input"
            type="text"
            placeholder="daily-briefing"
            bind:value={formName}
            aria-required="true"
            autofocus
          />
        </div>

        <!-- Description -->
        <div class="sc-form-row">
          <label class="sc-label" for="sc-m-desc">Description</label>
          <input
            id="sc-m-desc"
            class="sc-input"
            type="text"
            placeholder="Summarize my calendar and inbox for the day"
            bind:value={formDescription}
          />
        </div>

        <!-- Prompt -->
        <div class="sc-form-row">
          <label class="sc-label" for="sc-m-prompt">Prompt <span class="sc-req">*</span></label>
          <textarea
            id="sc-m-prompt"
            class="sc-textarea"
            rows={5}
            placeholder="Check my Google Calendar for today's meetings and summarize my unread emails. Highlight anything urgent."
            bind:value={formPrompt}
            aria-required="true"
          ></textarea>
        </div>

        <!-- Prompt action bar -->
        <div class="sc-prompt-bar">
          <!-- Workspace picker -->
          <select
            class="sc-prompt-select"
            bind:value={formWorkspaceSlug}
            aria-label="Work in a project"
          >
            <option value="">Work in a project</option>
            {#each workspaces as ws (ws.slug)}
              <option value={ws.slug}>{ws.name}</option>
            {/each}
            <option value="__folder__">Choose a different folder…</option>
          </select>

          <!-- Agent picker -->
          <select
            class="sc-prompt-select"
            bind:value={formAgentSlug}
            aria-label="Agent"
          >
            <option value="">Select agent</option>
            {#each hiredAgents as agent (agent.slug)}
              <option value={agent.slug}>{agent.name}</option>
            {/each}
          </select>

          <!-- Permission mode -->
          <select
            class="sc-prompt-select"
            bind:value={formPermissionMode}
            aria-label="Permission mode"
          >
            <option value="ask">Ask before acting</option>
            <option value="auto">Act without asking</option>
          </select>

          <!-- Runtime harness picker (live from detected runtimes) -->
          <select
            class="sc-prompt-select"
            bind:value={formModel}
            aria-label="Runtime"
          >
            <option value="">Runtime</option>
            {#each installedRuntimes as rt (rt.type)}
              <option value={rt.type}>{rt.name}{rt.version ? ` (${rt.version})` : ''}</option>
            {/each}
          </select>
        </div>

        <!-- Frequency -->
        <div class="sc-form-row">
          <label class="sc-label" for="sc-m-freq">Frequency</label>
          <select id="sc-m-freq" class="sc-select" bind:value={formFrequency} aria-label="Frequency">
            {#each Object.entries(FREQUENCY_LABELS) as [val, label] (val)}
              <option value={val}>{label}</option>
            {/each}
          </select>
        </div>

        {#if formFrequency === "custom"}
          <div class="sc-form-row">
            <label class="sc-label" for="sc-m-cron">Cron expression</label>
            <input
              id="sc-m-cron"
              class="sc-input sc-mono"
              type="text"
              placeholder="0 9 * * 1-5"
              bind:value={formCustomCron}
              aria-label="Custom cron expression"
            />
          </div>
        {/if}

        {#if formError}
          <p class="sc-form-error" role="alert">{formError}</p>
        {/if}

        <div class="sc-modal-footer">
          <button type="button" class="sc-btn-ghost" onclick={closeModal}>Cancel</button>
          <button type="submit" class="sc-btn-primary" disabled={formSubmitting}>
            {formSubmitting ? "Saving…" : "Save"}
          </button>
        </div>
      </form>
    </div>
  </div>
{/if}

<style>
  .sc-page {
    padding: 1.5rem 2rem 4rem;
    max-width: 1200px;
    margin: 0 auto;
    color: var(--cnp-fg);
  }

  .sc-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .sc-header-left {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .sc-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 2rem;
    font-weight: 500;
    letter-spacing: -0.025em;
    margin: 0;
  }

  .sc-subtitle {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .sc-badge {
    color: #dc2626;
    font-weight: 500;
  }

  .sc-settings-link {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.4rem 0.75rem;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    color: var(--cnp-fg-muted);
    text-decoration: none;
    font-size: 0.8rem;
    transition: color 0.15s, border-color 0.15s;
  }

  .sc-settings-link:hover {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .sc-incident-banner {
    border: 1px solid color-mix(in oklch, #dc2626 40%, var(--cnp-border));
    background: color-mix(in oklch, #dc2626 6%, var(--cnp-bg));
    border-radius: 8px;
    padding: 1rem 1.25rem;
    margin-bottom: 1.25rem;
  }

  .sc-incident-banner-header {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    color: #dc2626;
    margin-bottom: 0.5rem;
  }

  .sc-incident-banner-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .sc-incident-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .sc-incident {
    padding: 0.65rem 0.85rem;
    border: 1px solid var(--cnp-border);
    border-left-width: 3px;
    border-radius: 4px;
    background: var(--cnp-bg);
    position: relative;
  }

  .sc-incident-row {
    display: flex;
    gap: 0.5rem;
    font-size: 0.7rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
    margin-bottom: 0.25rem;
  }

  .sc-incident-summary {
    font-size: 0.9rem;
    font-weight: 500;
  }

  .sc-incident-spec {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    font-family: var(--cnp-font-mono, monospace);
    margin-top: 0.2rem;
  }

  .sc-incident-actions {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
  }

  .sc-incident-ack {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.2rem 0.5rem;
    font-size: 0.7rem;
    cursor: pointer;
    font-family: inherit;
  }

  .sc-incident-ack:hover:not(:disabled) {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .sc-sev-info {
    border-left-color: var(--cnp-fg-muted);
  }

  .sc-sev-medium {
    border-left-color: #d97706;
  }

  .sc-sev-high {
    border-left-color: #dc2626;
  }

  .sc-sev-critical {
    border-left-color: #dc2626;
    background: color-mix(in oklch, #dc2626 8%, var(--cnp-bg));
  }

  .sc-loading {
    margin-top: 1rem;
  }

  .sc-tiles {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
    gap: 0.75rem;
    margin-bottom: 1.5rem;
  }

  .sc-tile {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 1rem 1.25rem;
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
  }

  .sc-tile__icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    color: var(--cnp-accent);
    background: color-mix(in oklch, var(--cnp-accent) 12%, transparent);
    border-radius: 6px;
  }

  .sc-tile__icon--ok {
    color: #059669;
    background: color-mix(in oklch, #059669 14%, transparent);
  }

  .sc-tile__icon--warn {
    color: #d97706;
    background: color-mix(in oklch, #d97706 14%, transparent);
  }

  .sc-tile__icon--err {
    color: #dc2626;
    background: color-mix(in oklch, #dc2626 14%, transparent);
  }

  .sc-tile__body {
    display: flex;
    flex-direction: column;
    gap: 0.1rem;
    min-width: 0;
  }

  .sc-tile__label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sc-tile__value {
    font-size: 1.5rem;
    font-weight: 500;
    font-feature-settings: "tnum";
  }

  .sc-chart-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .sc-chart-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 0.75rem;
  }

  .sc-chart-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .sc-chart-legend {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
  }

  .sc-legend {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
  }

  .sc-legend-dot {
    width: 8px;
    height: 8px;
    border-radius: 2px;
    background: var(--cnp-accent);
  }

  .sc-legend-dot.bad {
    background: #dc2626;
  }

  .sc-chart-empty {
    padding: 1.5rem 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    text-align: center;
  }

  .sc-heat-bar {
    fill: var(--cnp-accent);
    opacity: 0.85;
  }

  .sc-heat-bar--bad {
    fill: #dc2626;
    opacity: 0.85;
  }

  .sc-section {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .sc-section-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .sc-section-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .sc-section-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .sc-empty {
    padding: 1rem 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .sc-empty a {
    color: var(--cnp-accent);
  }

  .sc-spec-list,
  .sc-overlap-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
  }

  .sc-spec {
    display: grid;
    grid-template-columns: 1fr auto;
    grid-template-rows: auto auto;
    gap: 0.2rem 1rem;
    padding: 0.75rem 1rem;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    background: var(--cnp-bg);
  }

  .sc-spec.paused {
    opacity: 0.6;
  }

  .sc-spec-name {
    grid-column: 1;
    grid-row: 1;
    font-weight: 500;
    font-size: 0.9rem;
  }

  .sc-spec-meta {
    grid-column: 1;
    grid-row: 2;
    display: flex;
    gap: 0.4rem;
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
  }

  .sc-spec-slug {
    font-family: var(--cnp-font-mono, monospace);
  }

  .sc-spec-failing {
    color: #dc2626;
  }

  .sc-spec-side {
    grid-column: 2;
    grid-row: 1 / span 2;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .sc-spec-fire {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
    font-feature-settings: "tnum";
  }

  .sc-spec-toggle {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.2rem 0.4rem;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
  }

  .sc-spec-toggle:hover:not(:disabled) {
    color: var(--cnp-fg);
    border-color: var(--cnp-fg-muted);
  }

  .sc-timeline {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .sc-timeline-row {
    display: grid;
    grid-template-columns: 180px 1fr;
    gap: 0.75rem;
    align-items: center;
  }

  .sc-timeline-label {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .sc-timeline-track {
    display: flex;
    gap: 2px;
    flex-wrap: wrap;
  }

  .sc-tick {
    display: inline-block;
    width: 8px;
    height: 14px;
    border-radius: 2px;
    background: var(--cnp-fg-muted);
    cursor: help;
  }

  .sc-st-completed {
    background: #059669;
  }

  .sc-st-running {
    background: var(--cnp-accent);
    animation: sc-pulse 1.5s ease-in-out infinite;
  }

  @keyframes sc-pulse {
    0%, 100% { opacity: 0.7; }
    50% { opacity: 1; }
  }

  .sc-st-enqueued {
    background: var(--cnp-fg-muted);
  }

  .sc-st-failed {
    background: #dc2626;
  }

  .sc-st-late {
    background: #d97706;
  }

  .sc-st-missed {
    background: #dc2626;
    opacity: 0.5;
  }

  .sc-st-skipped-overlap {
    background: #d97706;
    opacity: 0.5;
  }

  .sc-st-cancelled {
    background: var(--cnp-fg-muted);
    opacity: 0.4;
  }

  .sc-overlap {
    padding: 0.5rem 1rem;
    border: 1px solid color-mix(in oklch, #d97706 30%, var(--cnp-border));
    border-radius: 4px;
    background: color-mix(in oklch, #d97706 4%, var(--cnp-bg));
  }

  .sc-overlap-row {
    display: flex;
    gap: 0.5rem;
    font-size: 0.85rem;
  }

  .sc-overlap-spec {
    font-family: var(--cnp-font-mono, monospace);
    font-weight: 500;
  }

  .sc-overlap-gap {
    color: #d97706;
  }

  .sc-overlap-time {
    margin-left: auto;
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
  }

  /* ── Header actions ──────────────────────────────────────────────────────── */

  .sc-header-actions {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .sc-btn-primary {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.4rem 0.85rem;
    background: var(--cnp-accent);
    color: #fff;
    border: none;
    border-radius: 6px;
    font-size: 0.8rem;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: opacity 0.15s;
  }

  .sc-btn-primary:hover:not(:disabled) { opacity: 0.88; }
  .sc-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

  .sc-btn-ghost {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    padding: 0.4rem 0.85rem;
    background: transparent;
    color: var(--cnp-fg-muted);
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    font-size: 0.8rem;
    font-family: inherit;
    cursor: pointer;
    transition: color 0.15s, border-color 0.15s;
  }

  .sc-btn-ghost:hover { color: var(--cnp-fg); border-color: var(--cnp-fg-muted); }

  .sc-icon-btn {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.25rem 0.4rem;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    font-family: inherit;
    font-size: 1rem;
    line-height: 1;
    transition: color 0.15s, border-color 0.15s;
  }

  .sc-icon-btn:hover { color: var(--cnp-fg); border-color: var(--cnp-fg-muted); }

  /* ── Create form card ────────────────────────────────────────────────────── */

  .sc-create-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-accent);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1.5rem;
  }

  .sc-form {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    margin-top: 0.75rem;
  }

  .sc-form-divider {
    height: 1px;
    background: var(--cnp-border);
    margin: 0.25rem 0;
  }

  .sc-form-row {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .sc-form-2col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }

  .sc-label {
    font-size: 0.78rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sc-req { color: #dc2626; }

  .sc-input {
    padding: 0.4rem 0.65rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 5px;
    color: var(--cnp-fg);
    font-size: 0.875rem;
    font-family: inherit;
    outline: none;
    transition: border-color 0.15s;
    width: 100%;
    box-sizing: border-box;
  }

  .sc-input:focus { border-color: var(--cnp-accent); }
  .sc-input--sm { max-width: 120px; }
  .sc-mono { font-family: var(--cnp-font-mono, monospace); }

  .sc-select {
    padding: 0.4rem 0.65rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 5px;
    color: var(--cnp-fg);
    font-size: 0.875rem;
    font-family: inherit;
    outline: none;
    width: 100%;
    box-sizing: border-box;
  }

  .sc-select:focus { border-color: var(--cnp-accent); }
  .sc-select--sm { max-width: 120px; width: auto; }

  .sc-input-group {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .sc-input-hint {
    font-size: 0.75rem;
    color: var(--cnp-accent);
  }

  .sc-inline-group {
    display: flex;
    gap: 0.5rem;
    align-items: center;
  }

  .sc-type-tabs {
    display: flex;
    gap: 0;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    overflow: hidden;
    width: fit-content;
  }

  .sc-type-tab {
    padding: 0.35rem 0.9rem;
    background: transparent;
    border: none;
    border-right: 1px solid var(--cnp-border);
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .sc-type-tab:last-child { border-right: none; }

  .sc-type-tab.active {
    background: var(--cnp-accent);
    color: #fff;
  }

  .sc-collapse-toggle {
    background: transparent;
    border: none;
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
    font-family: inherit;
    cursor: pointer;
    text-align: left;
    padding: 0;
  }

  .sc-collapse-toggle:hover { color: var(--cnp-fg); }

  .sc-skips { margin-top: 0.25rem; }

  .sc-form-error {
    color: #dc2626;
    font-size: 0.8rem;
    margin: 0;
  }

  .sc-form-actions {
    display: flex;
    gap: 0.5rem;
    margin-top: 0.25rem;
  }

  /* ── Tab strip ───────────────────────────────────────────────────────────── */

  .sc-tab-strip {
    display: flex;
    gap: 0;
    border: 1px solid var(--cnp-border);
    border-radius: 6px;
    overflow: hidden;
  }

  .sc-tab {
    padding: 0.3rem 0.8rem;
    background: transparent;
    border: none;
    border-right: 1px solid var(--cnp-border);
    color: var(--cnp-fg-muted);
    font-size: 0.78rem;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s, color 0.15s;
  }

  .sc-tab:last-child { border-right: none; }

  .sc-tab.active {
    background: color-mix(in oklch, var(--cnp-accent) 14%, var(--cnp-bg-elev));
    color: var(--cnp-fg);
    font-weight: 500;
  }

  /* ── Spec table ──────────────────────────────────────────────────────────── */

  .sc-spec-table-wrap {
    overflow-x: auto;
    margin: 0 -0.25rem;
  }

  .sc-spec-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .sc-th {
    padding: 0.5rem 0.75rem;
    text-align: left;
    font-size: 0.72rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--cnp-fg-muted);
    border-bottom: 1px solid var(--cnp-border);
    white-space: nowrap;
  }

  .sc-th--actions { text-align: right; }

  .sc-sort-btn {
    background: transparent;
    border: none;
    color: inherit;
    font: inherit;
    cursor: pointer;
    padding: 0;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .sc-sort-btn:hover { color: var(--cnp-fg); }

  .sc-spec-row td { border-bottom: 1px solid color-mix(in oklch, var(--cnp-border) 50%, transparent); }
  .sc-spec-row:last-child td { border-bottom: none; }
  .sc-spec-row--paused { opacity: 0.65; }
  .sc-spec-row--archived { opacity: 0.4; }

  .sc-td {
    padding: 0.65rem 0.75rem;
    vertical-align: middle;
  }

  .sc-td--mono { font-family: var(--cnp-font-mono, monospace); font-size: 0.8rem; }
  .sc-td--muted { color: var(--cnp-fg-muted); font-size: 0.82rem; }

  .sc-td--actions {
    text-align: right;
    white-space: nowrap;
  }

  .sc-type-badge {
    display: inline-block;
    padding: 0.15rem 0.45rem;
    border-radius: 4px;
    font-size: 0.7rem;
    font-weight: 500;
    background: color-mix(in oklch, var(--cnp-fg-muted) 12%, transparent);
    color: var(--cnp-fg-muted);
  }

  .sc-type-badge--cron { background: color-mix(in oklch, var(--cnp-accent) 14%, transparent); color: var(--cnp-accent); }
  .sc-type-badge--interval { background: color-mix(in oklch, #059669 14%, transparent); color: #059669; }
  .sc-type-badge--calendar { background: color-mix(in oklch, #d97706 14%, transparent); color: #d97706; }

  .sc-status-pill {
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 99px;
    font-size: 0.7rem;
    font-weight: 500;
  }

  .sc-status-pill--active { background: color-mix(in oklch, #059669 14%, transparent); color: #059669; }
  .sc-status-pill--paused { background: color-mix(in oklch, #d97706 14%, transparent); color: #d97706; }
  .sc-status-pill--archived { background: color-mix(in oklch, var(--cnp-fg-muted) 12%, transparent); color: var(--cnp-fg-muted); }

  .sc-overlap-badge {
    font-size: 0.72rem;
    font-family: var(--cnp-font-mono, monospace);
    color: var(--cnp-fg-muted);
  }

  .sc-action-btn {
    background: transparent;
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg-muted);
    padding: 0.2rem 0.4rem;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    font-family: inherit;
    margin-left: 0.25rem;
    transition: color 0.15s, border-color 0.15s;
  }

  .sc-action-btn:hover:not(:disabled) { color: var(--cnp-fg); border-color: var(--cnp-fg-muted); }
  .sc-action-btn:disabled { opacity: 0.4; cursor: not-allowed; }
  .sc-action-btn--danger:hover:not(:disabled) { color: #dc2626; border-color: #dc2626; }

  /* ── Calendar month view ─────────────────────────────────────────────────── */

  .sc-cal {
    margin-top: 0.5rem;
  }

  .sc-cal-nav {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .sc-cal-month {
    font-size: 0.9rem;
    font-weight: 500;
    min-width: 160px;
    text-align: center;
  }

  .sc-cal-grid {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 2px;
  }

  .sc-cal-dow {
    text-align: center;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--cnp-fg-muted);
    padding: 0.25rem 0;
  }

  .sc-cal-cell {
    min-height: 56px;
    padding: 0.3rem 0.4rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .sc-cal-cell--pad {
    background: transparent;
    border-color: transparent;
  }

  .sc-cal-cell--today {
    border-color: var(--cnp-accent);
  }

  .sc-cal-date {
    font-size: 0.78rem;
    font-weight: 500;
    color: var(--cnp-fg-muted);
  }

  .sc-cal-cell--today .sc-cal-date {
    color: var(--cnp-accent);
  }

  .sc-cal-dots {
    display: flex;
    flex-wrap: wrap;
    gap: 2px;
    align-items: center;
  }

  .sc-cal-dot {
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--cnp-accent);
    display: inline-block;
  }

  .sc-cal-dot-more {
    font-size: 0.65rem;
    color: var(--cnp-fg-muted);
  }

  /* ── Create modal ────────────────────────────────────────────────────────── */

  .sc-modal-backdrop {
    position: fixed;
    inset: 0;
    z-index: 50;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }

  .sc-modal-backdrop-click {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.55);
    backdrop-filter: blur(4px);
    -webkit-backdrop-filter: blur(4px);
  }

  .sc-modal {
    position: relative;
    z-index: 1;
    width: 100%;
    max-width: 640px;
    max-height: 90vh;
    overflow-y: auto;
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 12px;
    box-shadow: 0 24px 64px rgba(0, 0, 0, 0.3);
  }

  .sc-modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1.25rem 1.5rem 0;
  }

  .sc-modal-title {
    font-size: 1rem;
    font-weight: 600;
    margin: 0;
  }

  .sc-modal-form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    padding: 1rem 1.5rem 1.5rem;
  }

  .sc-textarea {
    padding: 0.5rem 0.65rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 5px;
    color: var(--cnp-fg);
    font-size: 0.875rem;
    font-family: inherit;
    outline: none;
    transition: border-color 0.15s;
    width: 100%;
    box-sizing: border-box;
    resize: vertical;
    line-height: 1.55;
  }

  .sc-textarea:focus { border-color: var(--cnp-accent); }

  .sc-prompt-bar {
    display: flex;
    gap: 0.5rem;
    flex-wrap: wrap;
  }

  .sc-prompt-select {
    flex: 1;
    min-width: 140px;
    padding: 0.35rem 0.6rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 5px;
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
    font-family: inherit;
    outline: none;
    cursor: pointer;
  }

  .sc-prompt-select:focus { border-color: var(--cnp-accent); }

  .sc-modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
    padding-top: 0.25rem;
  }

  /* ── Spec detail view ────────────────────────────────────────────────────── */

  .sc-detail {
    padding: 0.25rem 0;
  }

  .sc-detail-back {
    display: inline-flex;
    align-items: center;
    gap: 0.35rem;
    background: transparent;
    border: none;
    color: var(--cnp-accent);
    font-size: 0.8rem;
    font-family: inherit;
    cursor: pointer;
    padding: 0;
    margin-bottom: 1.25rem;
    transition: opacity 0.15s;
  }

  .sc-detail-back:hover { opacity: 0.75; }

  .sc-detail-header {
    margin-bottom: 1.5rem;
  }

  .sc-detail-title-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .sc-detail-name {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0 0 0.25rem 0;
  }

  .sc-detail-slug {
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.78rem;
    color: var(--cnp-fg-muted);
  }

  .sc-detail-header-right {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    flex-shrink: 0;
  }

  .sc-detail-body {
    display: flex;
    flex-direction: column;
    gap: 1.25rem;
  }

  .sc-detail-section {
    border-top: 1px solid var(--cnp-border);
    padding-top: 1rem;
  }

  .sc-detail-section-title {
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--cnp-fg-muted);
    margin-bottom: 0.5rem;
  }

  .sc-detail-text {
    margin: 0;
    font-size: 0.9rem;
    line-height: 1.55;
  }

  .sc-detail-muted {
    margin: 0.35rem 0 0 0;
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .sc-detail-cron {
    display: inline-block;
    margin-top: 0.35rem;
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.78rem;
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 3px;
    padding: 0.15rem 0.4rem;
    color: var(--cnp-fg-muted);
  }

  .sc-detail-perms {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.9rem;
    color: #059669;
  }

  .sc-run-list {
    list-style: none;
    padding: 0;
    margin: 0;
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }

  .sc-run-item {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    font-size: 0.83rem;
  }

  .sc-run-time {
    color: var(--cnp-fg-muted);
    font-size: 0.78rem;
  }

  .sc-run-dur {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    font-family: var(--cnp-font-mono, monospace);
  }

  /* ── Info + example banners ──────────────────────────────────────────────── */

  .sc-info-banner {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.55rem 0.85rem;
    background: color-mix(in oklch, var(--cnp-accent) 7%, var(--cnp-bg-elev));
    border: 1px solid color-mix(in oklch, var(--cnp-accent) 20%, var(--cnp-border));
    border-radius: 7px;
    font-size: 0.82rem;
    color: var(--cnp-fg-muted);
    margin-bottom: 1rem;
  }

  .sc-info-banner strong { color: var(--cnp-fg); }

  .sc-example-banner {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.55rem 0.85rem;
    background: color-mix(in oklch, #d97706 7%, var(--cnp-bg-elev));
    border: 1px solid color-mix(in oklch, #d97706 25%, var(--cnp-border));
    border-radius: 7px;
    font-size: 0.82rem;
    color: #d97706;
    margin-bottom: 1rem;
  }

  .sc-example-badge {
    display: inline-block;
    padding: 0.1rem 0.4rem;
    border-radius: 4px;
    font-size: 0.65rem;
    font-weight: 600;
    background: color-mix(in oklch, #d97706 14%, transparent);
    color: #d97706;
    margin-left: 0.4rem;
    vertical-align: middle;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
</style>
