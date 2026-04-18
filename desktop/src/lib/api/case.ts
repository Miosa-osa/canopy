/**
 * Case transformation utilities for API boundary crossing.
 *
 * Backend (Elixir/Phoenix) uses snake_case keys.
 * Frontend (TypeScript/Svelte) uses camelCase keys.
 *
 * toCamel  — converts response payloads from snake_case → camelCase (recursive)
 * toSnake  — converts request bodies from camelCase → snake_case (recursive)
 *
 * Both handle nested objects and arrays. Non-string keys and non-plain-object
 * values are passed through unchanged.
 *
 * LOC target: ≤ 60.
 */

/** Convert a single snake_case key to camelCase. */
function snakeToCamel(key: string): string {
  return key.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
}

/** Convert a single camelCase key to snake_case. */
function camelToSnake(key: string): string {
  return key.replace(/([A-Z])/g, (c) => `_${c.toLowerCase()}`);
}

type PlainObject = Record<string, unknown>;

function isPlainObject(value: unknown): value is PlainObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Recursively convert all object keys from snake_case to camelCase. */
export function toCamel(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(toCamel);
  }
  if (isPlainObject(value)) {
    const out: PlainObject = {};
    for (const [k, v] of Object.entries(value)) {
      out[snakeToCamel(k)] = toCamel(v);
    }
    return out;
  }
  return value;
}

/** Recursively convert all object keys from camelCase to snake_case. */
export function toSnake(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(toSnake);
  }
  if (isPlainObject(value)) {
    const out: PlainObject = {};
    for (const [k, v] of Object.entries(value)) {
      out[camelToSnake(k)] = toSnake(v);
    }
    return out;
  }
  return value;
}
