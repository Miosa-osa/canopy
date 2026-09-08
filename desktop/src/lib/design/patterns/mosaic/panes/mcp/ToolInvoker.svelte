<script lang="ts">
/**
 * ToolInvoker — inline test-invocation form for a registered tool.
 *
 * Reuses (no duplication):
 *   - RuntimeConfigForm (declarative ConfigFieldSchema-driven form)
 *   - sessionsQuery (existing TanStack factory)
 *   - dispatchToolMutation → POST /api/v1/agents/tools/:tool_name
 *
 * Translates the tool's JSON-Schema `parameters.properties` map into the
 * `ConfigFieldSchema[]` shape the existing form expects. Falls back to a raw
 * JSON textarea when a property has no representable type.
 *
 * CSS prefix: ti-
 */
import { createMutation, createQuery } from '@tanstack/svelte-query';
import { dispatchToolMutation } from '$lib/api/queries/mcp.js';
import { sessionsQuery } from '$lib/api/queries/sessions.js';
import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Button from '$lib/design/foundation/button/Button.svelte';
import Select from '$lib/design/foundation/select/Select.svelte';
import Textarea from '$lib/design/foundation/textarea/Textarea.svelte';
import RuntimeConfigForm from '$lib/design/patterns/RuntimeConfigForm.svelte';
import type { RegisteredTool, ToolDispatchResponse, ToolParam } from '$lib/domain/mcp/types.js';
import type { ConfigFieldSchema } from '$lib/domain/runtimes/types.js';

interface Props {
  tool: RegisteredTool;
  onClose: () => void;
}

let { tool, onClose }: Props = $props();

// Sessions list — needed because /agents/tools/:tool_name requires session_id.
const sessions = createQuery(sessionsQuery({ limit: 50 }));
const dispatch = createMutation({ ...dispatchToolMutation() });

let sessionId = $state('');
let useRawJson = $state(false);
let rawJson = $state('{}');
let rawJsonError = $state<string | null>(null);
let result = $state<ToolDispatchResponse | null>(null);
let invokeError = $state<string | null>(null);

// Build a sessions select option list. The first available session is the
// default; selector lets the user pick another.
const sessionOptions = $derived(
  ($sessions.data ?? []).map((s) => ({
    value: s.id,
    label: s.id.slice(0, 8) + ' — ' + (s.runtimeType ?? 'session'),
  }))
);

$effect(() => {
  if (!sessionId && sessionOptions.length > 0) {
    sessionId = sessionOptions[0]!.value;
  }
});

/**
 * Convert a tool's `parameters.properties` map into a flat
 * `ConfigFieldSchema[]` for RuntimeConfigForm.
 *
 * - `string` with `enum` → select
 * - `string` / `number` / `integer` → text/number input
 * - `boolean` → toggle
 * - other (object/array) → falls back to "raw JSON" mode for the whole form.
 */
function schemaToFields(t: RegisteredTool): {
  fields: ConfigFieldSchema[];
  forceRaw: boolean;
} {
  const props = t.parameters?.properties;
  if (!props || Object.keys(props).length === 0) {
    return { fields: [], forceRaw: false };
  }
  const required = new Set(t.parameters?.required ?? []);
  const fields: ConfigFieldSchema[] = [];
  let forceRaw = false;

  for (const [key, raw] of Object.entries(props)) {
    const p = (raw ?? {}) as ToolParam;
    const type = p.type ?? 'string';

    if (Array.isArray(p.enum) && p.enum.length > 0) {
      fields.push({
        key,
        label: key,
        type: 'select',
        required: required.has(key),
        description: p.description,
        options: p.enum.map((v) => ({ value: String(v), label: String(v) })),
      });
      continue;
    }

    if (type === 'string') {
      fields.push({
        key,
        label: key,
        type: 'text',
        required: required.has(key),
        description: p.description,
      });
    } else if (type === 'integer' || type === 'number') {
      fields.push({
        key,
        label: key,
        type: 'number',
        required: required.has(key),
        description: p.description,
      });
    } else if (type === 'boolean') {
      fields.push({
        key,
        label: key,
        type: 'toggle',
        required: required.has(key),
        description: p.description,
      });
    } else {
      // object / array — drop into raw JSON mode for the whole form.
      forceRaw = true;
    }
  }

  return { fields, forceRaw };
}

const fieldsInfo = $derived(schemaToFields(tool));

$effect(() => {
  // Reset display when tool changes.
  void tool.name;
  result = null;
  invokeError = null;
  rawJsonError = null;
  rawJson = '{}';
  useRawJson = fieldsInfo.forceRaw;
});

/** Coerce text values from RuntimeConfigForm back to numbers/booleans. */
function coerceValues(
  raw: Record<string, unknown>,
  fields: ConfigFieldSchema[]
): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const f of fields) {
    const v = raw[f.key];
    if (v === undefined || v === '' || v === null) continue;
    if (f.type === 'number') {
      const n = Number(v);
      out[f.key] = Number.isFinite(n) ? n : v;
    } else if (f.type === 'toggle') {
      out[f.key] = Boolean(v);
    } else {
      out[f.key] = v;
    }
  }
  return out;
}

async function handleSubmit(values: Record<string, unknown>): Promise<void> {
  invokeError = null;
  result = null;
  if (!sessionId) {
    invokeError = 'Pick a session first — dispatch needs a session_id.';
    return;
  }
  const params = coerceValues(values, fieldsInfo.fields);
  await runDispatch(params);
}

async function handleRawSubmit(): Promise<void> {
  invokeError = null;
  rawJsonError = null;
  result = null;
  if (!sessionId) {
    invokeError = 'Pick a session first — dispatch needs a session_id.';
    return;
  }
  let params: Record<string, unknown>;
  try {
    const parsed = JSON.parse(rawJson);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      rawJsonError = 'Params must be a JSON object.';
      return;
    }
    params = parsed as Record<string, unknown>;
  } catch (err) {
    rawJsonError = err instanceof Error ? err.message : 'Invalid JSON';
    return;
  }
  await runDispatch(params);
}

async function runDispatch(params: Record<string, unknown>): Promise<void> {
  try {
    const resp = await $dispatch.mutateAsync({
      toolName: tool.name,
      body: { sessionId, params },
    });
    result = resp;
  } catch (err) {
    invokeError = err instanceof Error ? err.message : String(err);
  }
}
</script>

<section class="ti-root" aria-label="Test invocation for {tool.name}">
  <header class="ti-header">
    <h3 class="ti-title">Test invocation</h3>
    <Button variant="plain" size="default" onclick={onClose} aria-label="Close invoker">
      Close
    </Button>
  </header>

  <div class="ti-row">
    <label class="ti-label" for="ti-session">Session</label>
    {#if $sessions.isLoading}
      <p class="ti-hint">Loading sessions…</p>
    {:else if sessionOptions.length === 0}
      <Alert variant="error">
        No sessions found. Start one in the Sessions module before dispatching tools.
      </Alert>
    {:else}
      <Select
        options={sessionOptions}
        value={sessionId}
        onValueChange={(v) => (sessionId = v)}
      />
    {/if}
  </div>

  {#if fieldsInfo.fields.length > 0 && !useRawJson}
    <RuntimeConfigForm
      schema={fieldsInfo.fields}
      onSave={handleSubmit}
      isSaving={$dispatch.isPending}
    />
    <button class="ti-toggle" type="button" onclick={() => (useRawJson = true)}>
      Use raw JSON instead
    </button>
  {:else}
    <div class="ti-row">
      <label class="ti-label" for="ti-raw">Params (JSON)</label>
      <Textarea
        id="ti-raw"
        rows={8}
        bind:value={rawJson}
        placeholder={'{ "key": "value" }'}
      />
      {#if rawJsonError}
        <Alert variant="error">{rawJsonError}</Alert>
      {/if}
      <div class="ti-actions">
        <Button
          variant="primary"
          onclick={handleRawSubmit}
          loading={$dispatch.isPending}
        >
          Dispatch
        </Button>
        {#if !fieldsInfo.forceRaw && fieldsInfo.fields.length > 0}
          <Button variant="plain" onclick={() => (useRawJson = false)}>
            Use form
          </Button>
        {/if}
      </div>
    </div>
  {/if}

  {#if invokeError}
    <Alert variant="error" dismissible ondismiss={() => (invokeError = null)}>
      {invokeError}
    </Alert>
  {/if}

  {#if result}
    <div class="ti-result" data-ok={result.ok}>
      <div class="ti-result__header">
        Result — {result.ok ? 'ok' : result.pendingReview ? 'pending review' : 'error'}
      </div>
      <pre class="ti-result__body"><code>{JSON.stringify(result, null, 2)}</code></pre>
    </div>
  {/if}
</section>

<style>
  .ti-root {
    display: flex;
    flex-direction: column;
    gap: 10px;
    padding: 16px;
    border-bottom: 1px solid var(--border);
    background: color-mix(in oklch, var(--fg) 3%, transparent);
    font-family: var(--font-sans);
  }

  .ti-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .ti-title {
    margin: 0;
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .ti-row { display: flex; flex-direction: column; gap: 6px; }

  .ti-label {
    font-size: 11px;
    font-weight: 600;
    color: var(--fg-muted);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }

  .ti-hint {
    margin: 0;
    color: var(--fg-subtle);
    font-size: var(--text-sm);
  }

  .ti-actions { display: flex; gap: 8px; }

  .ti-toggle {
    align-self: flex-start;
    border: none;
    background: transparent;
    color: var(--fg-muted);
    font-size: 11px;
    cursor: pointer;
    padding: 4px 0;
    text-decoration: underline;
  }
  .ti-toggle:hover { color: var(--fg); }

  .ti-result {
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    overflow: hidden;
    background: var(--bg);
  }

  .ti-result[data-ok='true'] {
    border-color: color-mix(in oklch, var(--cnp-accent, oklch(0.72 0.18 145)) 60%, var(--border));
  }

  .ti-result__header {
    padding: 6px 10px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    border-bottom: 1px solid var(--border);
    color: var(--fg-muted);
  }

  .ti-result__body {
    margin: 0;
    padding: 10px 12px;
    font-family: var(--font-mono, ui-monospace, monospace);
    font-size: 11px;
    line-height: 1.45;
    overflow: auto;
    max-height: 240px;
    white-space: pre;
  }
</style>
