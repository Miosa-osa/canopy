/**
 * Canopy HTTP API client.
 *
 * Thin fetch wrapper pointing at the Phoenix backend.
 * Handles JSON parsing, error extraction, and both wrapped ({data:...})
 * and unwrapped response shapes from the OpenAPISpex-generated endpoints.
 *
 * Conversion layer (at the boundary, so the rest of the app never sees snake_case):
 *   GET responses  → auto-converted snake_case → camelCase via toCamel()
 *   POST/PUT/PATCH → auto-converted camelCase → snake_case via toSnake()
 *
 * Keys at depths matched by SKIP_KEYS are NOT recursed into — their nested
 * structure is preserved verbatim. This protects free-form jsonb columns
 * (auth_profile, config, metadata, etc.) from accidental key mangling.
 *
 * To opt out of auto-conversion for a single call, pass { rawKeys: true }
 * as the last opts argument to apiGet / apiPost / apiPut / apiPatch.
 */

export const API_BASE = 'http://localhost:9190/api/v1';

/** Non-2xx response from the Phoenix API. */
export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

/**
 * Keys whose values are NOT recursed into during conversion.
 * Add any free-form jsonb column key here to preserve its internal structure.
 */
export const CONVERSION_SKIP_KEYS = new Set([
  'auth_profile',
  'authProfile',
  'config',
  'meta',
  'metadata',
  'tool_args',
  'toolArgs',
  'params',
  'values',
  'body_json',
  'bodyJson',
  'content',
]);

type PlainObj = Record<string, unknown>;

function isPlainObject(v: unknown): v is PlainObj {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/** toCamel with skip-key protection for free-form jsonb fields. */
function toCamelSafe(value: unknown, depth = 0): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => toCamelSafe(item, depth));
  }
  if (isPlainObject(value)) {
    const out: PlainObj = {};
    for (const [k, v] of Object.entries(value)) {
      const camelKey = k.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
      // Preserve the value verbatim if this key is on the blocklist
      out[camelKey] =
        CONVERSION_SKIP_KEYS.has(k) || CONVERSION_SKIP_KEYS.has(camelKey)
          ? v
          : toCamelSafe(v, depth + 1);
    }
    return out;
  }
  return value;
}

/** toSnake with skip-key protection for free-form jsonb fields. */
function toSnakeSafe(value: unknown, depth = 0): unknown {
  if (Array.isArray(value)) {
    return value.map((item) => toSnakeSafe(item, depth));
  }
  if (isPlainObject(value)) {
    const out: PlainObj = {};
    for (const [k, v] of Object.entries(value)) {
      const snakeKey = k.replace(/([A-Z])/g, (c) => `_${c.toLowerCase()}`);
      // Preserve the value verbatim if this key is on the blocklist
      out[snakeKey] =
        CONVERSION_SKIP_KEYS.has(k) || CONVERSION_SKIP_KEYS.has(snakeKey)
          ? v
          : toSnakeSafe(v, depth + 1);
    }
    return out;
  }
  return value;
}

type FetchOpts = Omit<RequestInit, 'method'> & { rawKeys?: boolean };

async function handleResponse<T>(res: Response, rawKeys = false): Promise<T> {
  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const body = (await res.json()) as { error?: string; message?: string };
      message = body.error ?? body.message ?? message;
    } catch {
      // non-JSON error body — keep the status message
    }
    throw new ApiError(res.status, message);
  }

  // 204 No Content — return void cast
  if (res.status === 204) {
    return undefined as unknown as T;
  }

  const json = (await res.json()) as { data?: T } | T;

  // Unwrap Phoenix `{data: ...}` envelope if present
  let payload: unknown =
    json !== null &&
    typeof json === 'object' &&
    'data' in json &&
    (json as { data?: unknown }).data !== undefined
      ? (json as { data: unknown }).data
      : json;

  if (!rawKeys) {
    payload = toCamelSafe(payload);
  }

  return payload as T;
}

/** GET /api/v1/:path */
export async function apiGet<T>(path: string, opts?: FetchOpts): Promise<T> {
  const { rawKeys, ...fetchOpts } = opts ?? {};
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'GET',
    headers: { 'Content-Type': 'application/json' },
    ...fetchOpts,
  });
  return handleResponse<T>(res, rawKeys);
}

/** POST /api/v1/:path */
export async function apiPost<T>(path: string, body?: unknown, opts?: FetchOpts): Promise<T> {
  const { rawKeys, ...fetchOpts } = opts ?? {};
  const serialized =
    body !== undefined ? JSON.stringify(rawKeys ? body : toSnakeSafe(body)) : undefined;
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: serialized,
    ...fetchOpts,
  });
  return handleResponse<T>(res, rawKeys);
}

/** PUT /api/v1/:path */
export async function apiPut<T>(path: string, body?: unknown, opts?: FetchOpts): Promise<T> {
  const { rawKeys, ...fetchOpts } = opts ?? {};
  const serialized =
    body !== undefined ? JSON.stringify(rawKeys ? body : toSnakeSafe(body)) : undefined;
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: serialized,
    ...fetchOpts,
  });
  return handleResponse<T>(res, rawKeys);
}

/** PATCH /api/v1/:path */
export async function apiPatch<T>(path: string, body?: unknown, opts?: FetchOpts): Promise<T> {
  const { rawKeys, ...fetchOpts } = opts ?? {};
  const serialized =
    body !== undefined ? JSON.stringify(rawKeys ? body : toSnakeSafe(body)) : undefined;
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: serialized,
    ...fetchOpts,
  });
  return handleResponse<T>(res, rawKeys);
}

/** DELETE /api/v1/:path */
export async function apiDelete<T = void>(path: string, opts?: FetchOpts): Promise<T> {
  const { rawKeys, ...fetchOpts } = opts ?? {};
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json' },
    ...fetchOpts,
  });
  return handleResponse<T>(res, rawKeys);
}
