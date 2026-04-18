<script lang="ts">
/**
 * Agent detail — /agents/:slug (docs/02-frontend-design.md §6.7).
 * Left: persona markdown prose block (read mode) / textarea (edit mode).
 * Right: PushPanel with metadata.
 * Top: breadcrumb + Hire/Run primary pill CTA + Edit persona pill.
 */

import {
  type CreateMutationOptions,
  type CreateQueryOptions,
  createMutation,
  createQuery,
  useQueryClient,
} from '@tanstack/svelte-query';
import { AlertCircle } from 'lucide-svelte';
import { untrack } from 'svelte';
import { writable } from 'svelte/store';
import { beforeNavigate, goto } from '$app/navigation';
import { page } from '$app/state';
import {
  agentDetailQuery,
  fireAgentMutation,
  hireAgentMutation,
  updatePersonaMutation,
} from '$lib/api/queries/agents.js';
import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb';
import ActorAvatar from '$lib/design/patterns/ActorAvatar.svelte';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import DirtyGuardModal from '$lib/design/patterns/DirtyGuardModal.svelte';
import PushPanel from '$lib/design/patterns/PushPanel.svelte';
import StatusDot from '$lib/design/patterns/StatusDot.svelte';
import type { Agent, AgentDetail, HireAgentBody } from '$lib/domain/agents/types.js';
import { toasts } from '$lib/stores/toasts.svelte.js';
import { renderMarkdown } from '$lib/utils/markdown.js';

const queryClient = useQueryClient();

// slug is always defined on this route — SvelteKit guarantees it
const slug = $derived(page.params.slug ?? '');

const agentOptsStore = writable(
  untrack(() => agentDetailQuery(slug) as CreateQueryOptions<AgentDetail>)
);

$effect(() => {
  agentOptsStore.set(agentDetailQuery(slug) as CreateQueryOptions<AgentDetail>);
});

const agentQ = createQuery<AgentDetail>(agentOptsStore);

let metaPanelOpen = $state(true);

const hireMut = createMutation<Agent, Error, { slug: string; body?: HireAgentBody }>(
  hireAgentMutation() as CreateMutationOptions<Agent, Error, { slug: string; body?: HireAgentBody }>
);

const fireMut = createMutation<void, Error, string>(
  fireAgentMutation() as CreateMutationOptions<void, Error, string>
);

const personaMut = createMutation<AgentDetail, Error, { slug: string; personaMarkdown: string }>(
  updatePersonaMutation() as CreateMutationOptions<
    AgentDetail,
    Error,
    { slug: string; personaMarkdown: string }
  >
);

// Typed accessor
const agent = $derived(($agentQ.data ?? null) as AgentDetail | null);
const hired = $derived(agent?.hired === true);

// ── Edit-mode state ──────────────────────────────────────────────────────────

let editMode = $state(false);
let editText = $state('');
const isDirty = $derived(editMode && editText !== (agent?.personaMarkdown ?? ''));

function enterEditMode() {
  editText = agent?.personaMarkdown ?? '';
  editMode = true;
}

function cancelEdit() {
  editMode = false;
  editText = '';
}

function savePersona() {
  if (!isDirty || $personaMut.isPending) return;

  $personaMut.mutate(
    { slug, personaMarkdown: editText },
    {
      onSuccess: () => {
        queryClient.invalidateQueries({ queryKey: ['agents', slug] });
        toasts.success('Saved');
        editMode = false;
        editText = '';
      },
      onError: (err: Error) => {
        toasts.error(err.message ?? 'Save failed');
      },
    }
  );
}

// ⌘S / Ctrl+S inside the textarea
function handleTextareaKeydown(e: KeyboardEvent) {
  if ((e.metaKey || e.ctrlKey) && e.key === 's') {
    e.preventDefault();
    savePersona();
  }
}

// Unsaved-changes guard
let guardOpen = $state(false);
let bypassGuard = $state(false);
let pendingNavigation: (() => void) | null = null;

beforeNavigate(({ cancel, to }) => {
  if (isDirty && !bypassGuard) {
    cancel();
    pendingNavigation = () => {
      bypassGuard = true;
      if (to?.url) window.location.assign(to.url.href);
    };
    guardOpen = true;
  }
});

// Rendered HTML (only computed in read mode to avoid unnecessary work)
const renderedHtml = $derived(
  !editMode && agent?.personaMarkdown ? renderMarkdown(agent.personaMarkdown) : ''
);
</script>

<div class="agent-detail">
  {#if $agentQ.isLoading}
    <div class="agent-detail__loading" aria-live="polite" aria-label="Loading agent">
      <div class="sk sk--avatar"></div>
      <div class="sk sk--title"></div>
      <div class="sk sk--body"></div>
      <div class="sk sk--body sk--short"></div>
    </div>
  {:else if $agentQ.isError || !agent}
    <EmptyState
      icon={AlertCircle as never}
      title="Agent not found"
      body="This agent doesn't exist or couldn't be loaded."
      action="Back to agents"
      onAction={() => goto('/agents')}
    />
  {:else}
    <!-- Top bar -->
    <header class="agent-detail__topbar">
      <Breadcrumb>
        <BreadcrumbItem href="/agents">Agents</BreadcrumbItem>
        <BreadcrumbItem>{agent.name}</BreadcrumbItem>
      </Breadcrumb>

      <div class="agent-detail__topbar-actions">
        <StatusDot
          color={hired ? 'green' : 'grey'}
          label={hired ? 'Hired' : 'Available'}
          pulse={hired}
        />

        {#if editMode}
          <!-- Edit-mode action bar -->
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            onclick={cancelEdit}
            disabled={$personaMut.isPending}
            aria-label="Cancel persona edit"
          >
            Cancel
          </button>
          <button
            class="btn-pill btn-pill-primary btn-pill-sm"
            onclick={savePersona}
            disabled={!isDirty || $personaMut.isPending}
            aria-label="Save persona"
          >
            {$personaMut.isPending ? 'Saving…' : 'Save'}
          </button>
        {:else}
          <!-- Read-mode actions -->
          <button
            class="btn-pill btn-pill-secondary btn-pill-sm"
            onclick={enterEditMode}
            aria-label="Edit persona"
          >
            Edit persona
          </button>

          {#if hired}
            <button
              class="btn-pill btn-pill-secondary btn-pill-sm"
              onclick={() => $fireMut.mutate(slug, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['agents', slug] }) })}
              disabled={$fireMut.isPending}
              aria-label="Fire {agent.name}"
            >
              {$fireMut.isPending ? 'Firing...' : 'Fire'}
            </button>
            <button
              class="btn-pill btn-pill-primary btn-pill-sm"
              onclick={() => goto(`/sessions?agent=${slug}`)}
              aria-label="Run {agent.name}"
            >
              Run ▸
            </button>
          {:else}
            <button
              class="btn-pill btn-pill-primary btn-pill-sm"
              onclick={() => $hireMut.mutate({ slug }, { onSuccess: () => queryClient.invalidateQueries({ queryKey: ['agents', slug] }) })}
              disabled={$hireMut.isPending}
              aria-label="Hire {agent.name}"
            >
              {$hireMut.isPending ? 'Hiring...' : 'Hire'}
            </button>
          {/if}

          <button
            class="btn-compact btn-compact-ghost btn-compact-sm"
            onclick={() => { metaPanelOpen = !metaPanelOpen; }}
            aria-label={metaPanelOpen ? 'Hide metadata' : 'Show metadata'}
            aria-pressed={metaPanelOpen}
          >
            {metaPanelOpen ? '→' : '←'} Info
          </button>
        {/if}
      </div>
    </header>

    <!-- Body: persona + metadata panel -->
    <div class="agent-detail__body">
      <!-- Left: persona prose / editor -->
      <article class="agent-detail__persona">
        <div class="agent-detail__persona-header">
          <ActorAvatar
            actor={{ type: 'agent', id: agent.slug, name: agent.name, emoji: agent.emoji }}
            size="lg"
          />
          <div>
            <h1 class="agent-detail__name">{agent.emoji} {agent.name}</h1>
            <p class="agent-detail__subtitle">{agent.title} · {agent.category}</p>
          </div>
        </div>

        <div class="agent-detail__markdown">
          {#if editMode}
            <!-- Edit mode: raw markdown textarea -->
            <textarea
              class="agent-detail__persona-editor"
              bind:value={editText}
              onkeydown={handleTextareaKeydown}
              aria-label="Persona markdown editor"
              spellcheck="false"
            ></textarea>
          {:else}
            <!-- Read mode: rendered markdown -->
            <!-- eslint-disable-next-line svelte/no-at-html-tags -->
            {@html renderedHtml}
          {/if}
        </div>
      </article>

      <!-- Right: metadata PushPanel -->
      <PushPanel open={metaPanelOpen} title="Agent info" onClose={() => { metaPanelOpen = false; }}>
        <dl class="agent-meta">
          <div class="agent-meta__row">
            <dt>Default runtime</dt>
            <dd>{agent.defaultRuntime ?? '—'}</dd>
          </div>
          <div class="agent-meta__row">
            <dt>Budget</dt>
            <dd>{agent.budget != null ? `$${agent.budget}/mo` : '—'}</dd>
          </div>
          <div class="agent-meta__row">
            <dt>Heartbeat</dt>
            <dd class="agent-meta__mono">{agent.heartbeatCron ?? 'none'}</dd>
          </div>
          <div class="agent-meta__row">
            <dt>Run count</dt>
            <dd>{agent.runCount}</dd>
          </div>
          <div class="agent-meta__row">
            <dt>Context tier</dt>
            <dd>{agent.contextTier}</dd>
          </div>

          {#if agent.tools.length > 0}
            <div class="agent-meta__row agent-meta__row--stack">
              <dt>Tools</dt>
              <dd class="agent-meta__chips">
                {#each agent.tools as tool (tool)}
                  <span class="agent-meta__chip">{tool}</span>
                {/each}
              </dd>
            </div>
          {/if}

          {#if agent.skills.length > 0}
            <div class="agent-meta__row agent-meta__row--stack">
              <dt>Skills</dt>
              <dd class="agent-meta__chips">
                {#each agent.skills as skill (skill)}
                  <span class="agent-meta__chip">{skill}</span>
                {/each}
              </dd>
            </div>
          {/if}
        </dl>
      </PushPanel>
    </div>
  {/if}
</div>

<DirtyGuardModal
  open={guardOpen}
  onCancel={() => { guardOpen = false; pendingNavigation = null; }}
  onDiscard={() => { guardOpen = false; pendingNavigation?.(); pendingNavigation = null; }}
/>

<style>
  .agent-detail {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;
  }

  .agent-detail__topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-3) var(--space-5);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    gap: var(--space-4);
    flex-wrap: wrap;
  }

  .agent-detail__topbar-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    flex-shrink: 0;
  }

  .agent-detail__body {
    display: flex;
    flex: 1;
    overflow: hidden;
    gap: 0;
  }

  .agent-detail__persona {
    flex: 1;
    overflow-y: auto;
    padding: var(--space-6);
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    min-width: 0;
  }

  .agent-detail__persona-header {
    display: flex;
    align-items: center;
    gap: var(--space-4);
  }

  .agent-detail__name {
    font-family: var(--font-sans);
    font-size: var(--text-2xl);
    font-weight: 600;
    color: var(--fg);
    margin: 0;
    letter-spacing: -0.025em;
  }

  .agent-detail__subtitle {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-transform: capitalize;
  }

  .agent-detail__markdown {
    flex: 1;
  }

  /* ── Rendered markdown typography ─────────────────────────────────────────── */

  .agent-detail__markdown :global(.fv-h1) {
    font-family: var(--font-sans);
    font-size: var(--text-xl);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-5) 0 var(--space-2);
  }

  .agent-detail__markdown :global(.fv-h2) {
    font-family: var(--font-sans);
    font-size: var(--text-lg);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-4) 0 var(--space-2);
  }

  .agent-detail__markdown :global(.fv-h3) {
    font-family: var(--font-sans);
    font-size: var(--text-base);
    font-weight: 600;
    color: var(--fg);
    margin: var(--space-3) 0 var(--space-1);
  }

  .agent-detail__markdown :global(.fv-p) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.7;
    margin: 0 0 var(--space-2);
  }

  .agent-detail__markdown :global(.fv-ul),
  .agent-detail__markdown :global(.fv-ol) {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    line-height: 1.7;
    margin: 0 0 var(--space-2);
    padding-left: var(--space-5);
  }

  .agent-detail__markdown :global(.fv-code-block) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-3) var(--space-4);
    overflow-x: auto;
    margin: 0 0 var(--space-3);
  }

  .agent-detail__markdown :global(.fv-inline-code) {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: var(--radius-sm);
    padding: 1px 4px;
  }

  .agent-detail__markdown :global(.fv-link) {
    color: var(--fg);
    text-decoration: underline;
    text-underline-offset: 2px;
  }

  /* ── Edit-mode textarea ────────────────────────────────────────────────────── */

  .agent-detail__persona-editor {
    width: 100%;
    min-height: 400px;
    font-family: var(--font-mono);
    font-size: var(--text-sm);
    color: var(--fg);
    line-height: 1.7;
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: var(--space-5);
    resize: vertical;
    outline: none;
    box-sizing: border-box;
  }

  .agent-detail__persona-editor:focus {
    border-color: var(--fg-subtle);
    box-shadow: 0 0 0 2px color-mix(in oklch, var(--fg) 10%, transparent 90%);
  }

  /* Agent metadata in push panel */
  .agent-meta {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    margin: 0;
    padding: 0;
  }

  .agent-meta__row {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: var(--space-3);
  }

  .agent-meta__row--stack {
    flex-direction: column;
    gap: var(--space-1);
  }

  .agent-meta dt {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-subtle);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    flex-shrink: 0;
  }

  .agent-meta dd {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
    text-align: right;
  }

  .agent-meta__mono {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
  }

  .agent-meta__chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    text-align: left;
  }

  .agent-meta__chip {
    display: inline-flex;
    padding: 2px 8px;
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    border-radius: 9999px;
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-muted);
    border: 1px solid var(--border);
  }

  /* Loading skeletons */
  .agent-detail__loading {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-8);
    max-width: 600px;
  }

  .sk {
    background: var(--border);
    border-radius: var(--radius-sm);
    animation: sk-pulse 1.5s ease-in-out infinite;
  }

  .sk--avatar { width: 44px; height: 44px; border-radius: 9999px; }
  .sk--title { height: 28px; width: 50%; }
  .sk--body { height: 14px; width: 90%; }
  .sk--short { width: 70%; }

  @keyframes sk-pulse {
    0%, 100% { opacity: 0.3; }
    50% { opacity: 0.6; }
  }
</style>
