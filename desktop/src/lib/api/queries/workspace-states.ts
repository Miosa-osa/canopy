/**
 * TanStack Query factories + helpers for the per-workspace state store.
 *
 * Endpoints (see `backend/lib/canopy_web/controllers/workspace_states_controller.ex`):
 *   GET    /api/v1/workspaces/:slug/state              — full state map
 *   GET    /api/v1/workspaces/:slug/state/:key         — single value
 *   PUT    /api/v1/workspaces/:slug/state/:key         — upsert
 *   DELETE /api/v1/workspaces/:slug/state/:key         — drop
 *
 * Auto-conversion: the underlying `apiGet/apiPut/apiDelete` helpers convert
 * snake_case → camelCase on the way in, but for this resource the value
 * payload is module-defined free-form JSON. We pass `rawKeys: true` so the
 * stored value is preserved verbatim (no key mangling on nested objects).
 */

import { apiDelete, apiGet, apiPut } from '$lib/api/client.js';
import { activeWorkspace } from '$lib/stores/active-workspace.svelte.js';

// ── Wire types (one row of the state table) ──────────────────────────────────

export interface WorkspaceStateValueResponse<T = unknown> {
  key: string;
  value: T;
  // ISO-8601 (snake_case from server, no conversion since rawKeys=true).
  updated_at?: string | null;
}

export interface WorkspaceStateMapResponse {
  workspace_slug: string;
  data: Record<string, unknown>;
}

// ── Raw API ─────────────────────────────────────────────────────────────────

/** GET full state map for a workspace. */
export async function listWorkspaceState(slug: string): Promise<Record<string, unknown>> {
  const raw = await apiGet<WorkspaceStateMapResponse>(`/workspaces/${slug}/state`, {
    rawKeys: true,
  });
  return raw.data ?? {};
}

/** GET a single value. Returns `null` when the key is absent (404 → null). */
export async function getWorkspaceState<T = unknown>(slug: string, key: string): Promise<T | null> {
  try {
    const raw = await apiGet<WorkspaceStateValueResponse<T>>(
      `/workspaces/${slug}/state/${encodeURIComponent(key)}`,
      { rawKeys: true }
    );
    return raw.value ?? null;
  } catch (err: unknown) {
    if (err instanceof Error && /404|not_found/i.test(err.message)) return null;
    throw err;
  }
}

/** PUT (upsert) a value. Body is sent verbatim — no snake_case conversion. */
export async function putWorkspaceState<T = unknown>(
  slug: string,
  key: string,
  value: T
): Promise<WorkspaceStateValueResponse<T>> {
  return apiPut<WorkspaceStateValueResponse<T>>(
    `/workspaces/${slug}/state/${encodeURIComponent(key)}`,
    { value },
    { rawKeys: true }
  );
}

/** DELETE a single key. */
export async function deleteWorkspaceState(slug: string, key: string): Promise<void> {
  await apiDelete<unknown>(`/workspaces/${slug}/state/${encodeURIComponent(key)}`);
}

// ── TanStack Query option factories ──────────────────────────────────────────

/** Query options for the full state map of a workspace. */
export function workspaceStateMapQuery(slug: string | null) {
  return {
    queryKey: ['workspaces', slug, 'state'] as const,
    queryFn: () => listWorkspaceState(slug as string),
    staleTime: 5_000,
    enabled: Boolean(slug),
  };
}

/** Query options for a single workspace state key. */
export function workspaceStateQuery<T = unknown>(slug: string | null, key: string) {
  return {
    queryKey: ['workspaces', slug, 'state', key] as const,
    queryFn: () => getWorkspaceState<T>(slug as string, key),
    staleTime: 5_000,
    enabled: Boolean(slug) && Boolean(key),
  };
}

// ── Hook: useWorkspaceState ──────────────────────────────────────────────────
//
// Usage from a Svelte 5 component:
//
//   const layout = useWorkspaceState<MosaicTree>("mosaic.layout", DEFAULT);
//   $effect(() => { /* react to layout.value */ });
//   layout.set(nextTree);            // debounced PUT, optimistic UI
//
// `useWorkspaceState` is intentionally framework-agnostic — it returns a
// plain object with rune-backed reactive state. Callers can pass a slug
// override; otherwise the hook tracks `activeWorkspace.slug`.

const DEBOUNCE_MS = 500;

/**
 * Reactive workspace-scoped state cell.
 *
 * Hook contract:
 *   * `value`   — current value (rune-reactive); reads from server on first
 *     mount, then optimistic-updated on `set()`.
 *   * `loading` — true until the initial GET resolves.
 *   * `error`   — most-recent error, or null.
 *   * `set(v)`  — schedules a debounced PUT (500 ms). Optimistic UI: `value`
 *     updates immediately; if the PUT fails the value rolls back to the
 *     previous server-confirmed value and `error` is populated.
 *   * `flush()` — fires any pending PUT immediately (e.g. before unmount).
 *   * `dispose()` — clears any pending timer (call from `onDestroy`).
 */
export interface WorkspaceStateCell<T> {
  value: T;
  loading: boolean;
  error: Error | null;
  set: (next: T) => void;
  flush: () => Promise<void>;
  dispose: () => void;
}

/**
 * Create a reactive cell bound to a workspace state key. Auto-tracks the
 * active workspace's slug unless `slugOverride` is provided.
 */
export function useWorkspaceState<T>(
  key: string,
  defaultValue: T,
  slugOverride?: string | null
): WorkspaceStateCell<T> {
  const cell = $state({
    value: defaultValue,
    loading: true,
    error: null as Error | null,
  });

  // Last server-confirmed value — used for rollback on PUT failure.
  let confirmed: T = defaultValue;
  let pendingTimer: ReturnType<typeof setTimeout> | null = null;
  let pendingValue: T = defaultValue;
  let lastSlug: string | null = null;

  const resolveSlug = (): string | null =>
    slugOverride !== undefined ? slugOverride : activeWorkspace.slug;

  // Initial load (and re-load when slug changes).
  $effect(() => {
    const slug = resolveSlug();
    if (slug === null) {
      cell.value = defaultValue;
      cell.loading = false;
      confirmed = defaultValue;
      lastSlug = null;
      return;
    }

    if (slug === lastSlug) return;
    lastSlug = slug;
    cell.loading = true;

    getWorkspaceState<T>(slug, key)
      .then((server) => {
        const next = (server ?? defaultValue) as T;
        cell.value = next;
        confirmed = next;
        cell.loading = false;
        cell.error = null;
      })
      .catch((err: Error) => {
        cell.error = err;
        cell.loading = false;
      });
  });

  function flushNow(): Promise<void> {
    if (pendingTimer === null) return Promise.resolve();
    clearTimeout(pendingTimer);
    pendingTimer = null;

    const slug = resolveSlug();
    if (slug === null) return Promise.resolve();

    const valueToSend = pendingValue;
    return putWorkspaceState<T>(slug, key, valueToSend)
      .then(() => {
        confirmed = valueToSend;
        cell.error = null;
      })
      .catch((err: Error) => {
        // Rollback on failure.
        cell.value = confirmed;
        cell.error = err;
      });
  }

  function set(next: T): void {
    // Optimistic UI: update immediately so consumers see the new value.
    cell.value = next;
    pendingValue = next;

    if (pendingTimer !== null) clearTimeout(pendingTimer);
    pendingTimer = setTimeout(() => {
      void flushNow();
    }, DEBOUNCE_MS);
  }

  function dispose(): void {
    if (pendingTimer !== null) {
      clearTimeout(pendingTimer);
      pendingTimer = null;
    }
  }

  return {
    get value(): T {
      return cell.value;
    },
    set value(_v: T) {
      // No-op setter — consumers should call `set()` explicitly so the
      // debounce + optimistic-UI flow is engaged.
    },
    get loading(): boolean {
      return cell.loading;
    },
    get error(): Error | null {
      return cell.error;
    },
    set,
    flush: flushNow,
    dispose,
  };
}

/** Debounce window in milliseconds (exported for tests). */
export const WORKSPACE_STATE_DEBOUNCE_MS = DEBOUNCE_MS;
