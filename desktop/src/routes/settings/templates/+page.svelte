<script lang="ts">
  /**
   * Settings › Templates — Template Composer (Forge) configuration +
   * publishing controls + default policies.
   * Reads /api/v1/templates. Posts to create, publish, and fork endpoints.
   */
  import {
    type CreateQueryOptions,
    createMutation,
    createQuery,
    useQueryClient,
  } from "@tanstack/svelte-query";
  import { writable } from "svelte/store";
  import { untrack } from "svelte";
  import { BadgeCheck, LayoutTemplate, Plus, Send } from "lucide-svelte";
  import {
    createTemplate,
    publishTemplate,
    templatesQuery,
  } from "$lib/api/queries/templates.js";
  import type {
    Template,
    TemplateCreate,
    TemplateKind,
  } from "$lib/domain/templates/types.js";

  const qc = useQueryClient();

  // ── Templates query ────────────────────────────────────────────────────────

  const queryStore = writable(
    untrack(() => templatesQuery({ limit: 200 }) as CreateQueryOptions<Template[]>),
  );
  const templatesQ = createQuery<Template[]>(queryStore);

  // ── Default policy state (persisted client-side for now) ──────────────────

  let defaultRequireVerified = $state(false);
  let defaultPublishGate = $state(true);
  let defaultRedactSecrets = $state(true);

  // ── Create form state ──────────────────────────────────────────────────────

  let creating = $state(false);
  let formSlug = $state("");
  let formName = $state("");
  let formKind = $state<TemplateKind>("workspace");
  let formDescription = $state("");
  let formTags = $state("");
  let formError = $state<string | null>(null);

  function resetForm() {
    formSlug = "";
    formName = "";
    formKind = "workspace";
    formDescription = "";
    formTags = "";
    formError = null;
  }

  const createMut = createMutation({
    mutationFn: (body: TemplateCreate) => createTemplate(body),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["templates"] });
      creating = false;
      resetForm();
    },
    onError: (err: Error) => {
      formError = err.message;
    },
  });

  function submitCreate(e: Event) {
    e.preventDefault();
    formError = null;
    if (!formSlug.trim() || !formName.trim()) {
      formError = "Slug and name are required.";
      return;
    }
    const tags = formTags
      .split(",")
      .map((t) => t.trim())
      .filter(Boolean);

    $createMut.mutate({
      slug: formSlug.trim(),
      name: formName.trim(),
      kind: formKind,
      description: formDescription.trim() || undefined,
      tags: tags.length > 0 ? tags : undefined,
    });
  }

  // ── Publish mutation ───────────────────────────────────────────────────────

  const publishMut = createMutation({
    mutationFn: ({ slug, version }: { slug: string; version?: string }) =>
      publishTemplate(slug, { version, authoredBy: "user" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["templates"] });
    },
  });

  function handlePublish(template: Template) {
    const v = window.prompt(
      `Publish ${template.name} as version (current: ${template.version}):`,
      template.version,
    );
    if (!v) return;
    $publishMut.mutate({ slug: template.slug, version: v });
  }

  // ── Derived ────────────────────────────────────────────────────────────────

  const templates = $derived($templatesQ.data ?? []);
  const verifiedCount = $derived(templates.filter((t) => t.verified).length);
  const publishedCount = $derived(templates.filter((t) => t.published).length);
</script>

<div class="st-page">
  <header class="st-header">
    <div>
      <h1 class="st-title">Templates</h1>
      <p class="st-sub">
        Forge (Template Composer) configuration · publishing controls
      </p>
    </div>
    {#if !creating}
      <button
        type="button"
        class="st-btn st-btn-primary"
        onclick={() => {
          resetForm();
          creating = true;
        }}
      >
        <Plus size={14} aria-hidden="true" />
        New template
      </button>
    {/if}
  </header>

  <!-- Forge status card -->
  <section class="st-card st-forge">
    <div class="st-forge-row">
      <span class="st-forge-emoji" aria-hidden="true">🪄</span>
      <div class="st-forge-body">
        <div class="st-forge-name">Forge</div>
        <div class="st-forge-meta">
          Heartbeat daily 6am · Budget $50/mo · Posts to #templates-feed
        </div>
      </div>
      <a href="/agents/template-composer" class="st-forge-link">View persona</a>
    </div>
  </section>

  <!-- Default policies -->
  <section class="st-card">
    <header class="st-card-header">
      <h2 class="st-card-title">Default policies</h2>
      <span class="st-local-badge">local only — backend endpoint coming soon</span>
    </header>
    <div class="st-policy-list">
      <label class="st-policy">
        <input type="checkbox" bind:checked={defaultRequireVerified} />
        <span>
          <strong>Require verified templates</strong>
          — only show verified templates in the gallery by default.
        </span>
      </label>
      <label class="st-policy">
        <input type="checkbox" bind:checked={defaultPublishGate} />
        <span>
          <strong>Publish gate</strong>
          — require explicit approval before any template can be published.
        </span>
      </label>
      <label class="st-policy">
        <input type="checkbox" bind:checked={defaultRedactSecrets} />
        <span>
          <strong>Redact secrets on fork</strong>
          — scan for credentials before saving a workspace as a template.
        </span>
      </label>
    </div>
  </section>

  <!-- Create form -->
  {#if creating}
    <section class="st-card st-form">
      <h2 class="st-form-title">New template</h2>
      <form onsubmit={submitCreate}>
        <div class="st-grid">
          <label class="st-field">
            <span class="st-label">Slug</span>
            <input
              type="text"
              class="st-input"
              bind:value={formSlug}
              placeholder="dev-shop-v2"
              required
            />
          </label>

          <label class="st-field">
            <span class="st-label">Name</span>
            <input
              type="text"
              class="st-input"
              bind:value={formName}
              placeholder="Dev Shop v2"
              required
            />
          </label>

          <label class="st-field">
            <span class="st-label">Kind</span>
            <select class="st-input" bind:value={formKind}>
              <option value="workspace">Workspace</option>
              <option value="persona">Persona</option>
              <option value="workflow">Workflow</option>
            </select>
          </label>

          <label class="st-field">
            <span class="st-label">Tags (comma-separated)</span>
            <input
              type="text"
              class="st-input"
              bind:value={formTags}
              placeholder="starter, dev, productivity"
            />
          </label>
        </div>

        <label class="st-field st-field-wide">
          <span class="st-label">Description</span>
          <textarea
            class="st-input st-textarea"
            rows="2"
            bind:value={formDescription}
            placeholder="What this template scaffolds..."
          ></textarea>
        </label>

        {#if formError}
          <p class="st-error">{formError}</p>
        {/if}

        <div class="st-actions">
          <button
            type="button"
            class="st-btn"
            onclick={() => {
              creating = false;
              resetForm();
            }}
            disabled={$createMut.isPending}
          >
            Cancel
          </button>
          <button
            type="submit"
            class="st-btn st-btn-primary"
            disabled={$createMut.isPending}
          >
            {$createMut.isPending ? "Creating..." : "Create template"}
          </button>
        </div>
      </form>
    </section>
  {/if}

  <!-- Templates list -->
  <section class="st-card">
    <header class="st-card-header">
      <h2 class="st-card-title">
        <LayoutTemplate size={14} aria-hidden="true" />
        Templates
      </h2>
      <span class="st-card-meta">
        {templates.length} total · {verifiedCount} verified ·
        {publishedCount} published
      </span>
    </header>

    {#if $templatesQ.isLoading}
      <p class="st-empty">Loading…</p>
    {:else if templates.length === 0}
      <p class="st-empty">
        No templates yet. Create one above or fork an existing workspace from
        the workspace settings page.
      </p>
    {:else}
      <table class="st-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Kind</th>
            <th>Version</th>
            <th>Status</th>
            <th>Used</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {#each templates as tmpl (tmpl.id)}
            <tr>
              <td>
                <div class="st-row-name">
                  {tmpl.name}
                  {#if tmpl.verified}
                    <BadgeCheck
                      size={12}
                      class="st-verified"
                      aria-label="Verified"
                    />
                  {/if}
                </div>
                {#if tmpl.description}
                  <div class="st-row-desc">{tmpl.description}</div>
                {/if}
                <div class="st-row-slug">{tmpl.slug}</div>
              </td>
              <td>
                <span class="st-kind st-kind-{tmpl.kind}">{tmpl.kind}</span>
              </td>
              <td>{tmpl.version}</td>
              <td>
                {tmpl.published ? "Published" : "Draft"}
              </td>
              <td>{tmpl.popularityCount}×</td>
              <td>
                <button
                  type="button"
                  class="st-btn st-btn-xs"
                  onclick={() => handlePublish(tmpl)}
                  disabled={$publishMut.isPending}
                  aria-label={`Publish ${tmpl.name}`}
                >
                  <Send size={11} aria-hidden="true" />
                  Publish
                </button>
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    {/if}
  </section>
</div>

<style>
  .st-page {
    padding: 1rem 2rem;
    max-width: 1100px;
    color: var(--cnp-fg);
  }

  .st-header {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    margin-bottom: 1.5rem;
    gap: 1rem;
  }

  .st-title {
    font-family: var(--cnp-font-serif, Georgia, serif);
    font-size: 1.5rem;
    font-weight: 500;
    letter-spacing: -0.02em;
    margin: 0 0 0.25rem 0;
  }

  .st-sub {
    margin: 0;
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
  }

  .st-card {
    background: var(--cnp-bg-elev);
    border: 1px solid var(--cnp-border);
    border-radius: 8px;
    padding: 1.25rem;
    margin-bottom: 1rem;
  }

  .st-forge {
    background: color-mix(in oklch, oklch(0.72 0.14 290) 5%, var(--cnp-bg-elev));
  }

  .st-forge-row {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .st-forge-emoji {
    font-size: 1.5rem;
  }

  .st-forge-body {
    flex: 1;
    min-width: 0;
  }

  .st-forge-name {
    font-weight: 500;
  }

  .st-forge-meta {
    color: var(--cnp-fg-muted);
    font-size: 0.8rem;
  }

  .st-forge-link {
    color: oklch(0.72 0.14 290);
    font-size: 0.8rem;
    text-decoration: none;
  }

  .st-forge-link:hover {
    text-decoration: underline;
  }

  .st-policy-list {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .st-policy {
    display: flex;
    align-items: flex-start;
    gap: 0.5rem;
    font-size: 0.85rem;
    line-height: 1.5;
    cursor: pointer;
  }

  .st-policy input {
    margin-top: 3px;
    cursor: pointer;
  }

  .st-form-title {
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0 0 1rem 0;
  }

  .st-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .st-field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .st-field-wide {
    margin-bottom: 0.75rem;
  }

  .st-label {
    font-size: 0.75rem;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }

  .st-input {
    background: var(--cnp-bg);
    border: 1px solid var(--cnp-border);
    border-radius: 4px;
    color: var(--cnp-fg);
    padding: 0.4rem 0.6rem;
    font-size: 0.85rem;
    font-family: inherit;
  }

  .st-input:focus {
    outline: none;
    border-color: oklch(0.72 0.14 290);
  }

  .st-textarea {
    resize: vertical;
    font-size: 0.85rem;
    font-family: inherit;
  }

  .st-actions {
    display: flex;
    gap: 0.5rem;
    justify-content: flex-end;
    margin-top: 1rem;
  }

  .st-btn {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem 1rem;
    border: 1px solid var(--cnp-border);
    background: var(--cnp-bg);
    color: var(--cnp-fg);
    border-radius: 4px;
    font-size: 0.85rem;
    cursor: pointer;
    font-family: inherit;
  }

  .st-btn-xs {
    padding: 0.3rem 0.6rem;
    font-size: 0.75rem;
  }

  .st-btn:hover:not(:disabled) {
    border-color: var(--cnp-fg-muted);
  }

  .st-btn-primary {
    background: oklch(0.72 0.14 290);
    color: #fff;
    border-color: oklch(0.72 0.14 290);
  }

  .st-btn-primary:hover:not(:disabled) {
    filter: brightness(1.1);
  }

  .st-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .st-error {
    color: #dc2626;
    font-size: 0.85rem;
    margin: 0.5rem 0 0 0;
  }

  .st-card-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 0.75rem;
  }

  .st-card-title {
    display: inline-flex;
    align-items: center;
    gap: 0.4rem;
    font-size: 0.95rem;
    font-weight: 500;
    margin: 0;
  }

  .st-card-meta {
    font-size: 0.8rem;
    color: var(--cnp-fg-muted);
  }

  .st-empty {
    color: var(--cnp-fg-muted);
    font-size: 0.85rem;
    margin: 0.5rem 0;
  }

  .st-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.85rem;
  }

  .st-table th {
    text-align: left;
    font-weight: 500;
    color: var(--cnp-fg-muted);
    text-transform: uppercase;
    font-size: 0.7rem;
    letter-spacing: 0.04em;
    padding: 0.5rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
  }

  .st-table td {
    padding: 0.6rem 0.5rem;
    border-bottom: 1px solid var(--cnp-border);
    vertical-align: top;
  }

  .st-row-name {
    font-weight: 500;
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
  }

  :global(.st-verified) {
    color: oklch(0.72 0.14 290);
  }

  .st-row-desc {
    color: var(--cnp-fg-muted);
    font-size: 0.75rem;
    margin-top: 0.2rem;
  }

  .st-row-slug {
    color: var(--cnp-fg-muted);
    font-family: var(--cnp-font-mono, monospace);
    font-size: 0.7rem;
    margin-top: 0.2rem;
  }

  .st-kind {
    display: inline-block;
    padding: 0.1rem 0.5rem;
    border-radius: 3px;
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    border: 1px solid var(--cnp-border);
    color: var(--cnp-fg-muted);
  }

  .st-kind-workspace {
    color: oklch(0.72 0.15 165);
  }

  .st-kind-persona {
    color: oklch(0.72 0.14 290);
  }

  .st-kind-workflow {
    color: oklch(0.72 0.14 60);
  }

  .st-local-badge {
    font-size: 0.7rem;
    font-style: italic;
    color: var(--cnp-fg-muted);
    opacity: 0.75;
  }
</style>
