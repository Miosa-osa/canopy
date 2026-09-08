/**
 * Fetch scrollback bytes for a terminal session.
 *
 * Returns raw ANSI bytes as a Uint8Array (decoded from the base64 envelope
 * the backend sends). Pass `lastN` for cold restore; pass `from` for polling.
 */

const API_BASE = 'http://localhost:9190/api/v1';

export interface ScrollbackResult {
  data: Uint8Array;
  offset: number;
  totalBytes: number;
}

export async function fetchScrollback(
  sessionId: string,
  opts: { lastN?: number; from?: number } = {}
): Promise<ScrollbackResult> {
  const params = new URLSearchParams();
  if (opts.from !== undefined) params.set('from', String(opts.from));
  else if (opts.lastN !== undefined) params.set('last_n', String(opts.lastN));

  const url = `${API_BASE}/sessions/${sessionId}/scrollback?${params}`;
  const res = await fetch(url);

  if (!res.ok) throw new Error(`scrollback fetch failed: ${res.status}`);

  const body = (await res.json()) as {
    data: string;
    offset: number;
    total_bytes: number;
  };

  const bytes = body.data
    ? Uint8Array.from(atob(body.data), (c) => c.charCodeAt(0))
    : new Uint8Array(0);

  return { data: bytes, offset: body.offset, totalBytes: body.total_bytes };
}
