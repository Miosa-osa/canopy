<script lang="ts">
/**
 * /runtimes/[type] — Runtime Detail page.
 *
 * Breadcrumb + pill CTAs at top. Six Foundation Tabs:
 *   Overview / Configuration / Models / Skills / Sessions / Logs
 *
 * Wires:
 *   - runtimeDetailQuery(type) for runtime data
 *   - runtimeModelsQuery(type) for Models tab
 *   - testEnvironmentMutation(type) for "Test Environment" button
 *
 * TanStack QueryClientProvider assumed from root layout (+layout.svelte).
 */
// TODO: QueryClient setup assumed from layout
import { type CreateQueryOptions, createMutation, createQuery } from '@tanstack/svelte-query';
import { goto } from '$app/navigation';
import { page } from '$app/state';
import {
  runtimeDetailQuery,
  runtimeModelsQuery,
  testRuntimeEnvironment,
} from '$lib/api/queries/runtimes.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import { Breadcrumb, BreadcrumbItem } from '$lib/design/foundation/breadcrumb/index.js';
import Skeleton from '$lib/design/foundation/skeleton/Skeleton.svelte';
import { Table, TableHeader } from '$lib/design/foundation/table/index.js';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '$lib/design/foundation/tabs/index.js';
import EmptyState from '$lib/design/patterns/EmptyState.svelte';
import RuntimeConfigForm from '$lib/design/patterns/RuntimeConfigForm.svelte';
import type {
  EnvironmentCheckItem,
  RuntimeDetail,
  RuntimeModel,
  TestEnvironmentResult,
} from '$lib/domain/runtimes/types.js';

const runtimeType = $derived(page.params.type ?? '');

const detailQueryOpts = $derived(
  runtimeDetailQuery(runtimeType) as CreateQueryOptions<RuntimeDetail>
);
const modelsQueryOpts = $derived(
  runtimeModelsQuery(runtimeType) as CreateQueryOptions<RuntimeModel[]>
);

const detailQuery = createQuery<RuntimeDetail>(detailQueryOpts);
const modelsQuery = createQuery<RuntimeModel[]>(modelsQueryOpts);

const testMutation = createMutation<TestEnvironmentResult, Error, void>({
  mutationFn: () => testRuntimeEnvironment(runtimeType),
});

let testResult = $state<TestEnvironmentResult | null>(null);
let testError = $state<string | null>(null);

async function runTest() {
  testResult = null;
  testError = null;
  try {
    const result = await $testMutation.mutateAsync();
    testResult = result ?? null;
  } catch (err) {
    testError = err instanceof Error ? err.message : 'Test failed';
  }
}

function formatContext(n: number | null): string {
  if (n === null) return '—';
  return n >= 1000 ? `${(n / 1000).toFixed(0)}K` : String(n);
}

async function handleSaveConfig(values: Record<string, unknown>) {
  // Placeholder — config persistence API ships in Week 2.
  console.info('[RuntimeConfigForm] save', values);
}
</script>

<div class="rtd-page">
  <!-- Top bar -->
  <div class="rtd-topbar">
    <Breadcrumb>
      <BreadcrumbItem>
        <button
          class="btn-compact btn-compact-ghost rtd-back-btn"
          onclick={() => goto('/runtimes')}
          aria-label="Back to Runtimes"
        >
          Runtimes
        </button>
      </BreadcrumbItem>
      <BreadcrumbItem>
        {#if $detailQuery.data}
          <span class="rtd-crumb-current">{$detailQuery.data.name}</span>
        {:else}
          <Skeleton class="rtd-sk-crumb" />
        {/if}
      </BreadcrumbItem>
    </Breadcrumb>

    <div class="rtd-actions">
      <button
        class="btn-pill btn-pill-secondary btn-pill-sm"
        onclick={runTest}
        disabled={$testMutation.isPending}
        aria-label="Test environment"
      >
        {#if $testMutation.isPending}
          <span class="btn-pill-spinner" aria-hidden="true"></span>
          Testing…
        {:else}
          Test Environment
        {/if}
      </button>

      <button
        class="btn-pill btn-pill-primary btn-pill-sm"
        onclick={() => goto('/')}
        aria-label="Launch session"
      >
        Launch Session
      </button>
    </div>
  </div>

  <!-- Test result feedback -->
  {#if testResult}
    <Alert
      variant={testResult.ok ? 'success' : 'warning'}
      title={testResult.ok ? 'Environment OK' : 'Environment issues found'}
      dismissible
      ondismiss={() => (testResult = null)}
    >
      {#each testResult.checks as check (check.message)}
        <div class="rtd-check" data-level={check.level}>{check.message}</div>
      {/each}
    </Alert>
  {/if}

  {#if testError}
    <Alert variant="error" dismissible ondismiss={() => (testError = null)}>
      {testError}
    </Alert>
  {/if}

  {#if $detailQuery.isError}
    <Alert variant="error" title="Failed to load runtime">
      {($detailQuery.error as Error).message}
    </Alert>
  {:else}
    <!-- Tabs -->
    <Tabs value="overview" class="rtd-tabs">
      <TabsList class="rtd-tabs-list">
        <TabsTrigger value="overview">Overview</TabsTrigger>
        <TabsTrigger value="configuration">Configuration</TabsTrigger>
        <TabsTrigger value="models">Models</TabsTrigger>
        <TabsTrigger value="skills">Skills</TabsTrigger>
        <TabsTrigger value="sessions">Sessions</TabsTrigger>
        <TabsTrigger value="logs">Logs</TabsTrigger>
      </TabsList>

      <!-- Overview -->
      <TabsContent value="overview" class="rtd-tab-content">
        {#if $detailQuery.isLoading}
          <div class="rtd-ov-skeleton">
            {#each Array.from({ length: 4 }, (_, i) => i) as i (i)}
              <Skeleton class="rtd-sk-row" />
            {/each}
          </div>
        {:else if $detailQuery.data}
          {@const runtime = $detailQuery.data}
          <dl class="rtd-ov-dl">
            <div class="rtd-ov-row">
              <dt class="rtd-ov-dt">Version</dt>
              <dd class="rtd-ov-dd rtd-mono">{runtime.version ?? '—'}</dd>
            </div>
            <div class="rtd-ov-row">
              <dt class="rtd-ov-dt">Binary path</dt>
              <dd class="rtd-ov-dd rtd-mono">{runtime.binaryPath ?? '—'}</dd>
            </div>
            <div class="rtd-ov-row">
              <dt class="rtd-ov-dt">Status</dt>
              <dd class="rtd-ov-dd">{runtime.status}</dd>
            </div>
            <div class="rtd-ov-row">
              <dt class="rtd-ov-dt">Capabilities</dt>
              <dd class="rtd-ov-dd">
                <div class="rtd-caps">
                  {#each runtime.capabilities as cap (cap)}
                    <span class="rtd-cap-pill">{cap}</span>
                  {/each}
                  {#if runtime.capabilities.length === 0}
                    <span class="rtd-none">—</span>
                  {/if}
                </div>
              </dd>
            </div>
            <div class="rtd-ov-row">
              <dt class="rtd-ov-dt">Monthly spend</dt>
              <dd class="rtd-ov-dd">${runtime.monthlyCostUsd.toFixed(2)} <span class="rtd-none">(placeholder)</span></dd>
            </div>
          </dl>
        {/if}
      </TabsContent>

      <!-- Configuration -->
      <TabsContent value="configuration" class="rtd-tab-content">
        {#if $detailQuery.isLoading}
          <Skeleton class="rtd-sk-form" />
        {:else if $detailQuery.data}
          <RuntimeConfigForm
            schema={$detailQuery.data.configSchema}
            initial={$detailQuery.data.config}
            onSave={handleSaveConfig}
          />
        {/if}
      </TabsContent>

      <!-- Models -->
      <TabsContent value="models" class="rtd-tab-content">
        {#if $modelsQuery.isLoading}
          <Skeleton class="rtd-sk-form" />
        {:else if $modelsQuery.isError}
          <Alert variant="error">Failed to load models.</Alert>
        {:else if $modelsQuery.data && $modelsQuery.data.length > 0}
          <Table hoverable>
            <TableHeader>
              <tr>
                <th class="rtd-th">Model ID</th>
                <th class="rtd-th">Context</th>
                <th class="rtd-th">Input / 1M</th>
                <th class="rtd-th">Output / 1M</th>
                <th class="rtd-th">Default</th>
              </tr>
            </TableHeader>
            <tbody>
              {#each $modelsQuery.data as model (model.id)}
                <tr class="bos-table-row">
                  <td class="bos-table-cell rtd-mono">{model.id}</td>
                  <td class="bos-table-cell">{formatContext(model.contextWindow)}</td>
                  <td class="bos-table-cell">—</td>
                  <td class="bos-table-cell">—</td>
                  <td class="bos-table-cell">{model.isDefault ? '✓' : ''}</td>
                </tr>
              {/each}
            </tbody>
          </Table>
        {:else}
          <EmptyState title="No models listed" body="This runtime has not reported any available models." />
        {/if}
      </TabsContent>

      <!-- Skills -->
      <TabsContent value="skills" class="rtd-tab-content">
        <EmptyState title="Skills" body="Skills ship in Week 2." />
      </TabsContent>

      <!-- Sessions -->
      <TabsContent value="sessions" class="rtd-tab-content">
        <p class="rtd-deferred">Filtered session list — wire in Week 1 Day 3.</p>
      </TabsContent>

      <!-- Logs -->
      <TabsContent value="logs" class="rtd-tab-content">
        <p class="rtd-deferred">Log viewer — Week 2.</p>
      </TabsContent>
    </Tabs>
  {/if}
</div>

<style>
  .rtd-page {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    padding: var(--space-5) var(--space-6);
    overflow-y: auto;
    height: 100%;
    scrollbar-width: thin;
    scrollbar-color: var(--border) transparent;
  }

  .rtd-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: var(--space-3);
  }

  .rtd-back-btn {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
  }

  .rtd-crumb-current {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .rtd-actions {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  :global(.rtd-tabs) {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
    flex: 1;
  }

  :global(.rtd-tabs-list) {
    flex-shrink: 0;
  }

  .rtd-tab-content {
    flex: 1;
  }

  /* Overview */
  .rtd-ov-dl {
    display: flex;
    flex-direction: column;
    gap: 0;
  }

  .rtd-ov-row {
    display: flex;
    align-items: flex-start;
    gap: var(--space-4);
    padding: var(--space-3) 0;
    border-bottom: 1px solid var(--border);
  }

  .rtd-ov-row:last-child {
    border-bottom: none;
  }

  .rtd-ov-dt {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg-muted);
    width: 140px;
    flex-shrink: 0;
  }

  .rtd-ov-dd {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg);
    flex: 1;
  }

  .rtd-mono {
    font-family: var(--font-mono) !important;
    font-size: var(--text-xs) !important;
  }

  .rtd-caps {
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-1);
  }

  .rtd-cap-pill {
    display: inline-flex;
    align-items: center;
    height: 20px;
    padding: 0 8px;
    border-radius: 9999px;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    color: var(--fg-muted);
    background: color-mix(in oklch, var(--fg) 6%, transparent 94%);
    border: 1px solid var(--border);
  }

  .rtd-none {
    color: var(--fg-subtle);
    font-style: italic;
  }

  /* Skeletons */
  .rtd-ov-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  :global(.rtd-sk-crumb) {
    height: 13px !important;
    width: 80px !important;
    border-radius: 4px !important;
    display: inline-block !important;
  }

  :global(.rtd-sk-row) {
    height: 32px !important;
    width: 100% !important;
    border-radius: var(--radius-md) !important;
  }

  :global(.rtd-sk-form) {
    height: 200px !important;
    width: 100% !important;
    border-radius: var(--radius-lg) !important;
  }

  /* Test result checks */
  .rtd-check {
    font-family: var(--font-mono);
    font-size: var(--text-xs);
    line-height: 1.6;
  }

  .rtd-check[data-level='error'] { color: var(--signal-error); }
  .rtd-check[data-level='warn']  { color: var(--signal-warn); }

  /* Deferred content */
  .rtd-deferred {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
    padding: var(--space-8) 0;
    text-align: center;
  }

  /* Table headings */
  :global(.rtd-th) {
    font-family: var(--font-sans) !important;
    font-size: var(--text-xs) !important;
    font-weight: 600 !important;
    color: var(--fg-muted) !important;
    padding: var(--space-2) var(--space-3) !important;
    text-align: left !important;
    border-bottom: 1px solid var(--border) !important;
    letter-spacing: var(--tracking-xs) !important;
    text-transform: uppercase !important;
  }
</style>
