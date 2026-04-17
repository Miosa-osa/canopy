<script lang="ts">
/**
 * RuntimeConfigForm — declarative configuration form driven by a ConfigFieldSchema[].
 *
 * Field type → Foundation primitive mapping:
 *   text    → Input (type="text")
 *   number  → Input (type="number")
 *   select  → Select
 *   toggle  → Checkbox
 *
 * Required fields trigger an Alert on submit if empty.
 * Calls onSave(values) and signals completion via isSubmitting state.
 *
 * CSS prefix: rcf- (RuntimeConfigForm)
 */

import Alert from '$lib/design/foundation/alert/Alert.svelte';
import Checkbox from '$lib/design/foundation/checkbox/Checkbox.svelte';
import Input from '$lib/design/foundation/input/Input.svelte';
import Select from '$lib/design/foundation/select/Select.svelte';
import type { ConfigFieldSchema } from '$lib/domain/runtimes/types.js';

interface Props {
  schema: ConfigFieldSchema[];
  initial?: Record<string, unknown>;
  onSave: (values: Record<string, unknown>) => Promise<void>;
  onCancel?: () => void;
}

let { schema, initial = {}, onSave, onCancel }: Props = $props();

// Reactive values object keyed by schema field keys.
// Use $derived for initial computation from schema (Svelte 5 pattern).
const defaultValues = $derived(
  Object.fromEntries(
    schema.map((f) => [f.key, initial[f.key] ?? (f.type === 'toggle' ? false : '')])
  )
);

let values = $state<Record<string, unknown>>({});

$effect(() => {
  if (Object.keys(values).length === 0) {
    values = { ...defaultValues };
  }
});

let isSubmitting = $state(false);
let validationErrors = $state<string[]>([]);

async function handleSubmit(e: SubmitEvent) {
  e.preventDefault();
  validationErrors = [];

  // Required field validation.
  const missing = schema.filter((f) => f.required && !values[f.key]).map((f) => f.label);

  if (missing.length > 0) {
    validationErrors = [`Required fields missing: ${missing.join(', ')}`];
    return;
  }

  isSubmitting = true;
  try {
    await onSave({ ...values });
  } finally {
    isSubmitting = false;
  }
}

function updateValue(key: string, val: unknown) {
  values = { ...values, [key]: val };
}
</script>

<form class="rcf-form" onsubmit={handleSubmit} aria-label="Runtime configuration">
  {#if validationErrors.length > 0}
    <Alert variant="error" dismissible ondismiss={() => (validationErrors = [])}>
      {validationErrors.join(' ')}
    </Alert>
  {/if}

  {#each schema as field (field.key)}
    <div class="rcf-field">
      <label class="rcf-label" for="rcf-{field.key}">
        {field.label}
        {#if field.required}
          <span class="rcf-required" aria-hidden="true">*</span>
        {/if}
      </label>

      {#if field.description}
        <p class="rcf-description">{field.description}</p>
      {/if}

      {#if field.type === 'text' || field.type === 'number'}
        <Input
          id="rcf-{field.key}"
          type={field.type === 'number' ? 'number' : (field.secret ? 'password' : 'text')}
          placeholder={field.placeholder ?? ''}
          value={String(values[field.key] ?? '')}
          oninput={(e) => updateValue(field.key, (e.target as HTMLInputElement).value)}
          aria-required={field.required ?? false}
        />

      {:else if field.type === 'select' && field.options}
        <Select
          options={field.options}
          value={String(values[field.key] ?? '')}
          onValueChange={(v) => updateValue(field.key, v)}
        />

      {:else if field.type === 'toggle'}
        <Checkbox
          id="rcf-{field.key}"
          checked={Boolean(values[field.key])}
          label=""
          onchange={(v) => updateValue(field.key, v)}
        />
      {/if}
    </div>
  {/each}

  {#if schema.length === 0}
    <p class="rcf-empty">No configurable fields for this runtime.</p>
  {/if}

  <div class="rcf-actions">
    {#if onCancel}
      <button
        type="button"
        class="btn-rounded btn-rounded-ghost"
        onclick={onCancel}
        disabled={isSubmitting}
      >
        Cancel
      </button>
    {/if}

    <button
      type="submit"
      class="btn-pill btn-pill-primary"
      disabled={isSubmitting}
    >
      {#if isSubmitting}
        <span class="btn-pill-spinner" aria-hidden="true"></span>
        Saving…
      {:else}
        Save
      {/if}
    </button>
  </div>
</form>

<style>
  .rcf-form {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  .rcf-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }

  .rcf-label {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 500;
    color: var(--fg);
    letter-spacing: var(--tracking-sm);
    display: flex;
    align-items: center;
    gap: var(--space-1);
  }

  .rcf-required {
    color: var(--signal-error);
    font-size: var(--text-xs);
  }

  .rcf-description {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
    line-height: 1.5;
  }

  .rcf-empty {
    margin: 0;
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-subtle);
    font-style: italic;
    text-align: center;
    padding: var(--space-8) 0;
  }

  .rcf-actions {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: var(--space-2);
    padding-top: var(--space-2);
    border-top: 1px solid var(--border);
  }
</style>
