/**
 * TanStack Query factories for the /chat/threads resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { API_BASE, ApiError, apiDelete, apiGet, apiPatch, apiPost } from '$lib/api/client.js';
import type {
  ContinueThreadBody,
  ContinueThreadResponse,
  CreateThreadBody,
  CreateThreadResponse,
  Thread,
  ThreadDetail,
  ThreadFilters,
  UpdateThreadBody,
} from '$lib/domain/chat/types.js';

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listThreads(filters?: ThreadFilters): Promise<Thread[]> {
  const params = new URLSearchParams();
  if (filters?.userId) params.set('user_id', filters.userId);
  if (filters?.agentSlug) params.set('agent_slug', filters.agentSlug);
  if (filters?.archived !== undefined) params.set('archived', String(filters.archived));
  if (filters?.pinned !== undefined) params.set('pinned', String(filters.pinned));
  const qs = params.toString();
  return apiGet<Thread[]>(`/chat/threads${qs ? `?${qs}` : ''}`);
}

export function getThread(id: string): Promise<ThreadDetail> {
  return apiGet<ThreadDetail>(`/chat/threads/${id}`);
}

export function createThread(body: CreateThreadBody): Promise<CreateThreadResponse> {
  return apiPost<CreateThreadResponse>('/chat/threads', body);
}

export function continueThread(
  id: string,
  body: ContinueThreadBody
): Promise<ContinueThreadResponse> {
  return apiPost<ContinueThreadResponse>(`/chat/threads/${id}/continue`, body);
}

export function updateThread(id: string, body: UpdateThreadBody): Promise<Thread> {
  return apiPatch<Thread>(`/chat/threads/${id}`, body);
}

export function deleteThread(id: string): Promise<void> {
  return apiDelete<void>(`/chat/threads/${id}`);
}

/**
 * Fetches the thread export as a raw markdown string.
 * Uses a direct fetch because the backend returns text/markdown, not JSON.
 * Not a mutation — call directly when the user triggers a download.
 */
export async function exportThreadMarkdown(id: string): Promise<string> {
  const res = await fetch(`${API_BASE}/chat/threads/${id}/export`, {
    method: 'GET',
    headers: { Accept: 'text/markdown, text/plain, */*' },
  });
  if (!res.ok) {
    let message = `HTTP ${res.status}`;
    try {
      const body = (await res.json()) as { error?: string; message?: string };
      message = body.error ?? body.message ?? message;
    } catch {
      // non-JSON error body
    }
    throw new ApiError(res.status, message);
  }
  return res.text();
}

// ── TanStack Query option factories ─────────────────────────────────────────

/** Query options for the thread list with optional filters. */
export function threadsQuery(filters?: ThreadFilters) {
  return {
    queryKey: ['chat', 'threads', filters ?? {}] as const,
    queryFn: () => listThreads(filters),
    staleTime: 10_000,
  };
}

/** Query options for a single thread detail (thread + full transcript). */
export function threadQuery(id: string) {
  return {
    queryKey: ['chat', 'threads', id] as const,
    queryFn: () => getThread(id),
    staleTime: 5_000,
    enabled: Boolean(id),
  };
}

/** Mutation options to create a new thread + initial session. */
export function createThreadMutation() {
  return {
    mutationKey: ['chat', 'threads', 'create'] as const,
    mutationFn: (body: CreateThreadBody) => createThread(body),
  };
}

/** Mutation options to continue an existing thread (new session turn). */
export function continueThreadMutation(threadId: string) {
  return {
    mutationKey: ['chat', 'threads', threadId, 'continue'] as const,
    mutationFn: (body: ContinueThreadBody) => continueThread(threadId, body),
  };
}

/** Mutation options to rename/pin/archive a thread. */
export function updateThreadMutation() {
  return {
    mutationKey: ['chat', 'threads', 'update'] as const,
    mutationFn: ({ id, body }: { id: string; body: UpdateThreadBody }) => updateThread(id, body),
  };
}

/** Mutation options to delete a thread. */
export function deleteThreadMutation() {
  return {
    mutationKey: ['chat', 'threads', 'delete'] as const,
    mutationFn: (id: string) => deleteThread(id),
  };
}
