<script lang="ts">
/**
 * Skills library — /skills (Wave A #111 completion).
 * List of imported skills with filter row + inline import panel.
 * CSS prefix: sk- (Skills list)
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { Search, Zap } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { goto } from '$app/navigation';
import {
  importSkillMutation,
  skillsQuery,
} from '$lib/api/queries/skills.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import SkeletonList from '$lib/design/patterns/SkeletonList.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { ImportSkillBody, ImportSkillResponse, Skill, SkillFilters, SkillKind, SkillSource } from '$lib/domain/skills/types.js';
import { useListKeyboard } from '$lib/utils/useListKeyboard.svelte.js';

const queryClient = useQueryClient();

// ── Filter state ─────────────────────────────────────────────────────────────

let searchQuery = $state('');
let sourceFilter = $state<SkillSource | 'all'>('all');
let kindFilter = $state<SkillKind | 'all'>('all');
let enabledFilter = $state<boolean | undefined>(undefined);

const filters = $derived<SkillFilters>({
  source: sourceFilter === 'all' ? undefined : sourceFilter,
  kind: kindFilter === 'all' ? undefined : kindFilter,
  enabled: enabledFilter,
});

const optsStore = writable(
  untrack(() => skillsQuery(filters) as CreateQueryOptions<Skill[]>)
);

$effect(() => {
  optsStore.set(skillsQuery(filters) as CreateQueryOptions<Skill[]>);
});

const skillsQ = createQuery<Skill[]>(optsStore);

const allSkills = $derived(($skillsQ.data ?? []) as Skill[]);

// Client-side text search applied on top of server filters
const skills = $derived(
  searchQuery.trim()
    ? allSkills.filter(
        (s) =>
          s.slug.includes(searchQuery.toLowerCase()) ||
          s.name.toLowerCase().includes(searchQuery.toLowerCase())
      )
    : allSkills
);

// ── Keyboard nav ─────────────────────────────────────────────────────────────

const kb = useListKeyboard({
  items: () => skills,
  onSelect: (skill) => goto(`/skills/${skill.slug}`),
  onRefresh: () => queryClient.invalidateQueries({ queryKey: ['skills'] }),
});

// ── Source chips ─────────────────────────────────────────────────────────────

const SOURCE_CHIPS: Array<{ value: SkillSource | 'all'; label: string }> = [
  { value: 'all', label: 'All' },
  { value: 'local', label: 'Local' },
  { value: 'clawhub', label: 'Clawhub' },
  { value: 'skills_sh', label: 'Skills.sh' },
];

const KIND_CHIPS: Array<{ value: SkillKind | 'all'; label: string }> = [
  { value: 'all', label: 'All kinds' },
  { value: 'prompt', label: 'Prompt' },
  { value: 'workflow', label: 'Workflow' },
  { value: 'reference', label: 'Reference' },
];

// ── Inline import panel ───────────────────────────────────────────────────────

let importOpen = $state(false);
let importSource = $state<'clawhub' | 'skills_sh'>('clawhub');

const importMut = createMutation<ImportSkillResponse, Error, ImportSkillBody>(
  importSkillMutation() as CreateMutationOptions<ImportSkillResponse, Error, ImportSkillBody>
);

function handleImport(): void {
  $importMut.mutate(
    { source: importSource },
    {
      onSuccess: (result) => {
        queryClient.invalidateQueries({ queryKey: ['skills'] });
        importOpen = false;
        importFeedback = `Imported ${result.imported} skill${result.imported !== 1 ? 's' : ''}${result.errors > 0 ? ` (${result.errors} error${result.errors !== 1 ? 's' : ''})` : ''}.`;
      },
      onError: (err) => {
        importFeedback = err.message ?? 'Import failed.';
      },
    }
  );
}

let importFeedback = $state('');

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  if (diff < 60_000) return 'just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return `${Math.floor(diff / 86_400_000)}d ago`;
}

function sourceLabel(source: SkillSource): string {
  switch (source) {
    case 'clawhub': return 'Clawhub';
    case 'skills_sh': return 'Skills.sh';
    case 'local': return 'Local';
    case 'user': return 'User';
  }
}
</script>

<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
<div
  class="skl-page"
  role="region"
  aria-label="Skills list"
  onkeydown={kb.handleKeydown}
>
  <!-- Header -->
  <header class="skl-header">
    <div class="skl-title-row">
      <h1 class="skl-title">Skills</h1>
      <div class="skl-header-actions">
        <button
          class="btn-pill btn-pill-ghost btn-pill-sm"
          onclick={() => { importOpen = !importOpen; importFeedback = ''; }}
          aria-expanded={importOpen}
          aria-label="Import from registry"
        >
          + Import from registry
        </button>
      </div>
    </div>

    <!-- Filter row -->
    <div class="skl-filter-row">
      <div class="skl-search-wrap">
        <Search size={13} class="skl-search-icon" aria-hidden="true" />
        <input
          class="skl-search"
          type="search"
          placeholder="Search skills…"
          bind:value={searchQuery}
          aria-label="Search skills"
        />
      </div>

      <div class="skl-source-chips" role="group" aria-label="Filter by source">
        {#each SOURCE_CHIPS as chip (chip.value)}
          <button
            class="btn-pill btn-pill-xs skl-source-chip"
            class:skl-source-chip--active={sourceFilter === chip.value}
            onclick={() => { sourceFilter = chip.value; }}
            aria-pressed={sourceFilter === chip.value}
          >
            {chip.label}
          </button>
        {/each}
      </div>

      <div class="skl-source-chips" role="group" aria-label="Filter by kind">
        {#each KIND_CHIPS as chip (chip.value)}
          <button
            class="btn-pill btn-pill-xs skl-source-chip"
            class:skl-source-chip--active={kindFilter === chip.value}
            onclick={() => { kindFilter = chip.value; }}
            aria-pressed={kindFilter === chip.value}
          >
            {chip.label}
          </button>
        {/each}
      </div>

      <label class="skl-enabled-toggle" for="skl-enabled-toggle">
        <input
          id="skl-enabled-toggle"
          type="checkbox"
          class="skl-checkbox"
          checked={enabledFilter === true}
          onchange={(e) => {
            enabledFilter = (e.target as HTMLInputElement).checked ? true : undefined;
          }}
        />
        Enabled only
      </label>
    </div>
  </header>

  <!-- Inline import panel -->
  {#if importOpen}
    <div class="skl-import-panel" role="form" aria-label="Import skills from registry">
      <div class="skl-import-row">
        <label class="skl-import-label" for="skl-import-source">Source</label>
        <select
          id="skl-import-source"
          class="skl-select"
          bind:value={importSource}
        >
          <option value="clawhub">Clawhub</option>
          <option value="skills_sh">Skills.sh</option>
        </select>
        <button
          class="btn-pill btn-pill-primary btn-pill-sm"
          onclick={handleImport}
          disabled={$importMut.isPending}
          aria-busy={$importMut.isPending}
        >
          {$importMut.isPending ? 'Importing…' : 'Fetch & import'}
        </button>
        <button
          class="btn-compact btn-compact-ghost"
          onclick={() => { importOpen = false; importFeedback = ''; }}
          aria-label="Close import panel"
        >
          Cancel
        </button>
      </div>
      {#if importFeedback}
        <p class="skl-import-feedback">{importFeedback}</p>
      {/if}
    </div>
  {/if}

  <!-- Skills list -->
  <main class="skl-list-wrap">
    {#if $skillsQ.isLoading}
      <SkeletonList count={8} height="2.5rem" gap="0.125rem" />
    {:else if $skillsQ.isError}
      <EmptyState
        icon={Zap as never}
        title="Failed to load skills"
        body="Check your connection and try again."
        action="Retry"
        onAction={() => $skillsQ.refetch()}
      />
    {:else if skills.length === 0}
      <EmptyState
        icon={Zap as never}
        title="No skills yet."
        body="Import from a registry to get started."
        action="Import from registry"
        onAction={() => { importOpen = true; }}
      />
    {:else}
      <div class="skl-list" role="list">
        {#each skills as skill, i (skill.slug)}
          <div
            class="skl-row"
            class:skl-row--selected={kb.selectedIndex === i}
            role="listitem"
          >
            <button
              class="skl-row-btn"
              onclick={() => goto(`/skills/${skill.slug}`)}
              aria-label="Open skill {skill.name}"
            >
              <StatusDot color={skill.enabled ? 'green' : 'grey'} />
              <span class="skl-slug">{skill.slug}</span>
              <span class="skl-name">{skill.name}</span>
              <span class="skl-kind-pill skl-kind-pill--{skill.kind}">{skill.kind}</span>
              <span class="skl-source-badge">{sourceLabel(skill.source)}</span>
              <time class="skl-date" datetime={skill.updated_at}>
                {formatRelative(skill.updated_at)}
              </time>
            </button>
          </div>
        {/each}
      </div>
    {/if}
  </main>
</div>

<style>
  .skl-page {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
    outline: none;
  }

  /* ── Header ── */

  .skl-header {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding: var(--space-5) var(--space-6) var(--space-3);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
  }

  .skl-title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-3);
  }

  .skl-title {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .skl-header-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  /* ── Filter row ── */

  .skl-filter-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .skl-search-wrap {
    position: relative;
    display: flex;
    align-items: center;
    flex: 1;
    min-width: 160px;
  }

  :global(.skl-search-icon) {
    position: absolute;
    left: var(--space-3);
    color: var(--fg-subtle);
    pointer-events: none;
  }

  .skl-search {
    width: 100%;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-2) var(--space-3) var(--space-2) calc(var(--space-3) + 20px);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    outline: none;
    transition: border-color var(--dur-instant) var(--ease-out);
  }

  .skl-search:focus { border-color: var(--border-strong); }
  .skl-search::placeholder { color: var(--fg-subtle); }

  .skl-source-chips {
    display: flex;
    gap: var(--space-1);
    flex-shrink: 0;
  }

  .skl-source-chip {
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg-muted);
    font-size: 11px;
  }

  .skl-source-chip:hover {
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    color: var(--fg);
  }

  .skl-source-chip--active {
    background: color-mix(in oklch, var(--fg) 12%, transparent);
    color: var(--fg);
    border-color: var(--border-strong);
  }

  .skl-enabled-toggle {
    display: flex;
    align-items: center;
    gap: var(--space-1);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    cursor: pointer;
    white-space: nowrap;
    flex-shrink: 0;
  }

  .skl-checkbox {
    width: 14px;
    height: 14px;
    cursor: pointer;
    accent-color: var(--cnp-accent);
  }

  /* ── Import panel ── */

  .skl-import-panel {
    padding: var(--space-3) var(--space-6);
    background: var(--bg-inset);
    border-bottom: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    animation: fade-in-up var(--dur-fast) var(--ease-out) both;
    flex-shrink: 0;
  }

  .skl-import-row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    flex-wrap: wrap;
  }

  .skl-import-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
    flex-shrink: 0;
  }

  .skl-select {
    height: 28px;
    padding: 0 var(--space-2);
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-sm);
    outline: none;
    cursor: pointer;
  }

  .skl-select:focus-visible { border-color: var(--cnp-accent); }

  .skl-import-feedback {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── List ── */

  .skl-list-wrap {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-3) var(--space-6);
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .skl-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
  }

  .skl-row {
    background: var(--bg-elevated);
  }

  .skl-row + .skl-row {
    border-top: 1px solid var(--border);
  }

  .skl-row--selected {
    background: color-mix(in oklch, var(--fg) 5%, var(--bg-elevated));
  }

  .skl-row-btn {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    width: 100%;
    padding: var(--space-2) var(--space-3);
    background: transparent;
    border: none;
    cursor: pointer;
    text-align: left;
    transition: background var(--dur-fast) var(--ease-out);
  }

  .skl-row-btn:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .skl-slug {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    flex-shrink: 0;
    min-width: 160px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .skl-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .skl-source-badge {
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-subtle);
    flex-shrink: 0;
    white-space: nowrap;
  }

  .skl-date {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    font-variant-numeric: tabular-nums;
    color: var(--fg-subtle);
    flex-shrink: 0;
    white-space: nowrap;
  }

  /* ── Kind pill ── */

  .skl-kind-pill {
    display: inline-flex;
    align-items: center;
    padding: 1px 7px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
    border: 1px solid transparent;
  }

  .skl-kind-pill--prompt {
    background: color-mix(in oklch, oklch(0.55 0.18 250) 12%, transparent);
    border-color: color-mix(in oklch, oklch(0.55 0.18 250) 25%, transparent);
    color: oklch(0.55 0.18 250);
  }

  .skl-kind-pill--workflow {
    background: color-mix(in oklch, oklch(0.65 0.15 150) 12%, transparent);
    border-color: color-mix(in oklch, oklch(0.65 0.15 150) 25%, transparent);
    color: oklch(0.55 0.15 150);
  }

  .skl-kind-pill--reference {
    background: color-mix(in oklch, var(--fg) 7%, transparent);
    border-color: var(--border);
    color: var(--fg-muted);
  }
</style>
