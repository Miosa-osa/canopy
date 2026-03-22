// src/lib/api/client.ts
// HTTP API client for the Canopy backend with mock fallback

import type {
  CanopyAgent,
  AgentCreateRequest,
  DashboardData,
  HealthResponse,
  Session,
  Schedule,
  HeartbeatRun,
  Issue,
  Goal,
  GoalTreeNode,
  Project,
  CostSummary,
  AgentCostBreakdown,
  ModelCostBreakdown,
  BudgetPolicy,
  ActivityEvent,
  InboxItem,
  Skill,
  Webhook,
  AlertRule,
  Integration,
  Adapter,
  Gateway,
  Workspace,
  Settings,
  AuditEntry,
  MemoryEntry,
  MemoryNamespace,
  MemoryCreateRequest,
  SpawnInstance,
  LogEntry,
  QueuedRequest,
  SendMessageRequest,
  SendMessageResponse,
  Signal,
  SignalPattern,
  SignalStats,
  BudgetIncident,
  Secret,
  SecretCreateRequest,
  Approval,
  ApprovalCreateRequest,
  Organization,
  OrganizationMembership,
  OrganizationCreateRequest,
  Label,
  LabelCreateRequest,
  Plugin,
  PluginLog,
  RoleAssignment,
  SidebarBadges,
  User,
  AgentTemplate,
  Document,
  DocumentTreeNode,
  DocumentRevision,
} from "./types";

// ── Configuration ─────────────────────────────────────────────────────────────

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://127.0.0.1:9089";
const API_PREFIX = "/api/v1";

let useMock = true;
let mockModule: typeof import("./mock/index") | null = null;

async function getMock() {
  if (!mockModule) {
    mockModule = await import("./mock/index");
  }
  return mockModule;
}

/**
 * Enable mock mode and notify the mock module so its internal guard allows
 * handleRequest calls. Also clears the response cache to prevent stale real
 * data from being served after a reconnect cycle.
 */
async function setMockEnabled(enabled: boolean): Promise<void> {
  useMock = enabled;
  // Best-effort: notify the mock module. The module may not be loaded yet when
  // mock mode is first activated on startup — that is fine because _mockAllowed
  // defaults to true inside the mock module.
  if (mockModule) {
    if (enabled) {
      mockModule.notifyMockEnabled();
    } else {
      mockModule.notifyMockDisabled();
      // Wipe mock-sourced localStorage so real data is never polluted by
      // leftover mock agents, sessions, etc.
      mockModule.clearAllMockData();
    }
  } else if (!enabled) {
    // Mock module not loaded yet but we're disabling mock — eagerly load it
    // just to clear localStorage so stale data doesn't survive.
    try {
      const mod = await getMock();
      mod.notifyMockDisabled();
      mod.clearAllMockData();
    } catch {
      // Non-fatal
    }
  }
}

// ── Token Store ───────────────────────────────────────────────────────────────

let _token: string | null = null;

export function getToken(): string | null {
  return _token;
}
export function setToken(token: string | null): void {
  _token = token;
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
// All API requests wait for auth to complete before firing.

let _authResolve: (() => void) | null = null;
const _authPromise: Promise<void> = new Promise<void>((resolve) => {
  _authResolve = resolve;
});

function resolveAuthGate(): void {
  if (_authResolve) {
    _authResolve();
    _authResolve = null;
  }
}

// ── Auth Initialization ───────────────────────────────────────────────────────

async function saveTokenToStore(token: string): Promise<void> {
  try {
    const { load: loadStore } = await import("@tauri-apps/plugin-store");
    const store = await loadStore("store.json", {
      autoSave: true,
      defaults: {},
    });
    await store.set("authToken", token);
    await store.save();
  } catch {
    /* non-fatal — not in Tauri or store unavailable */
  }
}

async function verifyToken(token: string): Promise<boolean> {
  try {
    // Use /agents (requires auth) rather than /health (no auth required).
    // /health returns 200 for any request regardless of token validity, so
    // using it here would make verifyToken() return true for stale or
    // invalid tokens, skipping re-login and sending unauthenticated requests.
    const res = await fetch(`${BASE_URL}${API_PREFIX}/agents`, {
      headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
    });
    return res.ok;
  } catch {
    return false;
  }
}

export async function login(email: string, password: string): Promise<string> {
  const response = await fetch(`${BASE_URL}${API_PREFIX}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) {
    throw new ApiError(response.status, "Login failed");
  }
  const data = (await response.json()) as { token: string; user: unknown };
  return data.token;
}

export async function initializeAuth(): Promise<void> {
  // 0. Probe backend — if it responds, disable mock mode
  try {
    const probe = await fetch(`${BASE_URL}${API_PREFIX}/health`, {
      signal: AbortSignal.timeout(3000),
    });
    if (probe.ok) {
      // setMockEnabled(false) clears the response cache, purges all mock
      // localStorage keys, and notifies the mock module — one call does all.
      clearCache();
      await setMockEnabled(false);
    }
  } catch {
    // Backend not running — stay in mock mode
    await setMockEnabled(true);
    resolveAuthGate();
    return;
  }

  // 1. Check Tauri store for a saved token
  try {
    const { load: loadStore } = await import("@tauri-apps/plugin-store");
    const store = await loadStore("store.json", {
      autoSave: true,
      defaults: {},
    });
    const stored = await store.get<string>("authToken");
    if (stored) _token = stored;
  } catch {
    // Not in Tauri or store unavailable
  }

  // 2. If we have a token, verify it is still valid
  if (_token) {
    const valid = await verifyToken(_token);
    if (valid) {
      resolveAuthGate();
      return;
    }
    _token = null;
  }

  // 3. No valid token — try dev auto-login (credentials from env only)
  const devEmail = import.meta.env.VITE_DEV_EMAIL;
  const devPassword = import.meta.env.VITE_DEV_PASSWORD;
  if (devEmail && devPassword) {
    try {
      const token = await login(devEmail, devPassword);
      _token = token;
      await saveTokenToStore(token);
    } catch {
      // Backend not ready or credentials rejected — fall back to mock mode
      await setMockEnabled(true);
    }
  } else {
    // No dev credentials and no stored token — fall back to mock mode so that
    // API calls don't fire unauthenticated requests and receive 401 responses.
    // The app can prompt for credentials and call setToken() + disableMock()
    // once the user logs in.
    await setMockEnabled(true);
  }

  // Open the auth gate so queued API requests can proceed
  resolveAuthGate();
}

// ── Typed Error ───────────────────────────────────────────────────────────────

export class ApiError extends Error {
  readonly status: number;
  readonly code: string | undefined;
  readonly body: unknown;

  constructor(status: number, message: string, body?: unknown) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.code =
      typeof body === "object" && body !== null && "code" in body
        ? String((body as Record<string, unknown>).code)
        : undefined;
    this.body = body;
  }
}

// ── Retry with Backoff ──────────────────────────────────────────────────────

const DEFAULT_RETRY = { maxRetries: 3, backoffMs: 1000, maxBackoff: 30000 };

async function withRetry<T>(
  fn: () => Promise<T>,
  config = DEFAULT_RETRY,
): Promise<T> {
  let lastError: Error = new Error("No attempts made");
  for (let attempt = 0; attempt < config.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;
      if (error instanceof ApiError && error.status < 500) throw error;
      const delay = Math.min(
        config.backoffMs * 2 ** attempt,
        config.maxBackoff,
      );
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastError;
}

// ── Response Cache ──────────────────────────────────────────────────────────

const responseCache = new Map<string, { data: unknown; timestamp: number }>();
const CACHE_TTL: Record<string, number> = {
  "/settings": 60_000,
  "/agents": 30_000,
  "/dashboard": 15_000,
  "/schedules": 30_000,
  "/costs": 30_000,
};

function getCacheTTL(path: string): number {
  for (const [prefix, ttl] of Object.entries(CACHE_TTL)) {
    if (path.startsWith(prefix)) return ttl;
  }
  return 0;
}

function getCached<T>(path: string): T | null {
  const entry = responseCache.get(path);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > getCacheTTL(path)) {
    responseCache.delete(path);
    return null;
  }
  return entry.data as T;
}

function setCache(path: string, data: unknown): void {
  if (getCacheTTL(path) > 0)
    responseCache.set(path, { data, timestamp: Date.now() });
}

export function clearCache(): void {
  responseCache.clear();
}

// ── Offline Queue ───────────────────────────────────────────────────────────

const offlineQueue: QueuedRequest[] = [];
export function getOfflineQueue(): readonly QueuedRequest[] {
  return offlineQueue;
}
export function getOfflineQueueSize(): number {
  return offlineQueue.length;
}

export async function flushOfflineQueue(): Promise<{
  succeeded: number;
  failed: number;
}> {
  let succeeded = 0,
    failed = 0;
  while (offlineQueue.length > 0) {
    const req = offlineQueue[0];
    try {
      await request(req.path, {
        method: req.method,
        body: req.body ? JSON.stringify(req.body) : undefined,
      });
      offlineQueue.shift();
      succeeded++;
    } catch {
      failed++;
      break;
    }
  }
  return { succeeded, failed };
}

function queueForOffline(method: string, path: string, body?: unknown): void {
  offlineQueue.push({
    id: crypto.randomUUID(),
    method,
    path,
    body,
    timestamp: Date.now(),
  });
}

// ── Core Request ──────────────────────────────────────────────────────────────

async function doFetch<T>(
  path: string,
  options: RequestInit,
  retried = false,
): Promise<T> {
  const url = `${BASE_URL}${API_PREFIX}${path}`;
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
    ...(options.headers as Record<string, string> | undefined),
  };
  if (_token) headers["Authorization"] = `Bearer ${_token}`;

  const response = await fetch(url, { ...options, headers });

  if (response.status === 401 && !retried && _token) {
    // Token expired — for now just clear it
    _token = null;
    return doFetch<T>(path, options, true);
  }

  if (!response.ok) {
    let body: unknown;
    try {
      body = await response.json();
    } catch {
      body = await response.text();
    }
    const message =
      typeof body === "object" && body !== null && "error" in body
        ? String((body as Record<string, unknown>).error)
        : `HTTP ${response.status}: ${path}`;
    throw new ApiError(response.status, message, body);
  }

  if (response.status === 204) return undefined as T;
  return response.json() as Promise<T>;
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  // Wait for auth to finish before making any API call.
  // Re-read useMock AFTER the promise resolves — initializeAuth() may have
  // flipped it from true → false while this call was queued, which is the
  // race condition that caused mock data to bleed into live sessions.
  await _authPromise;

  // Guard: re-check useMock after the auth gate opens so a flip that happened
  // concurrently during initializeAuth() is always visible here.
  if (useMock) {
    const mock = await getMock();
    // Second guard: useMock could flip again between the check above and
    // getMock() completing (getMock() is async). Only dispatch to mock when
    // the flag is still true at call time.
    if (!useMock) {
      // Fall through to the real fetch path below
    } else {
      return mock.handleRequest<T>(path, options);
    }
  }

  const method = (options.method ?? "GET").toUpperCase();

  if (method === "GET") {
    const cached = getCached<T>(path);
    if (cached !== null) return cached;
    try {
      const data = await withRetry(() => doFetch<T>(path, options));
      setCache(path, data);
      return data;
    } catch (error) {
      // Fall back to mock on network error
      if (!(error instanceof ApiError)) {
        await setMockEnabled(true);
        const mock = await getMock();
        return mock.handleRequest<T>(path, options);
      }
      throw error;
    }
  }

  try {
    return await withRetry(() => doFetch<T>(path, options));
  } catch (error) {
    if (!(error instanceof ApiError)) {
      const body =
        options.body !== undefined
          ? JSON.parse(options.body as string)
          : undefined;
      queueForOffline(method, path, body);
    }
    throw error;
  }
}

// ── Health ────────────────────────────────────────────────────────────────────

export const health = {
  get: async (): Promise<HealthResponse> => {
    // Always attempt a real probe first — this is how mock mode gets cleared
    try {
      const res = await fetch(`${BASE_URL}${API_PREFIX}/health`, {
        headers: { Accept: "application/json" },
        signal: AbortSignal.timeout(3000),
      });
      if (!res.ok) throw new ApiError(res.status, "Health check failed");
      // Backend is reachable — disable mock mode so subsequent requests go to
      // the real API. setMockEnabled(false) purges localStorage mock data and
      // clears the response cache in one call.
      if (useMock) {
        clearCache();
        await setMockEnabled(false);
      }
      return res.json() as Promise<HealthResponse>;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      // Network error — backend unreachable, activate mock mode
      await setMockEnabled(true);
      const mock = await getMock();
      return mock.handleRequest<HealthResponse>("/health", {});
    }
  },
};

// ── Dashboard ─────────────────────────────────────────────────────────────────

export const dashboard = {
  get: () => request<DashboardData>("/dashboard"),
};

// ── Agents ────────────────────────────────────────────────────────────────────

export const agents = {
  list: async (workspaceId?: string): Promise<CanopyAgent[]> => {
    const qs = workspaceId ? `?workspace_id=${workspaceId}` : "";
    const data = await request<{ agents: CanopyAgent[]; count: number }>(
      `/agents${qs}`,
    );
    return data.agents ?? [];
  },
  get: (id: string) => request<CanopyAgent>(`/agents/${id}`),
  create: (body: AgentCreateRequest) =>
    request<CanopyAgent>("/agents", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (id: string, body: Partial<AgentCreateRequest>) =>
    request<CanopyAgent>(`/agents/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  action: (id: string, action: string) =>
    request<CanopyAgent>(`/agents/${id}/${action}`, { method: "POST" }),
  resume: (id: string) =>
    request<CanopyAgent>(`/agents/${id}/resume`, { method: "POST" }),
  terminate: (id: string) =>
    request<void>(`/agents/${id}`, { method: "DELETE" }),
};

// ── Sessions ──────────────────────────────────────────────────────────────────

export const sessions = {
  list: async (workspaceId?: string): Promise<Session[]> => {
    const qs = workspaceId ? `?workspace_id=${workspaceId}` : "";
    const data = await request<{ sessions: Session[]; count: number }>(
      `/sessions${qs}`,
    );
    return data.sessions ?? [];
  },
  get: (id: string) => request<Session>(`/sessions/${id}`),
  create: (body: { agent_id: string; title?: string }) =>
    request<Session>("/sessions", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  delete: (id: string) =>
    request<void>(`/sessions/${id}`, { method: "DELETE" }),
};

// ── Messages ──────────────────────────────────────────────────────────────────

export const messages = {
  list: async (sessionId: string) => {
    const data = await request<{
      messages: import("./types").Message[];
      count: number;
    }>(`/sessions/${sessionId}/transcript`);
    return data.messages ?? [];
  },
  send: (body: SendMessageRequest) =>
    request<SendMessageResponse>(`/sessions/${body.session_id}/message`, {
      method: "POST",
      body: JSON.stringify({ ...body, stream: true }),
    }),
};

// ── Schedules ─────────────────────────────────────────────────────────────────

export const schedules = {
  list: async (workspaceId?: string): Promise<Schedule[]> => {
    const qs = workspaceId ? `?workspace_id=${workspaceId}` : "";
    const data = await request<{ schedules: Schedule[] }>(`/schedules${qs}`);
    return data.schedules ?? [];
  },
  get: (id: string) => request<Schedule>(`/schedules/${id}`),
  create: (body: { agent_id: string; cron: string; context?: string }) =>
    request<Schedule>("/schedules", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (
    id: string,
    body: Partial<{ cron: string; context: string; enabled: boolean }>,
  ) =>
    request<Schedule>(`/schedules/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  delete: (id: string) =>
    request<void>(`/schedules/${id}`, { method: "DELETE" }),
  runs: (id: string) =>
    request<{ runs: HeartbeatRun[] }>(`/schedules/${id}/runs`),
  triggerNow: (id: string) =>
    request<HeartbeatRun>(`/schedules/${id}/trigger`, { method: "POST" }),
};

// ── Issues ────────────────────────────────────────────────────────────────────

export const issues = {
  list: async (workspaceId?: string): Promise<Issue[]> => {
    const qs = workspaceId ? `?workspace_id=${workspaceId}` : "";
    const data = await request<{ issues: Issue[] }>(`/issues${qs}`);
    return data.issues ?? [];
  },
  get: (id: string) => request<Issue>(`/issues/${id}`),
  create: (body: Partial<Issue>) =>
    request<Issue>("/issues", { method: "POST", body: JSON.stringify(body) }),
  update: (id: string, body: Partial<Issue>) =>
    request<Issue>(`/issues/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  delete: (id: string) => request<void>(`/issues/${id}`, { method: "DELETE" }),
  dispatch: (issueId: string) =>
    request<{ ok: boolean; message: string }>(`/issues/${issueId}/dispatch`, {
      method: "POST",
    }),
};

// ── Goals ─────────────────────────────────────────────────────────────────────

export const goals = {
  list: async (projectId: string): Promise<GoalTreeNode[]> => {
    const data = await request<{ goals: GoalTreeNode[] }>(
      `/projects/${projectId}/goals`,
    );
    return data.goals ?? [];
  },
  create: (projectId: string, body: Partial<Goal>) =>
    request<Goal>(`/projects/${projectId}/goals`, {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (projectId: string, id: string, body: Partial<Goal>) =>
    request<Goal>(`/projects/${projectId}/goals/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  decompose: (
    goalId: string,
    opts?: { max_issues?: number; auto_assign?: boolean },
  ) =>
    request<{ issues: Issue[]; count: number }>(`/goals/${goalId}/decompose`, {
      method: "POST",
      body: JSON.stringify(opts ?? {}),
    }),
};

// ── Projects ──────────────────────────────────────────────────────────────────

export const projects = {
  list: async (workspaceId?: string): Promise<Project[]> => {
    const qs = workspaceId ? `?workspace_id=${workspaceId}` : "";
    const data = await request<{ projects: Project[] }>(`/projects${qs}`);
    return data.projects ?? [];
  },
  get: (id: string) => request<Project>(`/projects/${id}`),
  create: (body: Partial<Project>) =>
    request<Project>("/projects", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (id: string, body: Partial<Project>) =>
    request<Project>(`/projects/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
};

// ── Costs ─────────────────────────────────────────────────────────────────────

export const costs = {
  summary: () => request<CostSummary>("/costs/summary"),
  byAgent: () => request<{ agents: AgentCostBreakdown[] }>("/costs/by-agent"),
  byModel: () => request<{ models: ModelCostBreakdown[] }>("/costs/by-model"),
  policies: () => request<{ policies: BudgetPolicy[] }>("/budgets"),
  incidents: () =>
    request<{ incidents: BudgetIncident[] }>("/budgets/incidents"),
  daily: () =>
    request<{ points: Array<{ date: string; cost_cents: number }> }>(
      "/costs/daily",
    ),
};

// ── Activity ──────────────────────────────────────────────────────────────────

export const activity = {
  list: async (limit = 50): Promise<ActivityEvent[]> => {
    const data = await request<{ events: ActivityEvent[] }>(
      `/activity?limit=${limit}`,
    );
    return data.events ?? [];
  },
};

// ── Inbox ─────────────────────────────────────────────────────────────────────

export const inbox = {
  list: async (): Promise<InboxItem[]> => {
    const data = await request<{ messages: InboxItem[]; items: InboxItem[] }>(
      "/inbox",
    );
    return data.messages ?? data.items ?? [];
  },
  action: (id: string, actionId: string) =>
    request<void>(`/inbox/${id}/actions/${actionId}`, { method: "POST" }),
  dismiss: (id: string) =>
    request<void>(`/inbox/${id}/dismiss`, { method: "POST" }),
};

// ── Skills ────────────────────────────────────────────────────────────────────

export const skills = {
  list: async (): Promise<Skill[]> => {
    const data = await request<{ skills: Skill[] }>("/skills");
    return data.skills ?? [];
  },
  toggle: (id: string) =>
    request<Skill>(`/skills/${id}/toggle`, { method: "POST" }),
};

// ── Webhooks ──────────────────────────────────────────────────────────────────

export const webhooks = {
  list: async (): Promise<Webhook[]> => {
    const data = await request<{ webhooks: Webhook[] }>("/webhooks");
    return data.webhooks ?? [];
  },
  create: (body: Partial<Webhook>) =>
    request<Webhook>("/webhooks", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  delete: (id: string) =>
    request<void>(`/webhooks/${id}`, { method: "DELETE" }),
};

// ── Alerts ────────────────────────────────────────────────────────────────────

export const alerts = {
  list: async (): Promise<AlertRule[]> => {
    const data = await request<{ rules: AlertRule[] }>("/alerts/rules");
    return data.rules ?? [];
  },
  create: (body: Partial<AlertRule>) =>
    request<AlertRule>("/alerts/rules", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};

// ── Integrations ──────────────────────────────────────────────────────────────

export const integrations = {
  list: async (): Promise<Integration[]> => {
    const data = await request<{ integrations: Integration[] }>(
      "/integrations",
    );
    return data.integrations ?? [];
  },
};

// ── Adapters ──────────────────────────────────────────────────────────────────

export const adapters = {
  list: async (): Promise<Adapter[]> => {
    const data = await request<{ adapters: Adapter[] }>("/adapters");
    return data.adapters ?? [];
  },
};

// ── Gateways ──────────────────────────────────────────────────────────────────

export const gateways = {
  list: async (): Promise<Gateway[]> => {
    const data = await request<{ gateways: Gateway[] }>("/gateways");
    return data.gateways ?? [];
  },
  create: (body: Partial<Gateway>) =>
    request<Gateway>("/gateways", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  delete: (id: string) =>
    request<void>(`/gateways/${id}`, { method: "DELETE" }),
  probe: (id: string) =>
    request<Gateway>(`/gateways/${id}/probe`, { method: "POST" }),
};

// ── Documents ─────────────────────────────────────────────────────────────────

export const documents = {
  list: async (
    workspaceId?: string,
  ): Promise<{
    documents: Document[];
    tree: DocumentTreeNode[];
  }> => {
    const qs = workspaceId
      ? `?workspace_id=${encodeURIComponent(workspaceId)}`
      : "";
    const data = await request<{
      documents: Document[];
      tree: DocumentTreeNode[];
    }>(`/documents${qs}`);
    return { documents: data.documents ?? [], tree: data.tree ?? [] };
  },

  get: async (path: string): Promise<Document> => {
    return request<Document>(`/documents/${encodeDocPath(path)}`);
  },

  create: async (doc: {
    title: string;
    path: string;
    content: string;
    format?: Document["format"];
    project_id?: string | null;
  }): Promise<Document> => {
    return request<Document>("/documents", {
      method: "POST",
      body: JSON.stringify(doc),
    });
  },

  update: async (
    path: string,
    updates: { content?: string; title?: string; format?: Document["format"] },
  ): Promise<Document> => {
    return request<Document>(`/documents/${encodeDocPath(path)}`, {
      method: "PUT",
      body: JSON.stringify(updates),
    });
  },

  delete: async (path: string): Promise<void> => {
    await request<void>(`/documents/${encodeDocPath(path)}`, {
      method: "DELETE",
    });
  },

  revisions: async (documentId: string): Promise<DocumentRevision[]> => {
    const data = await request<{ revisions: DocumentRevision[] }>(
      `/document-revisions?document_id=${encodeURIComponent(documentId)}`,
    );
    return data.revisions ?? [];
  },
};

/** Encode a document path for use in URL segments (preserves slashes). */
function encodeDocPath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

// ── Workspaces ────────────────────────────────────────────────────────────────

export const workspaces = {
  list: async (): Promise<Workspace[]> => {
    const data = await request<{ workspaces: Workspace[] }>("/workspaces");
    return data.workspaces ?? [];
  },
  create: async (params: {
    name: string;
    directory?: string;
  }): Promise<Workspace> => {
    return request<Workspace>("/workspaces", {
      method: "POST",
      body: JSON.stringify(params),
    });
  },
  activate: async (id: string): Promise<Workspace> => {
    return request<{ workspace: Workspace }>(`/workspaces/${id}/activate`, {
      method: "POST",
    }).then((data) => (data as { workspace: Workspace }).workspace ?? data);
  },
};

// ── Settings ──────────────────────────────────────────────────────────────────

export const settings = {
  get: () => request<Settings>("/config"),
  update: (body: Partial<Settings>) =>
    request<Settings>("/config", {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
};

// ── Audit ─────────────────────────────────────────────────────────────────────

export const audit = {
  list: async (page = 1, limit = 50): Promise<AuditEntry[]> => {
    const data = await request<{ entries: AuditEntry[]; events: AuditEntry[] }>(
      `/audit?page=${page}&limit=${limit}`,
    );
    return data.entries ?? data.events ?? [];
  },
};

// ── Logs ──────────────────────────────────────────────────────────────────────

export const logs = {
  list: async (_limit = 100): Promise<LogEntry[]> => {
    // Backend exposes /logs/stream (SSE only) — fall back to activity feed
    const data = await request<{ events: LogEntry[] }>(
      `/activity?limit=${_limit}`,
    );
    return data.events ?? [];
  },
};

// ── Memory ────────────────────────────────────────────────────────────────────

export const memory = {
  list: async (namespace?: string): Promise<MemoryEntry[]> => {
    const params = namespace
      ? `?namespace=${encodeURIComponent(namespace)}`
      : "";
    const data = await request<{ entries: MemoryEntry[] }>(`/memory${params}`);
    return data.entries ?? [];
  },
  namespaces: async (): Promise<MemoryNamespace[]> => {
    const data = await request<{ namespaces: MemoryNamespace[] }>(
      "/memory/namespaces",
    );
    return data.namespaces ?? [];
  },
  get: async (id: string): Promise<MemoryEntry> => {
    const data = await request<{ entry: MemoryEntry }>(`/memory/${id}`);
    return data.entry;
  },
  search: async (q: string): Promise<MemoryEntry[]> => {
    const data = await request<{ entries: MemoryEntry[] }>(
      `/memory/search?q=${encodeURIComponent(q)}`,
    );
    return data.entries ?? [];
  },
  create: async (body: MemoryCreateRequest): Promise<MemoryEntry> => {
    const data = await request<{ entry: MemoryEntry }>("/memory", {
      method: "POST",
      body: JSON.stringify(body),
    });
    return data.entry;
  },
  update: async (
    id: string,
    body: Partial<MemoryCreateRequest>,
  ): Promise<MemoryEntry> => {
    const data = await request<{ entry: MemoryEntry }>(`/memory/${id}`, {
      method: "PUT",
      body: JSON.stringify(body),
    });
    return data.entry;
  },
  delete: async (id: string): Promise<void> => {
    await request<void>(`/memory/${id}`, { method: "DELETE" });
  },
};

// ── Signals ───────────────────────────────────────────────────────────────────

export const signals = {
  list: async (limit = 100): Promise<Signal[]> => {
    const data = await request<{ signals: Signal[] }>(
      `/signals/feed?limit=${limit}`,
    );
    return data.signals ?? [];
  },
  patterns: async (): Promise<SignalPattern[]> => {
    const data = await request<{ patterns: SignalPattern[] }>(
      "/signals/patterns",
    );
    return data.patterns ?? [];
  },
  stats: async (): Promise<SignalStats> => {
    return request<SignalStats>("/signals/stats");
  },
};

// ── Spawn ─────────────────────────────────────────────────────────────────────

export const spawn = {
  list: async (): Promise<SpawnInstance[]> => {
    const data = await request<{ instances: SpawnInstance[] }>("/spawn/active");
    return data.instances ?? [];
  },
  create: (body: { agent_id: string; task: string; model?: string }) =>
    request<SpawnInstance>("/spawn", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};

// ── Secrets ───────────────────────────────────────────────────────────────────

export const secrets = {
  list: async (): Promise<Secret[]> => {
    const data = await request<{ secrets: Secret[] }>("/secrets");
    return data.secrets ?? [];
  },
  get: (id: string) => request<Secret>(`/secrets/${id}`),
  create: (body: SecretCreateRequest) =>
    request<Secret>("/secrets", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  delete: (id: string) => request<void>(`/secrets/${id}`, { method: "DELETE" }),
  rotate: (id: string) =>
    request<Secret>(`/secrets/${id}/rotate`, { method: "POST" }),
};

// ── Approvals ─────────────────────────────────────────────────────────────────

export const approvals = {
  list: async (params?: Record<string, string>): Promise<Approval[]> => {
    const qs = params ? "?" + new URLSearchParams(params).toString() : "";
    const data = await request<{ approvals: Approval[] }>(`/approvals${qs}`);
    return data.approvals ?? [];
  },
  get: (id: string) => request<Approval>(`/approvals/${id}`),
  create: (body: ApprovalCreateRequest) =>
    request<Approval>("/approvals", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  approve: (id: string, comment?: string) =>
    request<Approval>(`/approvals/${id}/approve`, {
      method: "POST",
      body: JSON.stringify({ comment }),
    }),
  reject: (id: string, comment?: string) =>
    request<Approval>(`/approvals/${id}/reject`, {
      method: "POST",
      body: JSON.stringify({ comment }),
    }),
};

// ── Organizations ─────────────────────────────────────────────────────────────

export const organizations = {
  list: async (): Promise<Organization[]> => {
    const data = await request<{ organizations: Organization[] }>(
      "/organizations",
    );
    return data.organizations ?? [];
  },
  get: (id: string) => request<Organization>(`/organizations/${id}`),
  create: (body: OrganizationCreateRequest) =>
    request<Organization>("/organizations", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (id: string, body: Partial<OrganizationCreateRequest>) =>
    request<Organization>(`/organizations/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  delete: (id: string) =>
    request<void>(`/organizations/${id}`, { method: "DELETE" }),
  members: async (id: string): Promise<OrganizationMembership[]> => {
    const data = await request<{ members: OrganizationMembership[] }>(
      `/organizations/${id}/members`,
    );
    return data.members ?? [];
  },
};

// ── Labels ────────────────────────────────────────────────────────────────────

export const labels = {
  list: async (params?: Record<string, string>): Promise<Label[]> => {
    const qs = params ? "?" + new URLSearchParams(params).toString() : "";
    const data = await request<{ labels: Label[] }>(`/labels${qs}`);
    return data.labels ?? [];
  },
  create: (body: LabelCreateRequest) =>
    request<Label>("/labels", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  delete: (id: string) => request<void>(`/labels/${id}`, { method: "DELETE" }),
};

// ── Plugins ───────────────────────────────────────────────────────────────────

export const plugins = {
  list: async (): Promise<Plugin[]> => {
    const data = await request<{ plugins: Plugin[] }>("/plugins");
    return data.plugins ?? [];
  },
  get: (id: string) => request<Plugin>(`/plugins/${id}`),
  create: (body: Partial<Plugin>) =>
    request<Plugin>("/plugins", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (id: string, body: Partial<Plugin>) =>
    request<Plugin>(`/plugins/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  delete: (id: string) => request<void>(`/plugins/${id}`, { method: "DELETE" }),
  logs: async (id: string): Promise<PluginLog[]> => {
    const data = await request<{ logs: PluginLog[] }>(`/plugins/${id}/logs`);
    return data.logs ?? [];
  },
};

// ── Access / Role Assignments ─────────────────────────────────────────────────

export const access = {
  list: async (params?: Record<string, string>): Promise<RoleAssignment[]> => {
    const qs = params ? "?" + new URLSearchParams(params).toString() : "";
    const data = await request<{ assignments: RoleAssignment[] }>(
      `/access${qs}`,
    );
    return data.assignments ?? [];
  },
  assign: (body: Partial<RoleAssignment>) =>
    request<RoleAssignment>("/access/assign", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  revoke: (id: string) => request<void>(`/access/${id}`, { method: "DELETE" }),
};

// ── Sidebar Badges ────────────────────────────────────────────────────────────

export const sidebarBadges = {
  get: () => request<SidebarBadges>("/sidebar-badges"),
};

// ── Users ─────────────────────────────────────────────────────────────────────

export const users = {
  list: async (): Promise<User[]> => {
    const data = await request<{ users: User[] }>("/users");
    return data.users ?? [];
  },
  get: (id: string) => request<User>(`/users/${id}`),
  create: (body: Partial<User>) =>
    request<User>("/users", {
      method: "POST",
      body: JSON.stringify(body),
    }),
  update: (id: string, body: Partial<User>) =>
    request<User>(`/users/${id}`, {
      method: "PATCH",
      body: JSON.stringify(body),
    }),
  delete: (id: string) => request<void>(`/users/${id}`, { method: "DELETE" }),
};

// ── Templates ─────────────────────────────────────────────────────────────────

export const templates = {
  list: async (): Promise<AgentTemplate[]> => {
    const data = await request<{ templates: AgentTemplate[] }>("/templates");
    return data.templates ?? [];
  },
  get: (id: string) => request<AgentTemplate>(`/templates/${id}`),
  create: (body: Partial<AgentTemplate>) =>
    request<AgentTemplate>("/templates", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};

// ── Enable/Disable Mock ──────────────────────────────────────────────────────
// These are async because disabling mock purges localStorage and notifies the
// mock module, both of which are best-effort async operations.

export async function enableMock(): Promise<void> {
  await setMockEnabled(true);
}
export async function disableMock(): Promise<void> {
  await setMockEnabled(false);
}
export function isMockEnabled(): boolean {
  return useMock;
}

/**
 * Purge all mock-related localStorage keys and flush in-memory mock state.
 * Safe to call at any time — no-ops when the mock module isn't loaded yet.
 */
export async function clearMockData(): Promise<void> {
  try {
    const mod = await getMock();
    mod.clearAllMockData();
  } catch {
    // Mock module not available — clear the well-known key directly
    try {
      localStorage.removeItem("canopy-workspace-agents");
    } catch {
      // localStorage unavailable
    }
  }
}
