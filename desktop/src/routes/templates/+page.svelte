<script lang="ts">
  /**
   * /templates — Template Composer gallery.
   * Powered by Forge (the Template Composer agent) via /api/v1/templates/*.
   *
   * Sections:
   *   1. Header — title + search + new template link
   *   2. Kind tabs — workspace / persona / workflow / all
   *   3. Filters — verified-only toggle + tag chips
   *   4. Grid — curated tile gallery (DB-backed, popularity-ordered)
   *   5. Instantiate dialog — params form + POST to instantiate endpoint
   *
   * CSS prefix: tg- (template gallery)
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
    BadgeCheck,
    LayoutTemplate,
    Plus,
    Search,
    Sparkles,
    Wand2,
  } from "lucide-svelte";
  import {
    instantiateTemplate,
    templatesQuery,
  } from "$lib/api/queries/templates.js";
  import SkeletonList from "$lib/design/patterns/SkeletonList.svelte";
  import type {
    InstantiateRequest,
    Template,
    TemplateKind,
    TemplateParameter,
  } from "$lib/domain/templates/types.js";

  const qc = useQueryClient();

  // ── State ──────────────────────────────────────────────────────────────────

  let search = $state("");
  let selectedKind = $state<TemplateKind | "all">("all");
  let verifiedOnly = $state(false);
  let activeTemplate = $state<Template | null>(null);
  let paramValues = $state<Record<string, string>>({});
  let targetWorkspace = $state("");
  let instantiateError = $state<string | null>(null);
  let lastResultMessage = $state<string | null>(null);

  // ── Query ──────────────────────────────────────────────────────────────────

  const queryStore = writable(
    untrack(() => templatesQuery({ limit: 200 }) as CreateQueryOptions<Template[]>),
  );
  const templatesQ = createQuery<Template[]>(queryStore);

  const allTemplates = $derived($templatesQ.data ?? []);

  const KIND_TABS: Array<{ value: TemplateKind | "all"; label: string }> = [
    { value: "all", label: "All" },
    { value: "workspace", label: "Workspace" },
    { value: "persona", label: "Persona" },
    { value: "workflow", label: "Workflow" },
  ];

  const filtered = $derived(
    allTemplates.filter((t) => {
      const kindOk = selectedKind === "all" || t.kind === selectedKind;
      const verifiedOk = !verifiedOnly || t.verified;
      const q = search.trim().toLowerCase();
      const searchOk =
        q === "" ||
        t.name.toLowerCase().includes(q) ||
        (t.description?.toLowerCase() ?? "").includes(q) ||
        t.slug.toLowerCase().includes(q) ||
        t.tags.some((tag) => tag.toLowerCase().includes(q));
      return kindOk && verifiedOk && searchOk;
    }),
  );

  // ── Instantiate dialog ─────────────────────────────────────────────────────

  function openInstantiateDialog(template: Template) {
    activeTemplate = template;
    paramValues = {};
    targetWorkspace = "";
    instantiateError = null;
    lastResultMessage = null;

    // Pre-fill defaults from parameter schema
    for (const [name, decl] of Object.entries(template.parameters ?? {})) {
      if (decl?.default !== undefined) {
        paramValues[name] = String(decl.default ?? "");
      }
    }
  }

  function closeInstantiateDialog() {
    activeTemplate = null;
    paramValues = {};
    targetWorkspace = "";
    instantiateError = null;
  }

  const instantiateMut = createMutation({
    mutationFn: ({ slug, body }: { slug: string; body: InstantiateRequest }) =>
      instantiateTemplate(slug, body),
    onSuccess: (inst) => {
      lastResultMessage = `Instantiated ${inst.templateSlug}@${inst.templateVersion} — ${inst.filesWritten} files, ${inst.agentsCreated} agents, ${inst.skillsInstalled} skills`;
      qc.invalidateQueries({ queryKey: ["templates"] });
      closeInstantiateDialog();
    },
    onError: (err: Error) => {
      instantiateError = err.message;
    },
  });

  function submitInstantiate(e: Event) {
    e.preventDefault();
    if (!activeTemplate) return;
    instantiateError = null;

    // Verify required params are present
    const required = Object.entries(activeTemplate.parameters ?? {})
      .filter(([, decl]) => decl?.required)
      .map(([name]) => name);

    const missing = required.filter(
      (name) => !paramValues[name] || paramValues[name].trim() === "",
    );

    if (missing.length > 0) {
      instantiateError = `Missing required: ${missing.join(", ")}`;
      return;
    }

    $instantiateMut.mutate({
      slug: activeTemplate.slug,
      body: {
        targetWorkspaceSlug: targetWorkspace.trim() || undefined,
        params: paramValues,
        instantiatedBy: "user",
      },
    });
  }

  function paramKeys(template: Template): Array<[string, TemplateParameter]> {
    return Object.entries(template.parameters ?? {});
  }

  // ── Kind icon mapping ──────────────────────────────────────────────────────

  function kindIcon(kind: TemplateKind): string {
    if (kind === "workspace") return "W";
    if (kind === "persona") return "P";
    if (kind === "workflow") return "F";
    return "?";
  }

  function kindBadgeClass(kind: TemplateKind): string {
    return `tg-badge tg-badge-${kind}`;
  }
</script>

<div class="tg-page">
  <!-- Header -->
  <header class="tg-header">
    <div class="tg-title-row">
      <div class="tg-title-block">
        <h1 class="tg-title">Templates</h1>
        <span class="tg-subtitle">
          Powered by Forge · {allTemplates.length}
          {allTemplates.length === 1 ? "template" : "templates"} available
        </span>
      </div>
      <a href="/settings/templates" class="tg-settings-link">
        <Plus size={14} aria-hidden="true" />
        Manage templates
      </a>
    </div>

    <div class="tg-search-wrap">
      <Search size={13} class="tg-search-icon" aria-hidden="true" />
      <input
        class="tg-search"
        type="search"
        placeholder="Search templates..."
        bind:value={search}
        aria-label="Search templates"
      />
    </div>
  </header>

  <!-- Kind tabs -->
  <div class="tg-tabs" role="group" aria-label="Filter by kind">
    {#each KIND_TABS as tab (tab.value)}
      <button
        class="btn-pill btn-pill-xs tg-pill"
        class:tg-pill--active={selectedKind === tab.value}
        onclick={() => {
          selectedKind = tab.value;
        }}
        aria-pressed={selectedKind === tab.value}
      >
        {tab.label}
      </button>
    {/each}
    <span class="tg-tabs-sep" aria-hidden="true">·</span>
    <label class="tg-toggle">
      <input type="checkbox" bind:checked={verifiedOnly} />
      <BadgeCheck size={12} aria-hidden="true" />
      Verified only
    </label>
  </div>

  {#if lastResultMessage}
    <div class="tg-toast" role="status">
      <Sparkles size={12} aria-hidden="true" />
      {lastResultMessage}
    </div>
  {/if}

  <!-- Grid -->
  <main class="tg-grid-wrap">
    {#if $templatesQ.isLoading}
      <SkeletonList count={6} height="6rem" gap="0.75rem" />
    {:else if filtered.length === 0}
      <div class="tg-empty">
        <LayoutTemplate size={24} class="tg-empty__icon" aria-hidden="true" />
        <p class="tg-empty__text">
          {search
            ? `No templates match "${search}".`
            : "No templates available yet."}
        </p>
      </div>
    {:else}
      <div class="tg-grid">
        {#each filtered as tmpl (tmpl.slug)}
          <article class="tg-card" aria-label={tmpl.name}>
            <div class="tg-card__head">
              <div class="tg-card__icon" aria-hidden="true">
                {tmpl.icon ?? kindIcon(tmpl.kind)}
              </div>
              <div class="tg-card__title-block">
                <h2 class="tg-card__name">
                  {tmpl.name}
                  {#if tmpl.verified}
                    <BadgeCheck
                      size={13}
                      class="tg-verified"
                      aria-label="Verified template"
                    />
                  {/if}
                </h2>
                <span class="tg-card__slug">{tmpl.slug}@{tmpl.version}</span>
              </div>
            </div>

            <p class="tg-card__desc">
              {tmpl.description ?? "No description."}
            </p>

            <div class="tg-card__footer">
              <div class="tg-card__meta">
                <span class={kindBadgeClass(tmpl.kind)}>{tmpl.kind}</span>
                {#if tmpl.popularityCount > 0}
                  <span class="tg-card__pop">
                    used {tmpl.popularityCount}×
                  </span>
                {/if}
              </div>
              <button
                type="button"
                class="btn-pill btn-pill-sm"
                onclick={() => openInstantiateDialog(tmpl)}
                aria-label={`Use template ${tmpl.name}`}
              >
                Use template
              </button>
            </div>
          </article>
        {/each}
      </div>
    {/if}
  </main>

  <!-- Instantiate dialog -->
  {#if activeTemplate}
    <div
      class="tg-dialog-backdrop"
      role="dialog"
      aria-modal="true"
      aria-label={`Instantiate ${activeTemplate.name}`}
      onclick={(e) => {
        if (e.target === e.currentTarget) closeInstantiateDialog();
      }}
      onkeydown={(e) => {
        if (e.key === "Escape") closeInstantiateDialog();
      }}
    >
      <div class="tg-dialog">
        <header class="tg-dialog-header">
          <Wand2 size={14} aria-hidden="true" />
          <h2 class="tg-dialog-title">Use {activeTemplate.name}</h2>
        </header>

        <p class="tg-dialog-sub">
          {activeTemplate.kind} template ·
          {activeTemplate.slug}@{activeTemplate.version}
        </p>

        <form onsubmit={submitInstantiate}>
          <label class="tg-field">
            <span class="tg-field__label">Target workspace slug (optional)</span>
            <input
              type="text"
              class="tg-input"
              bind:value={targetWorkspace}
              placeholder="my-new-workspace"
            />
          </label>

          {#if paramKeys(activeTemplate).length > 0}
            <fieldset class="tg-fieldset">
              <legend class="tg-fieldset__legend">Parameters</legend>
              {#each paramKeys(activeTemplate) as [name, decl] (name)}
                <label class="tg-field">
                  <span class="tg-field__label">
                    {name}
                    {#if decl?.required}
                      <span class="tg-required" aria-label="required">*</span>
                    {/if}
                  </span>
                  <input
                    type="text"
                    class="tg-input"
                    bind:value={paramValues[name]}
                    placeholder={decl?.description ?? ""}
                    required={decl?.required}
                  />
                  {#if decl?.description}
                    <span class="tg-field__hint">{decl.description}</span>
                  {/if}
                </label>
              {/each}
            </fieldset>
          {:else}
            <p class="tg-empty-params">
              No parameters required. Click instantiate to materialize.
            </p>
          {/if}

          {#if instantiateError}
            <p class="tg-error">{instantiateError}</p>
          {/if}

          <div class="tg-dialog-actions">
            <button
              type="button"
              class="btn-pill btn-pill-sm"
              onclick={closeInstantiateDialog}
              disabled={$instantiateMut.isPending}
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-pill btn-pill-sm tg-btn-primary"
              disabled={$instantiateMut.isPending}
            >
              {$instantiateMut.isPending ? "Instantiating..." : "Instantiate"}
            </button>
          </div>
        </form>
      </div>
    </div>
  {/if}
</div>

<style>
  .tg-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  /* Header */
  .tg-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .tg-title-row {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .tg-title-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .tg-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .tg-subtitle {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  .tg-settings-link {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-1) var(--space-3);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    color: var(--fg-muted);
    text-decoration: none;
    font-size: var(--text-xs);
    transition: color var(--dur-instant) var(--ease-out),
      border-color var(--dur-instant) var(--ease-out);
  }

  .tg-settings-link:hover {
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .tg-search-wrap {
    position: relative;
    display: flex;
    align-items: center;
  }

  :global(.tg-search-icon) {
    position: absolute;
    left: var(--space-3);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .tg-search {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-2) var(--space-3) var(--space-2)
      calc(var(--space-3) + 22px);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .tg-search:focus {
    border-color: var(--border-strong);
  }

  .tg-search::placeholder {
    color: var(--fg-subtle);
  }

  /* Tabs / filters */
  .tg-tabs {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-3) var(--space-6);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .tg-tabs-sep {
    color: var(--fg-subtle);
    margin: 0 var(--space-1);
  }

  .tg-pill {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
  }

  .tg-pill:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    color: var(--fg);
  }

  .tg-pill--active {
    background: color-mix(in oklch, var(--fg) 12%, transparent 88%);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .tg-toggle {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    font-size: 11px;
    color: var(--fg-muted);
    cursor: pointer;
  }

  .tg-toggle input {
    cursor: pointer;
  }

  .tg-toast {
    margin: var(--space-3) var(--space-6) 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(0.72 0.14 290) 8%, var(--bg-inset));
    border: 1px solid color-mix(in oklch, oklch(0.72 0.14 290) 30%, var(--border));
    border-radius: var(--radius-md);
    color: var(--fg);
    font-size: var(--text-xs);
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
  }

  /* Grid */
  .tg-grid-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-5) var(--space-6);
  }

  .tg-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--space-3);
  }

  @media (max-width: 900px) {
    .tg-grid {
      grid-template-columns: repeat(2, 1fr);
    }
  }

  @media (max-width: 600px) {
    .tg-grid {
      grid-template-columns: 1fr;
    }
  }

  /* Card */
  .tg-card {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-4);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl);
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .tg-card:hover {
    border-color: var(--border-strong);
  }

  .tg-card__head {
    display: flex;
    align-items: flex-start;
    gap: var(--space-3);
  }

  .tg-card__icon {
    width: 36px;
    height: 36px;
    background: color-mix(in oklch, oklch(0.72 0.14 290) 12%, transparent 88%);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    font-weight: 700;
    color: var(--fg);
    flex-shrink: 0;
  }

  .tg-card__title-block {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .tg-card__name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
  }

  :global(.tg-verified) {
    color: oklch(0.72 0.14 290);
  }

  .tg-card__slug {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .tg-card__desc {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    line-height: 1.5;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  .tg-card__footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-top: auto;
    gap: var(--space-2);
  }

  .tg-card__meta {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    flex-wrap: wrap;
  }

  .tg-card__pop {
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .tg-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--fg-subtle);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    padding: 1px 6px;
  }

  .tg-badge-workspace {
    color: oklch(0.72 0.15 165);
  }

  .tg-badge-persona {
    color: oklch(0.72 0.14 290);
  }

  .tg-badge-workflow {
    color: oklch(0.72 0.14 60);
  }

  /* Empty state */
  .tg-empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-12) var(--space-6);
    text-align: center;
  }

  :global(.tg-empty__icon) {
    color: var(--fg-subtle);
  }

  .tg-empty__text {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    margin: 0;
  }

  /* Dialog */
  .tg-dialog-backdrop {
    position: fixed;
    inset: 0;
    background: color-mix(in oklch, black 50%, transparent 50%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 50;
    padding: var(--space-4);
  }

  .tg-dialog {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-xl);
    padding: var(--space-5);
    width: 100%;
    max-width: 500px;
    max-height: 90vh;
    overflow-y: auto;
  }

  .tg-dialog-header {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    margin-bottom: var(--space-1);
    color: var(--fg);
  }

  .tg-dialog-title {
    font-size: var(--text-lg);
    font-weight: 600;
    margin: 0;
  }

  .tg-dialog-sub {
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    margin: 0 0 var(--space-4) 0;
    font-family: var(--font-mono);
  }

  .tg-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
    margin-bottom: var(--space-3);
  }

  .tg-field__label {
    font-size: var(--text-xs);
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .tg-field__hint {
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .tg-required {
    color: oklch(0.55 0.21 25);
    margin-left: 2px;
  }

  .tg-input {
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    color: var(--fg);
    padding: var(--space-2) var(--space-3);
    font-family: inherit;
    font-size: var(--text-sm);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .tg-input:focus {
    border-color: var(--border-strong);
  }

  .tg-fieldset {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3);
    margin-bottom: var(--space-3);
  }

  .tg-fieldset__legend {
    font-size: var(--text-xs);
    color: var(--fg-muted);
    padding: 0 var(--space-1);
  }

  .tg-empty-params {
    color: var(--fg-subtle);
    font-size: var(--text-xs);
    margin: var(--space-3) 0;
  }

  .tg-error {
    color: oklch(0.55 0.21 25);
    font-size: var(--text-xs);
    margin: var(--space-2) 0;
  }

  .tg-dialog-actions {
    display: flex;
    gap: var(--space-2);
    justify-content: flex-end;
    margin-top: var(--space-4);
  }

  .tg-btn-primary {
    background: oklch(0.72 0.14 290);
    color: white;
    border-color: oklch(0.72 0.14 290);
  }

  .tg-btn-primary:hover:not(:disabled) {
    filter: brightness(1.08);
  }
</style>
