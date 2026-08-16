<script lang="ts">
/**
 * RuntimeStep — step 3 of OnboardingWizard.
 * Groups runtimes by category, deduplicates, shows versions for installed.
 * CSS prefix: obw-rt-
 */
import { createQuery } from '@tanstack/svelte-query';
import { Check, Circle, AlertTriangle } from 'lucide-svelte';
import { runtimesQuery } from '$lib/api/queries/runtimes.js';
import type { Runtime } from '$lib/domain/runtimes/types.js';

interface Props {
  onNext: () => void;
  onBack: () => void;
  onSkip: () => void;
}

let { onNext, onBack, onSkip }: Props = $props();

const query = createQuery(runtimesQuery());

interface GroupedRuntime {
  name: string;
  type: string;
  version: string | null;
  installed: boolean;
  kind: string;
  path: string | null;
}

type Category = 'cli' | 'api' | 'ide';

const CATEGORY_LABELS: Record<Category, string> = {
  cli: 'Agent Runtimes (CLI)',
  api: 'API Providers',
  ide: 'IDE Extensions',
};

const CATEGORY_DESCS: Record<Category, string> = {
  cli: 'Local AI coding agents installed on your machine',
  api: 'Cloud API keys for direct model access',
  ide: 'Editor extensions and plugins',
};

function categorize(rt: Runtime): Category {
  const t = rt.type.toLowerCase();
  if (t.endsWith('-api') || t === 'anthropic-api' || t === 'openai-api' || t === 'groq-api' || t === 'mistral-api') return 'api';
  if (t === 'cline' || t === 'continue-cli' || t.startsWith('cursor-')) return 'ide';
  return 'cli';
}

function dedup(runtimes: Runtime[]): GroupedRuntime[] {
  const seen = new Map<string, GroupedRuntime>();
  for (const rt of runtimes) {
    const key = rt.name.toLowerCase().replace(/[^a-z0-9]/g, '');
    const existing = seen.get(key);
    const installed = (rt as Runtime & { installed?: boolean }).installed === true || rt.status === 'installed';
    if (!existing || (installed && !existing.installed)) {
      seen.set(key, {
        name: rt.name,
        type: rt.type,
        version: (rt as Runtime & { version?: string | null }).version ?? null,
        installed,
        kind: rt.kind,
        path: rt.binaryPath,
      });
    }
  }
  return [...seen.values()];
}

const grouped = $derived.by(() => {
  const all = dedup($query.data ?? []);
  const groups = new Map<Category, GroupedRuntime[]>();
  for (const cat of ['cli', 'api', 'ide'] as Category[]) {
    groups.set(cat, []);
  }
  for (const rt of all) {
    const raw = ($query.data ?? []).find((r) => r.type === rt.type);
    const cat = raw ? categorize(raw) : 'cli';
    groups.get(cat)!.push(rt);
  }
  for (const [cat, items] of groups) {
    groups.set(cat, items.sort((a, b) => {
      if (a.installed && !b.installed) return -1;
      if (!a.installed && b.installed) return 1;
      return a.name.localeCompare(b.name);
    }));
  }
  return groups;
});

let showNotInstalled = $state(false);
let enabledTypes = $state<Set<string>>(new Set());

$effect(() => {
  const all = dedup($query.data ?? []);
  const installedTypes = all.filter((r) => r.installed).map((r) => r.type);
  if (enabledTypes.size === 0 && installedTypes.length > 0) {
    enabledTypes = new Set(installedTypes);
  }
});

function toggleRuntime(type: string): void {
  const next = new Set(enabledTypes);
  if (next.has(type)) next.delete(type);
  else next.add(type);
  enabledTypes = next;
}
</script>

<div class="obw-rt">
  <p class="obw-rt__hint">
    These AI tools were found on your system. Toggle the ones you want active — you can change this anytime in Settings.
  </p>

  {#if $query.isPending}
    <div class="obw-rt__loading">Scanning for runtimes…</div>
  {:else if $query.isError}
    <div class="obw-rt__empty">Could not reach runtime API. You can configure runtimes later.</div>
  {:else}
    {#each ['cli', 'api', 'ide'] as cat (cat)}
      {@const items = grouped.get(cat) ?? []}
      {@const installed = items.filter((r) => r.installed)}
      {@const notInstalled = items.filter((r) => !r.installed)}
      {#if items.length > 0}
        <div class="obw-rt__group">
          <div class="obw-rt__group-header">
            <h3 class="obw-rt__group-title">{CATEGORY_LABELS[cat]}</h3>
            <span class="obw-rt__group-count">{installed.length} detected</span>
          </div>
          <p class="obw-rt__group-desc">{CATEGORY_DESCS[cat]}</p>

          <ul class="obw-rt__list">
            {#each installed as rt (rt.type)}
              {@const active = enabledTypes.has(rt.type)}
              <li class="obw-rt__row" class:obw-rt__row--active={active}>
                <button
                  class="obw-rt__toggle-btn"
                  class:obw-rt__toggle-btn--on={active}
                  onclick={() => toggleRuntime(rt.type)}
                  aria-label="{active ? 'Disable' : 'Enable'} {rt.name}"
                  aria-pressed={active}
                >
                  <span class="obw-rt__toggle-dot"></span>
                </button>
                <span class="obw-rt__name">{rt.name}</span>
                {#if rt.version}
                  <span class="obw-rt__version">{rt.version}</span>
                {/if}
                {#if rt.path}
                  <span class="obw-rt__path" title={rt.path}>{rt.path.split('/').pop()}</span>
                {/if}
              </li>
            {/each}

            {#if notInstalled.length > 0 && showNotInstalled}
              {#each notInstalled as rt (rt.type)}
                <li class="obw-rt__row obw-rt__row--missing">
                  <span class="obw-rt__circle"><Circle size={14} /></span>
                  <span class="obw-rt__name">{rt.name}</span>
                  <span class="obw-rt__badge">not installed</span>
                </li>
              {/each}
            {/if}
          </ul>

          {#if notInstalled.length > 0 && !showNotInstalled}
            <button class="obw-rt__toggle" onclick={() => showNotInstalled = true}>
              + {notInstalled.length} more not installed
            </button>
          {/if}
        </div>
      {/if}
    {/each}
  {/if}

  <div class="obw-nav">
    <button class="obw-btn-ghost" onclick={onBack}>← Back</button>
    <div class="obw-nav__right">
      <button class="obw-btn-ghost obw-btn-skip" onclick={onSkip}>Skip for now</button>
      <button class="obw-btn-primary" onclick={onNext}>Next →</button>
    </div>
  </div>
</div>

<style>
  .obw-rt {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .obw-rt__hint {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-muted);
    line-height: 1.6;
  }

  .obw-rt__loading, .obw-rt__empty {
    font-family: var(--font-sans);
    font-size: 13px;
    color: var(--fg-subtle);
    padding: 16px 0;
  }

  .obw-rt__group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .obw-rt__group-header {
    display: flex;
    align-items: baseline;
    justify-content: space-between;
    gap: 8px;
  }

  .obw-rt__group-title {
    font-family: var(--font-sans);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--fg-muted);
    margin: 0;
  }

  .obw-rt__group-count {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .obw-rt__group-desc {
    margin: 0;
    font-family: var(--font-sans);
    font-size: 11px;
    color: var(--fg-subtle);
  }

  .obw-rt__list {
    list-style: none;
    margin: 0;
    padding: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .obw-rt__row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 12px;
    border-radius: 8px;
    border: 1px solid var(--border);
    background: var(--bg-elevated, var(--bg));
  }

  .obw-rt__row--installed {
    border-color: color-mix(in oklch, var(--signal-success, #34a853) 30%, var(--border));
  }

  .obw-rt__row--missing {
    opacity: 0.5;
  }

  .obw-rt__check {
    color: var(--signal-success, #34a853);
    display: flex;
    flex-shrink: 0;
  }

  .obw-rt__circle {
    color: var(--fg-subtle);
    display: flex;
    flex-shrink: 0;
  }

  .obw-rt__name {
    flex: 1;
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 500;
    color: var(--fg);
  }

  .obw-rt__version {
    font-family: var(--font-mono);
    font-size: 11px;
    color: var(--fg-subtle);
    background: color-mix(in oklch, var(--fg) 6%, transparent);
    padding: 1px 6px;
    border-radius: 4px;
  }

  .obw-rt__badge {
    font-family: var(--font-sans);
    font-size: 10px;
    color: var(--fg-subtle);
  }

  .obw-rt__path {
    font-family: var(--font-mono);
    font-size: 10px;
    color: var(--fg-subtle);
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .obw-rt__toggle-btn {
    position: relative;
    width: 34px;
    height: 18px;
    border-radius: 9px;
    border: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 8%, transparent);
    cursor: pointer;
    flex-shrink: 0;
    padding: 0;
    transition: background 150ms, border-color 150ms;
  }

  .obw-rt__toggle-btn--on {
    background: var(--cnp-accent, #6366f1);
    border-color: var(--cnp-accent, #6366f1);
  }

  .obw-rt__toggle-dot {
    position: absolute;
    top: 2px;
    left: 2px;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: var(--fg-subtle);
    transition: transform 150ms, background 150ms;
  }

  .obw-rt__toggle-btn--on .obw-rt__toggle-dot {
    transform: translateX(16px);
    background: #fff;
  }

  .obw-rt__row--active {
    border-color: color-mix(in oklch, var(--cnp-accent, #6366f1) 40%, var(--border));
  }

  .obw-rt__toggle {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 11px;
    cursor: pointer;
    padding: 4px 0;
    text-align: left;
  }

  .obw-rt__toggle:hover { color: var(--fg-muted); }

  .obw-nav {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    margin-top: auto;
  }

  .obw-nav__right { display: flex; gap: 12px; align-items: center; }

  .obw-btn-ghost {
    background: none;
    border: none;
    color: var(--fg-subtle);
    font-family: var(--font-sans);
    font-size: 13px;
    cursor: pointer;
    padding: 6px 8px;
    border-radius: 6px;
  }

  .obw-btn-ghost:hover { color: var(--fg); }
  .obw-btn-skip { font-size: 12px; }

  .obw-btn-primary {
    padding: 8px 20px;
    border-radius: 999px;
    border: none;
    background: var(--cnp-accent, #6366f1);
    color: #fff;
    font-family: var(--font-sans);
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }

  .obw-btn-primary:hover { opacity: 0.88; }
</style>
