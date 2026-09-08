<script lang="ts">
/**
 * SkillsPanel — agent ↔ skill assignment panel.
 * Lists all skills grouped by kind, shows which are assigned to this agent,
 * and calls the live assignment endpoints (POST/DELETE /agents/:slug/skills).
 * CSS prefix: skp- (SkillsPanel)
 */
import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { writable } from 'svelte/store';
import {
  agentSkillsQuery,
  assignSkillMutation,
  unassignSkillMutation,
} from '$lib/api/queries/agent-skills.js';
import type { AgentSkillAssignment, Skill } from '$lib/domain/skills/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';

interface Props {
  agentSlug: string;
  skills: Skill[];
  isLoading: boolean;
}

let { agentSlug, skills, isLoading }: Props = $props();

const queryClient = useQueryClient();

// ── Live assignments query ────────────────────────────────────────────────

const assignmentsOptsStore = writable(
  agentSkillsQuery(agentSlug) as CreateQueryOptions<AgentSkillAssignment[]>
);

$effect(() => {
  assignmentsOptsStore.set(
    agentSkillsQuery(agentSlug) as CreateQueryOptions<AgentSkillAssignment[]>
  );
});

const assignmentsQ = createQuery<AgentSkillAssignment[]>(assignmentsOptsStore);

const assignedSlugs = $derived(($assignmentsQ.data ?? []).map((a) => a.skill_slug));

// ── Mutations ─────────────────────────────────────────────────────────────

const assignMut = createMutation<
  AgentSkillAssignment,
  Error,
  { agentSlug: string; skillSlug: string; priority?: number }
>(
  assignSkillMutation() as CreateMutationOptions<
    AgentSkillAssignment,
    Error,
    { agentSlug: string; skillSlug: string; priority?: number }
  >
);

const unassignMut = createMutation<void, Error, { agentSlug: string; skillSlug: string }>(
  unassignSkillMutation() as CreateMutationOptions<
    void,
    Error,
    { agentSlug: string; skillSlug: string }
  >
);

function invalidateAssignments() {
  queryClient.invalidateQueries({ queryKey: ['agents', agentSlug, 'skills'] });
}

function toggle(skillSlug: string) {
  if (assignedSlugs.includes(skillSlug)) {
    $unassignMut.mutate(
      { agentSlug, skillSlug },
      {
        onSuccess: () => {
          invalidateAssignments();
          toasts.success('Skill removed.');
        },
        onError: (err) => toasts.error(err.message ?? 'Remove failed.'),
      }
    );
  } else {
    $assignMut.mutate(
      { agentSlug, skillSlug },
      {
        onSuccess: () => {
          invalidateAssignments();
          toasts.success('Skill assigned.');
        },
        onError: (err) => toasts.error(err.message ?? 'Assignment failed.'),
      }
    );
  }
}

// ── Group by kind ─────────────────────────────────────────────────────────

const KIND_ORDER = ['prompt', 'workflow', 'reference'] as const;

const byKind = $derived(
  KIND_ORDER.reduce<Record<string, Skill[]>>((acc, k) => {
    const group = skills.filter((s) => s.kind === k);
    if (group.length > 0) acc[k] = group;
    return acc;
  }, {})
);

function kindLabel(kind: string): string {
  switch (kind) {
    case 'prompt':
      return 'Prompts';
    case 'workflow':
      return 'Workflows';
    case 'reference':
      return 'Reference';
    default:
      return kind;
  }
}

const isBusy = $derived($assignMut.isPending || $unassignMut.isPending);
</script>

<div class="skp-root">
  {#if isLoading || $assignmentsQ.isLoading}
    <div class="skp-loading" aria-live="polite">Loading skills…</div>
  {:else if skills.length === 0}
    <div class="skp-empty">No skills found. Import from a registry in Settings → Skills.</div>
  {:else}
    {#each Object.entries(byKind) as [kind, group] (kind)}
      <section class="skp-section">
        <h3 class="skp-section-label">{kindLabel(kind)}</h3>
        <div class="skp-list" role="list">
          {#each group as skill (skill.slug)}
            {@const assigned = assignedSlugs.includes(skill.slug)}
            <div class="skp-row" role="listitem">
              <div class="skp-row-info">
                <span class="skp-row-name">{skill.name}</span>
                {#if skill.description}
                  <span class="skp-row-desc">{skill.description}</span>
                {/if}
                {#if skill.tags.length > 0}
                  <div class="skp-tags">
                    {#each skill.tags as tag (tag)}
                      <span class="skp-tag">{tag}</span>
                    {/each}
                  </div>
                {/if}
              </div>
              <button
                class="skp-toggle"
                class:skp-toggle--on={assigned}
                role="switch"
                aria-checked={assigned}
                aria-label="{assigned ? 'Remove' : 'Assign'} skill {skill.name}"
                disabled={isBusy}
                onclick={() => toggle(skill.slug)}
              >
                <span class="skp-toggle-thumb"></span>
              </button>
            </div>
          {/each}
        </div>
      </section>
    {/each}
  {/if}
</div>

<style>
  .skp-root {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    padding: var(--space-6);
  }

  .skp-loading,
  .skp-empty {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    padding: var(--space-4) 0;
  }

  .skp-section {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }

  .skp-section-label {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--fg-subtle);
    margin: 0;
    padding-bottom: var(--space-1);
    border-bottom: 1px solid var(--border);
  }

  .skp-list {
    display: flex;
    flex-direction: column;
    gap: 1px;
  }

  .skp-row {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    gap: var(--space-4);
    padding: var(--space-3) var(--space-2);
    border-radius: var(--radius-sm);
    transition: background 0.1s;
  }

  .skp-row:hover {
    background: color-mix(in oklch, var(--fg) 4%, transparent);
  }

  .skp-row-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
    flex: 1;
    min-width: 0;
  }

  .skp-row-name {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
  }

  .skp-row-desc {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-muted);
    line-height: 1.5;
  }

  .skp-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    margin-top: 4px;
  }

  .skp-tag {
    padding: 1px 6px;
    background: color-mix(in oklch, var(--fg) 7%, transparent);
    border: 1px solid var(--border);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  /* Toggle switch */
  .skp-toggle {
    position: relative;
    flex-shrink: 0;
    width: 36px;
    height: 20px;
    border-radius: 10px;
    background: var(--border);
    border: none;
    cursor: pointer;
    transition: background 0.15s;
    padding: 0;
  }

  .skp-toggle:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  .skp-toggle--on {
    background: var(--cnp-accent, oklch(0.55 0.18 250));
  }

  .skp-toggle-thumb {
    position: absolute;
    top: 3px;
    left: 3px;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: white;
    transition: transform 0.15s;
    display: block;
  }

  .skp-toggle--on .skp-toggle-thumb {
    transform: translateX(16px);
  }

  .skp-toggle:focus-visible {
    outline: 2px solid var(--cnp-accent, oklch(0.55 0.18 250));
    outline-offset: 2px;
  }
</style>
