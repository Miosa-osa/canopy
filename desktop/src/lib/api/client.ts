/**
 * Canopy HTTP API client.
 *
 * Thin fetch wrapper pointing at the Phoenix backend.
 * Handles JSON parsing, error extraction, and both wrapped ({data:...})
 * and unwrapped response shapes from the OpenAPISpex-generated endpoints.
 */

export const API_BASE = "http://localhost:9190/api/v1";

/** Non-2xx response from the Phoenix API. */
export class ApiError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

type FetchOpts = Omit<RequestInit, "method">;

async function handleResponse<T>(res: Response): Promise<T> {
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
  if (
    json !== null &&
    typeof json === "object" &&
    "data" in json &&
    json.data !== undefined
  ) {
    return (json as { data: T }).data;
  }

  return json as T;
}

/** GET /api/v1/:path */
export async function apiGet<T>(path: string, opts?: FetchOpts): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "GET",
    headers: { "Content-Type": "application/json" },
    ...opts,
  });
  return handleResponse<T>(res);
}

/** POST /api/v1/:path */
export async function apiPost<T>(
  path: string,
  body?: unknown,
  opts?: FetchOpts,
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    ...opts,
  });
  return handleResponse<T>(res);
}

/** PUT /api/v1/:path */
export async function apiPut<T>(
  path: string,
  body?: unknown,
  opts?: FetchOpts,
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    ...opts,
  });
  return handleResponse<T>(res);
}

/** PATCH /api/v1/:path */
export async function apiPatch<T>(
  path: string,
  body?: unknown,
  opts?: FetchOpts,
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : undefined,
    ...opts,
  });
  return handleResponse<T>(res);
}

/** DELETE /api/v1/:path */
export async function apiDelete<T = void>(
  path: string,
  opts?: FetchOpts,
): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    ...opts,
  });
  return handleResponse<T>(res);
}
