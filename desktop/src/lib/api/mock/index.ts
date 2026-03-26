// src/lib/api/mock/index.ts
// Mock API router — intercepts requests in dev mode when backend is unavailable

import { mockDashboard } from "./dashboard";
import {
  mockAgents,
  mockAgentById,
  setMockWorkspaceAgents,
  getMockWorkspaceAgents,
  clearMockWorkspaceAgents,
  clearAllMockWorkspaceAgents,
} from "./agents";
import {
  mockSchedules,
  addSchedule,
  updateSchedule,
  deleteSchedule,
} from "./schedules";
import { mockIssues, addIssue, updateIssue, deleteIssue } from "./issues";
import { mockCosts } from "./costs";
import { mockActivity } from "./activity";
import { mockSessions, addSession, deleteSession } from "./sessions";
import { getInbox, performInboxAction } from "./inbox";
import {
  getGoals,
  getGoalTree,
  getGoalById,
  addGoal,
  updateGoal,
  deleteGoal,
} from "./goals";
import {
  getDocuments,
  getDocumentTree,
  getDocumentById,
  addDocument,
  updateDocument,
  deleteDocument,
} from "./documents";
import {
  getProjects,
  getProjectById,
  addProject,
  updateProject,
  deleteProject,
} from "./projects";
import { getSpawnInstances, createSpawnInstance, deleteSpawn } from "./spawn";
import { getMockMessages } from "./chat";
import {
  getMutableEntries,
  getMockMemoryNamespaces,
  getMockMemoryById,
  searchMockMemory,
  createMockEntry,
  updateMockEntry,
  deleteMockEntry,
} from "./memory";
import { mockSkills, toggleSkill } from "./skills";
import {
  mockWebhooks,
  addWebhook,
  updateWebhook,
  deleteWebhook,
} from "./webhooks";
import { mockAlertRules, addAlertRule, deleteAlertRule } from "./alerts";
import { mockIntegrations, mockAdapters } from "./integrations";
import {
  mockGateways,
  addGateway,
  updateGateway,
  deleteGateway,
} from "./gateways";
import { mockUsers } from "./users";
import { mockConfig } from "./config";
import { mockTemplates } from "./templates";
import { mockSecrets } from "./secrets";
import { mockApprovals } from "./approvals";
import { mockOrganizations, mockOrgMembers } from "./organizations";
import { mockLabels } from "./labels";
import { mockPlugins, mockPluginLogs } from "./plugins";
import {
  mockWorkflows,
  getWorkflowById,
  addWorkflow,
  updateWorkflow,
  deleteWorkflow,
  getWorkflowSteps,
  addWorkflowStep,
  removeWorkflowStep,
  getWorkflowRuns,
  addWorkflowRun,
} from "./workflows";
import {
  mockEnvironmentApps,
  mockEnvironmentAgentApps,
  mockEnvironmentResources,
  mockEnvironmentCapabilities,
  grantEnvironmentAccess,
  revokeEnvironmentAccess,
} from "./environment";
import { mockSignals } from "./signals";
import { mockAudit } from "./audit";
import { mockLogs } from "./logs";
import { mockAnalytics } from "./analytics";
import { mockWorkProducts } from "./work-products";
import {
  getMockConversations,
  getMockConversationById,
  getMockConversationMessages,
  addMockConversation,
  archiveMockConversation,
  deleteMockConversation,
  mockSendMessage,
} from "./conversations";
import {
  mockDatasets,
  mockDatasetById,
  addMockDataset,
  updateMockDataset,
  deleteMockDataset,
  mockDatasetPreview,
} from "./datasets";
import {
  mockReports,
  mockReportById,
  addMockReport,
  updateMockReport,
  deleteMockReport,
  generateMockReport,
} from "./reports";
import {
  getMockNotifications,
  getMockNotificationById,
  markNotificationRead,
  markAllNotificationsRead,
  dismissNotification,
  getMockNotificationBadges,
} from "./notifications";
import type {
  CanopyAgent,
  Schedule,
  HeartbeatRun,
  Issue,
  IssueStatus,
  IssuePriority,
  Session,
  Goal,
  GoalStatus,
  GoalPriority,
  Webhook,
  AlertRule,
  Document,
  Gateway,
  Workflow,
  WorkflowStep,
  WorkflowRun,
  Dataset,
} from "../types";

// Simulated network delay (kept minimal for responsiveness)
function delay(ms = 30): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms + Math.random() * 20));
}

// rawPath includes query string; path is cleanPath (no query string)
type RouteHandler = (
  path: string,
  options: RequestInit,
  rawPath: string,
) => unknown;

// ── Route table ───────────────────────────────────────────────────────────────

const routes: Array<{ pattern: RegExp; handler: RouteHandler }> = [
  // ── Health ──────────────────────────────────────────────────────────────────
  {
    pattern: /^\/health$/,
    handler: () => ({
      status: "ok",
      version: "1.0.0-mock",
      provider: null,
      uptime_seconds: 3600,
      agents_active: 2,
    }),
  },

  // ── Dashboard ───────────────────────────────────────────────────────────────
  { pattern: /^\/dashboard$/, handler: () => mockDashboard() },

  // ── Agents — specific routes before general ─────────────────────────────────
  {
    // POST /agents/:id/wake|sleep|pause|terminate|focus
    pattern: /^\/agents\/([^/]+)\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return mockAgentById(id);
    },
  },
  {
    // GET/PATCH/DELETE /agents/:id
    pattern: /^\/agents\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") return undefined;
      if (method === "PATCH" && options.body) {
        const base = mockAgentById(id);
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<CanopyAgent>;
          return { ...base, ...body, updated_at: new Date().toISOString() };
        } catch {
          return base;
        }
      }
      return mockAgentById(id);
    },
  },
  {
    // GET /agents + POST /agents
    pattern: /^\/agents$/,
    handler: (_path, options, rawPath) => {
      const wsId =
        new URLSearchParams((rawPath ?? "").split("?")[1] ?? "").get(
          "workspace_id",
        ) ?? undefined;

      if ((options.method ?? "GET").toUpperCase() === "POST") {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body ?? {}),
          ) as Partial<CanopyAgent> & { slug?: string };
          const now = new Date().toISOString();
          const newAgent: CanopyAgent = {
            id: body.id ?? `agent-new-${Date.now()}`,
            name: body.name ?? "new-agent",
            display_name: body.display_name ?? body.name ?? "New Agent",
            avatar_emoji: body.avatar_emoji ?? "🤖",
            role: body.role ?? "General",
            adapter: body.adapter ?? "osa",
            model: body.model ?? "claude-sonnet-4-6",
            system_prompt: body.system_prompt ?? "",
            config: body.config ?? {},
            skills: body.skills ?? [],
            team_id: body.team_id ?? null,
            reports_to: body.reports_to ?? null,
            workspace_id: body.workspace_id ?? wsId ?? null,
            schedule_id: null,
            budget_policy_id: null,
            status: "idle",
            current_task: null,
            last_active_at: null,
            token_usage_today: {
              input: 0,
              output: 0,
              cache_read: 0,
              cache_write: 0,
            },
            cost_today_cents: 0,
            created_at: now,
            updated_at: now,
          };
          // Persist the created agent so subsequent GET /agents returns it
          const targetWs = body.workspace_id ?? wsId;
          if (targetWs) {
            const existing = mockAgents(targetWs);
            setMockWorkspaceAgents(targetWs, [...existing, newAgent]);
          }
          return newAgent;
        } catch {
          return {} as CanopyAgent;
        }
      }
      const agents = mockAgents(wsId);
      return { agents, count: agents.length };
    },
  },

  // ── Sessions ─────────────────────────────────────────────────────────────────
  {
    pattern: /^\/sessions\/([^/]+)\/(transcript|messages)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return { messages: getMockMessages(id) };
    },
  },
  {
    // GET/DELETE /sessions/:id
    pattern: /^\/sessions\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteSession(id);
        return { ok: true };
      }
      return mockSessions().find((s) => s.id === id) ?? mockSessions()[0];
    },
  },
  {
    // GET /sessions + POST /sessions
    pattern: /^\/sessions$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newSession: Session = {
          id: `sess-new-${Date.now()}`,
          agent_id: (body.agent_id as string) ?? "agent-1",
          agent_name: (body.agent_name as string) ?? "Scout",
          title: (body.title as string) ?? "New Session",
          status: "active",
          message_count: 0,
          token_usage: { input: 0, output: 0, cache_read: 0, cache_write: 0 },
          cost_cents: 0,
          started_at: now,
          completed_at: null,
          created_at: now,
        };
        addSession(newSession);
        return newSession;
      }
      const sessions = mockSessions();
      return { sessions, count: sessions.length };
    },
  },

  // ── Messages ─────────────────────────────────────────────────────────────────
  {
    pattern: /^\/messages$/,
    handler: () => ({
      stream_id: `stream-${Date.now()}`,
      session_id: "sess-1",
    }),
  },

  // ── Schedules ────────────────────────────────────────────────────────────────
  {
    // POST /schedules/:id/trigger
    pattern: /^\/schedules\/([^/]+)\/trigger$/,
    handler: (path): HeartbeatRun => {
      const scheduleId = path.split("/")[2];
      const sched =
        mockSchedules().find((s) => s.id === scheduleId) ?? mockSchedules()[0];
      return {
        id: `run-mock-${Date.now()}`,
        schedule_id: sched.id,
        agent_id: sched.agent_id,
        agent_name: sched.agent_name,
        status: "running",
        trigger: "manual",
        started_at: new Date().toISOString(),
        completed_at: null,
        duration_ms: null,
        token_usage: null,
        cost_cents: null,
        output_summary: null,
        error_message: null,
      };
    },
  },
  {
    // GET /schedules/:id/runs
    pattern: /^\/schedules\/([^/]+)\/runs$/,
    handler: () => ({ runs: [] }),
  },
  {
    // GET/PATCH/DELETE /schedules/:id
    pattern: /^\/schedules\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteSchedule(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Schedule>;
          return updateSchedule(id, body) ?? { error: "not_found" };
        } catch {
          return mockSchedules().find((s) => s.id === id) ?? mockSchedules()[0];
        }
      }
      return mockSchedules().find((s) => s.id === id) ?? mockSchedules()[0];
    },
  },
  {
    // GET /schedules + POST /schedules
    pattern: /^\/schedules$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newSchedule: Schedule = {
          id: `sched-new-${Date.now()}`,
          agent_id: (body.agent_id as string) ?? "agt-researcher",
          agent_name: (body.agent_name as string) ?? "Research Agent",
          cron: (body.cron as string) ?? "0 9 * * 1-5",
          human_readable: (body.human_readable as string) ?? "",
          enabled: (body.enabled as boolean) ?? false,
          context: (body.context as string) ?? "",
          next_run_at: null,
          last_run_at: null,
          last_run_status: null,
          run_count: 0,
          created_at: now,
          updated_at: now,
        };
        addSchedule(newSchedule);
        return newSchedule;
      }
      return { schedules: mockSchedules() };
    },
  },

  // ── Workflows ────────────────────────────────────────────────────────────────
  {
    // POST /workflows/:id/trigger
    pattern: /^\/workflows\/([^/]+)\/trigger$/,
    handler: (path, options): { run: WorkflowRun } => {
      const workflowId = path.split("/")[2];
      let input: Record<string, unknown> = {};
      try {
        const body = JSON.parse(options.body as string) as {
          input?: Record<string, unknown>;
        };
        input = body.input ?? {};
      } catch {
        /* ignore */
      }
      const run: WorkflowRun = {
        id: `wfr-${Date.now()}`,
        workflow_id: workflowId,
        status: "pending",
        trigger_event: "manual",
        input,
        output: {},
        started_at: new Date().toISOString(),
        completed_at: null,
        error: null,
        step_results: {},
        inserted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      addWorkflowRun(run);
      return { run };
    },
  },
  {
    // GET /workflows/:id/runs
    pattern: /^\/workflows\/([^/]+)\/runs$/,
    handler: (path) => {
      const workflowId = path.split("/")[2];
      return { runs: getWorkflowRuns(workflowId) };
    },
  },
  {
    // DELETE /workflows/:id/steps/:stepId
    pattern: /^\/workflows\/([^/]+)\/steps\/([^/]+)$/,
    handler: (path) => {
      const parts = path.split("/");
      removeWorkflowStep(parts[2], parts[4]);
      return { ok: true };
    },
  },
  {
    // GET /workflows/:id/steps + POST /workflows/:id/steps
    pattern: /^\/workflows\/([^/]+)\/steps$/,
    handler: (path, options) => {
      const workflowId = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const name = (body.name as string) ?? "New Step";
        const newStep: WorkflowStep = {
          id: `wf-step-new-${Date.now()}`,
          workflow_id: workflowId,
          agent_id: (body.agent_id as string) ?? null,
          agent_name: (body.agent_name as string) ?? null,
          agent_emoji: (body.agent_emoji as string) ?? null,
          name,
          step_type:
            (body.step_type as string as WorkflowStep["step_type"]) ??
            "agent_task",
          position: (body.position as number) ?? 1,
          config: (body.config as Record<string, unknown>) ?? {},
          depends_on: (body.depends_on as string[]) ?? [],
          timeout_seconds: (body.timeout_seconds as number) ?? 300,
          retry_count: (body.retry_count as number) ?? 0,
          on_failure:
            (body.on_failure as string as WorkflowStep["on_failure"]) ?? "stop",
          inserted_at: now,
          updated_at: now,
        };
        addWorkflowStep(workflowId, newStep);
        return { step: newStep };
      }
      return { steps: getWorkflowSteps(workflowId) };
    },
  },
  {
    // GET/PATCH/DELETE /workflows/:id
    pattern: /^\/workflows\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteWorkflow(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Workflow>;
          const updated = updateWorkflow(id, body);
          return updated ? { workflow: updated } : { error: "not_found" };
        } catch {
          const wf = getWorkflowById(id);
          return wf ? { workflow: wf } : { error: "not_found" };
        }
      }
      const wf = getWorkflowById(id);
      return wf ? { workflow: wf } : { error: "not_found" };
    },
  },
  {
    // GET /workflows + POST /workflows
    pattern: /^\/workflows$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const name = (body.name as string) ?? "New Workflow";
        const newWorkflow: Workflow = {
          id: `wf-new-${Date.now()}`,
          name,
          slug:
            (body.slug as string) ?? name.toLowerCase().replace(/\s+/g, "-"),
          description: (body.description as string) ?? null,
          status: "draft",
          trigger_type:
            (body.trigger_type as string as Workflow["trigger_type"]) ??
            "manual",
          trigger_config: {},
          created_by: null,
          version: 1,
          workspace_id: (body.workspace_id as string) ?? null,
          organization_id: null,
          step_count: 0,
          last_run_at: null,
          steps: [],
          inserted_at: now,
          updated_at: now,
        };
        addWorkflow(newWorkflow);
        return { workflow: newWorkflow };
      }
      return { workflows: mockWorkflows() };
    },
  },

  // ── Issues ───────────────────────────────────────────────────────────────────
  {
    // POST /issues/:id/dispatch
    pattern: /^\/issues\/([^/]+)\/dispatch$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const issue = mockIssues().find((i) => i.id === id) ?? mockIssues()[0];
      return {
        ok: true,
        message: `Issue dispatched to ${issue.assignee_name ?? "agent"}.`,
      };
    },
  },
  {
    // POST /issues/:id/assign  POST /issues/:id/checkout  GET /issues/:id/comments  POST /issues/:id/comments
    pattern: /^\/issues\/([^/]+)\/([^/]+)$/,
    handler: (_path, options) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "GET") return { comments: [] };
      return undefined;
    },
  },
  {
    // GET/PATCH/DELETE /issues/:id
    pattern: /^\/issues\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteIssue(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Issue>;
          return updateIssue(id, body) ?? { error: "not_found" };
        } catch {
          return mockIssues().find((i) => i.id === id) ?? mockIssues()[0];
        }
      }
      return mockIssues().find((i) => i.id === id) ?? mockIssues()[0];
    },
  },
  {
    // GET /issues + POST /issues
    pattern: /^\/issues$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newIssue: Issue = {
          id: `iss-new-${Date.now()}`,
          title: (body.title as string) ?? "New Issue",
          description: (body.description as string | null) ?? null,
          status: ((body.status as string) ?? "todo") as IssueStatus,
          priority: ((body.priority as string) ?? "medium") as IssuePriority,
          assignee_id: (body.assignee_id as string | null) ?? null,
          assignee_name: (body.assignee_name as string | null) ?? null,
          project_id: (body.project_id as string) ?? "",
          goal_id: (body.goal_id as string | null) ?? null,
          labels: (body.labels as string[]) ?? [],
          comments_count: 0,
          created_by: (body.created_by as string) ?? "user",
          created_at: now,
          updated_at: now,
        };
        addIssue(newIssue);
        return newIssue;
      }
      return { issues: mockIssues() };
    },
  },

  // ── Goals (project-scoped) ────────────────────────────────────────────────────
  {
    pattern: /^\/projects\/([^/]+)\/goals\/([^/]+)$/,
    handler: (path, options) => {
      const goalId = path.split("/")[4];
      const method = (options.method ?? "GET").toUpperCase();
      const goal = getGoalById(goalId) ?? getGoalTree()[0];
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          );
          return { ...goal, ...body, updated_at: new Date().toISOString() };
        } catch {
          return goal;
        }
      }
      return goal;
    },
  },
  {
    pattern: /^\/projects\/([^/]+)\/goals$/,
    handler: (path, options) => {
      const projectId = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newGoal: Goal = {
          id: `goal-${Date.now()}`,
          title: (body.title as string) ?? "New Goal",
          description: (body.description as string | null) ?? null,
          parent_id: (body.parent_id as string | null) ?? null,
          project_id: projectId,
          status: ((body.status as GoalStatus) ?? "active") as GoalStatus,
          priority: ((body.priority as GoalPriority) ??
            "medium") as GoalPriority,
          progress: 0,
          assignee_id: (body.assignee_id as string | null) ?? null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        addGoal(newGoal);
        return newGoal;
      }
      return { goals: getGoalTree(projectId) };
    },
  },

  // ── Goals (standalone — legacy or direct access) ──────────────────────────────
  {
    pattern: /^\/goals\/tree$/,
    handler: () => ({ tree: getGoalTree() }),
  },
  {
    // POST /goals/:id/decompose
    pattern: /^\/goals\/([^/]+)\/decompose$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return {
        status: "started",
        goal_id: id,
        message: "Goal decomposition started. Issues will appear shortly.",
      };
    },
  },
  {
    // GET /goals/:id/ancestry
    pattern: /^\/goals\/([^/]+)\/ancestry$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const goal = getGoalById(id);
      return { ancestry: goal ? [goal] : [] };
    },
  },
  {
    // GET/PATCH/PUT/DELETE /goals/:id
    pattern: /^\/goals\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "PATCH" || method === "PUT") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const updated = updateGoal(id, body as Partial<Goal>);
        return updated ?? { error: "not_found" };
      }
      if (method === "DELETE") {
        deleteGoal(id);
        return { ok: true };
      }
      return getGoalById(id) ?? { error: "not_found" };
    },
  },
  {
    // GET /goals + POST /goals
    pattern: /^\/goals$/,
    handler: (_path, options) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newGoal: Goal = {
          id: `goal-${Date.now()}`,
          title: (body.title as string) ?? "New Goal",
          description: (body.description as string | null) ?? null,
          parent_id: (body.parent_id as string | null) ?? null,
          project_id: (body.project_id as string) ?? "",
          status: ((body.status as GoalStatus) ?? "active") as GoalStatus,
          priority: ((body.priority as GoalPriority) ??
            "medium") as GoalPriority,
          progress: 0,
          assignee_id: (body.assignee_id as string | null) ?? null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        addGoal(newGoal);
        return newGoal;
      }
      return { goals: getGoals(), count: getGoals().length };
    },
  },

  // ── Projects ──────────────────────────────────────────────────────────────────
  {
    // GET/PATCH/PUT/DELETE /projects/:id
    pattern: /^\/projects\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "PATCH" || method === "PUT") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const updated = updateProject(
          id,
          body as Partial<import("../types").Project>,
        );
        return updated ?? { error: "not_found" };
      }
      if (method === "DELETE") {
        deleteProject(id);
        return { ok: true };
      }
      return getProjectById(id);
    },
  },
  {
    // GET /projects + POST /projects
    pattern: /^\/projects$/,
    handler: (_path, options) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newProject: import("../types").Project = {
          id: `proj-${Date.now()}`,
          name: (body.name as string) ?? "New Project",
          description: (body.description as string | null) ?? null,
          status: "active",
          workspace_path:
            (body.workspace_path as string) ?? "~/.canopy/projects",
          goal_count: 0,
          issue_count: 0,
          agent_count: 0,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        addProject(newProject);
        return newProject;
      }
      return { projects: getProjects(), count: getProjects().length };
    },
  },

  // ── Documents ────────────────────────────────────────────────────────────────
  {
    pattern: /^\/documents\/tree$/,
    handler: () => ({ tree: getDocumentTree() }),
  },
  {
    pattern: /^\/documents\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteDocument(id);
        return { ok: true };
      }
      if ((method === "PUT" || method === "PATCH") && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Document>;
          return {
            document: updateDocument(id, body) ?? { error: "not_found" },
          };
        } catch {
          return { document: getDocumentById(id) };
        }
      }
      return { document: getDocumentById(id) };
    },
  },
  {
    pattern: /^\/documents$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newDoc: Document = {
          id: `doc-new-${Date.now()}`,
          title: (body.title as string) ?? "New Document",
          path: (body.path as string) ?? "reference/new-doc.md",
          format: ((body.format as string) ?? "markdown") as Document["format"],
          project_id: (body.project_id as string) ?? "proj-1",
          last_edited_by: (body.last_edited_by as string) ?? "User",
          created_at: now,
          updated_at: now,
          content: (body.content as string) ?? "",
        };
        addDocument(newDoc);
        return { document: newDoc };
      }
      return {
        documents: getDocuments(),
        count: getDocuments().length,
      };
    },
  },

  // ── Costs ─────────────────────────────────────────────────────────────────────
  { pattern: /^\/costs\/summary$/, handler: () => mockCosts().summary },
  {
    pattern: /^\/costs\/by-agent$/,
    handler: () => ({ agents: mockCosts().byAgent }),
  },
  {
    pattern: /^\/costs\/by-model$/,
    handler: () => ({ models: mockCosts().byModel }),
  },
  {
    // GET /costs/daily?from=YYYY-MM-DD&to=YYYY-MM-DD
    pattern: /^\/costs\/daily/,
    handler: (_path, _options, rawPath) => {
      const url = new URL("http://x" + rawPath);
      const toStr = url.searchParams.get("to");
      const fromStr = url.searchParams.get("from");
      const to = toStr ? new Date(toStr) : new Date();
      const from = fromStr
        ? new Date(fromStr)
        : new Date(to.getTime() - 30 * 86_400_000);
      const days = Math.round((to.getTime() - from.getTime()) / 86_400_000) + 1;
      const points: { date: string; cost_cents: number }[] = [];
      for (let i = 0; i < days; i++) {
        const d = new Date(from.getTime() + i * 86_400_000);
        const dateStr = d.toISOString().slice(0, 10);
        // Simulate realistic cost variation: weekend dips, weekday peaks
        const dow = d.getDay();
        const base = dow === 0 || dow === 6 ? 150 : 500;
        const jitter = Math.floor(
          Math.sin(i * 2.5) * 200 + Math.cos(i * 1.3) * 150,
        );
        points.push({ date: dateStr, cost_cents: Math.max(0, base + jitter) });
      }
      return { points };
    },
  },

  // ── Budgets ────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/budgets\/incidents$/,
    handler: () => ({ incidents: mockCosts().incidents }),
  },
  {
    pattern: /^\/budgets$/,
    handler: () => ({ policies: mockCosts().policies }),
  },

  // ── Analytics ─────────────────────────────────────────────────────────────────
  {
    pattern: /^\/analytics\/summary$/,
    handler: (_path, _options, rawPath) => {
      const period =
        new URL("http://x" + rawPath).searchParams.get("period") ?? "30d";
      return mockAnalytics(period);
    },
  },
  {
    pattern: /^\/analytics\/agents$/,
    handler: (_path, _options, rawPath) => {
      const period =
        new URL("http://x" + rawPath).searchParams.get("period") ?? "30d";
      return { agents: mockAnalytics(period).agent_metrics };
    },
  },
  {
    pattern: /^\/analytics\/teams$/,
    handler: (_path, _options, rawPath) => {
      const period =
        new URL("http://x" + rawPath).searchParams.get("period") ?? "30d";
      return { teams: mockAnalytics(period).team_metrics };
    },
  },

  // ── Work Products ─────────────────────────────────────────────────────────────
  {
    pattern: /^\/work-products\/([^/]+)\/archive$/,
    handler: () => ({ ok: true }),
  },
  {
    pattern: /^\/work-products\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const product = mockWorkProducts().find((p) => p.id === id);
      return product ? { product } : { error: "not found" };
    },
  },
  {
    pattern: /^\/work-products$/,
    handler: () => ({
      products: mockWorkProducts(),
      count: mockWorkProducts().length,
    }),
  },

  // ── Conversations ─────────────────────────────────────────────────────────────
  {
    // POST /conversations/:id/archive
    pattern: /^\/conversations\/([^/]+)\/archive$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const conv = archiveMockConversation(id);
      return conv ? { conversation: conv } : { error: "not_found" };
    },
  },
  {
    // GET /conversations/:id/messages  |  POST /conversations/:id/messages
    pattern: /^\/conversations\/([^/]+)\/messages$/,
    handler: (path, options, rawPath) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const content = (body.content as string) ?? "";
        return mockSendMessage(id, content);
      }
      const params = new URLSearchParams((rawPath ?? "").split("?")[1] ?? "");
      const limit = Math.min(parseInt(params.get("limit") ?? "50", 10), 200);
      const msgs = getMockConversationMessages(id).slice(-limit);
      return { messages: msgs, count: msgs.length };
    },
  },
  {
    // GET/DELETE /conversations/:id
    pattern: /^\/conversations\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteMockConversation(id);
        return undefined;
      }
      const conv = getMockConversationById(id);
      if (!conv) return { error: "not_found" };
      return {
        conversation: conv,
        messages: getMockConversationMessages(id).slice(-50),
      };
    },
  },
  {
    // GET /conversations  |  POST /conversations
    pattern: /^\/conversations$/,
    handler: (_path, options, rawPath) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newConv = {
          id: `conv-new-${Date.now()}`,
          title: (body.title as string) ?? null,
          agent_id: (body.agent_id as string) ?? "agent-1",
          agent_name: "Agent",
          agent_avatar: "🤖",
          workspace_id: (body.workspace_id as string) ?? null,
          user_id: null,
          status: "active" as const,
          last_message_at: null,
          message_count: 0,
          metadata: {},
          inserted_at: now,
          updated_at: now,
        };
        addMockConversation(newConv);
        return { conversation: newConv };
      }
      const params = new URLSearchParams((rawPath ?? "").split("?")[1] ?? "");
      const filters = {
        agent_id: params.get("agent_id") ?? undefined,
        status: params.get("status") ?? undefined,
      };
      const convs = getMockConversations(filters);
      return { conversations: convs, total: convs.length };
    },
  },

  // ── Activity ──────────────────────────────────────────────────────────────────
  { pattern: /^\/activity/, handler: () => ({ events: mockActivity() }) },

  // ── Notifications ─────────────────────────────────────────────────────────────
  {
    // GET /notifications/badges  — must come before /:id pattern
    pattern: /^\/notifications\/badges$/,
    handler: () => getMockNotificationBadges(),
  },
  {
    // POST /notifications/mark-all-read
    pattern: /^\/notifications\/mark-all-read$/,
    handler: (_path, options) => {
      let category: string | undefined;
      if (options.body) {
        try {
          const body =
            typeof options.body === "string"
              ? JSON.parse(options.body)
              : options.body;
          category = (body as { category?: string }).category;
        } catch {
          // ignore
        }
      }
      markAllNotificationsRead(category);
      return { ok: true };
    },
  },
  {
    // POST /notifications/:id/read
    pattern: /^\/notifications\/([^/]+)\/read$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const notification = markNotificationRead(id);
      return { notification: notification ?? { error: "not_found" } };
    },
  },
  {
    // POST /notifications/:id/dismiss
    pattern: /^\/notifications\/([^/]+)\/dismiss$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const notification = dismissNotification(id);
      return { notification: notification ?? { error: "not_found" } };
    },
  },
  {
    // GET /notifications/:id
    pattern: /^\/notifications\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const notification = getMockNotificationById(id);
      return { notification: notification ?? { error: "not_found" } };
    },
  },
  {
    // GET /notifications  (with optional ?category=, ?unread=, ?severity=, ?limit=, ?offset=)
    // POST /notifications (create)
    pattern: /^\/notifications$/,
    handler: (_path, options, rawPath) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        // Create — just echo back a fake notification
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        return {
          notification: {
            id: `ntf-new-${Date.now()}`,
            workspace_id: "ws-1",
            recipient_type: "user",
            recipient_id: null,
            sender_type: "system",
            sender_id: null,
            category: (body.category as string) ?? "system",
            severity: (body.severity as string) ?? "info",
            title: (body.title as string) ?? "New notification",
            body: (body.body as string) ?? null,
            action_url: null,
            action_label: null,
            metadata: {},
            read_at: null,
            dismissed_at: null,
            expires_at: null,
            inserted_at: now,
          },
        };
      }

      // GET with filters
      const params = new URLSearchParams((rawPath ?? "").split("?")[1] ?? "");
      const category = params.get("category");
      const severity = params.get("severity");
      const unread = params.get("unread");
      const limit = params.get("limit")
        ? parseInt(params.get("limit")!, 10)
        : undefined;
      const offset = params.get("offset")
        ? parseInt(params.get("offset")!, 10)
        : 0;

      let results = getMockNotifications().filter((n) => !n.dismissed_at);
      if (category) results = results.filter((n) => n.category === category);
      if (severity) results = results.filter((n) => n.severity === severity);
      if (unread === "true") results = results.filter((n) => !n.read_at);

      const total = results.length;
      if (offset) results = results.slice(offset);
      if (limit !== undefined) results = results.slice(0, limit);

      return { notifications: results, total };
    },
  },

  // ── Inbox ─────────────────────────────────────────────────────────────────────
  {
    // POST /inbox/read-all
    pattern: /^\/inbox\/read-all$/,
    handler: () => {
      const items = getInbox();
      for (const item of items) {
        if (item.status === "unread") item.status = "read";
      }
      return { ok: true };
    },
  },
  {
    // POST /inbox/:id/read
    pattern: /^\/inbox\/([^/]+)\/read$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const item = getInbox().find((i) => i.id === id);
      if (item && item.status === "unread") item.status = "read";
      return { item };
    },
  },
  {
    // POST /inbox/:id/actions/:actionId  or  /inbox/:id/action
    pattern: /^\/inbox\/([^/]+)\/(actions?|dismiss)(\/([^/]+))?$/,
    handler: (path, options) => {
      const parts = path.split("/");
      const itemId = parts[2];
      let actionId = parts[4] ?? "ack";
      if (!parts[4] && options.body) {
        try {
          const body =
            typeof options.body === "string"
              ? JSON.parse(options.body)
              : options.body;
          actionId = (body as { action_id?: string }).action_id ?? "ack";
        } catch {
          // ignore
        }
      }
      if (path.includes("/dismiss")) actionId = "ack";
      return { item: performInboxAction(itemId, actionId) };
    },
  },
  {
    pattern: /^\/inbox$/,
    handler: () => ({ items: getInbox(), count: getInbox().length }),
  },

  // ── Skills ────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/skills\/([^/]+)\/toggle$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const toggled = toggleSkill(id);
      return toggled ?? mockSkills()[0];
    },
  },
  { pattern: /^\/skills$/, handler: () => ({ skills: mockSkills() }) },

  // ── Webhooks ──────────────────────────────────────────────────────────────────
  {
    // GET/PATCH/DELETE /webhooks/:id
    pattern: /^\/webhooks\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteWebhook(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Webhook>;
          return updateWebhook(id, body) ?? { error: "not_found" };
        } catch {
          return mockWebhooks().find((w) => w.id === id) ?? mockWebhooks()[0];
        }
      }
      return mockWebhooks().find((w) => w.id === id) ?? mockWebhooks()[0];
    },
  },
  {
    pattern: /^\/webhooks$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newWebhook: Webhook = {
          id: `wh-new-${Date.now()}`,
          name: (body.name as string) ?? "New Webhook",
          direction: ((body.direction as string) ??
            "incoming") as Webhook["direction"],
          url: (body.url as string) ?? "",
          events: (body.events as string[]) ?? [],
          secret: (body.secret as string | null) ?? null,
          enabled: (body.enabled as boolean) ?? true,
          last_triggered_at: null,
          failure_count: 0,
          created_at: new Date().toISOString(),
        };
        addWebhook(newWebhook);
        return newWebhook;
      }
      return { webhooks: mockWebhooks() };
    },
  },

  // ── Alerts ────────────────────────────────────────────────────────────────────
  {
    // DELETE /alerts/rules/:id
    pattern: /^\/alerts\/rules\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[3];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteAlertRule(id);
        return { ok: true };
      }
      return mockAlertRules().find((r) => r.id === id) ?? mockAlertRules()[0];
    },
  },
  {
    pattern: /^\/alerts\/rules$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newRule: AlertRule = {
          id: `ar-new-${Date.now()}`,
          name: (body.name as string) ?? "New Alert Rule",
          entity_type: ((body.entity_type as string) ??
            "agent") as AlertRule["entity_type"],
          field: (body.field as string) ?? "error_rate",
          operator: ((body.operator as string) ??
            "gt") as AlertRule["operator"],
          value: (body.value as string) ?? "0.1",
          action: ((body.action as string) ?? "notify") as AlertRule["action"],
          enabled: (body.enabled as boolean) ?? true,
          triggered_count: 0,
          last_triggered_at: null,
          created_at: new Date().toISOString(),
        };
        addAlertRule(newRule);
        return newRule;
      }
      return { rules: mockAlertRules() };
    },
  },
  { pattern: /^\/alerts$/, handler: () => ({ rules: mockAlertRules() }) },

  // ── Integrations ──────────────────────────────────────────────────────────────
  {
    pattern: /^\/integrations$/,
    handler: () => ({ integrations: mockIntegrations() }),
  },

  // ── Adapters ──────────────────────────────────────────────────────────────────
  {
    pattern: /^\/adapters$/,
    handler: () => ({ adapters: mockAdapters() }),
  },

  // ── Gateways ──────────────────────────────────────────────────────────────────
  {
    // GET/PATCH/DELETE /gateways/:id
    pattern: /^\/gateways\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteGateway(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Gateway>;
          return updateGateway(id, body) ?? { error: "not_found" };
        } catch {
          return mockGateways().find((g) => g.id === id) ?? mockGateways()[0];
        }
      }
      return mockGateways().find((g) => g.id === id) ?? mockGateways()[0];
    },
  },
  {
    pattern: /^\/gateways$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const newGateway: Gateway = {
          id: `gw-new-${Date.now()}`,
          name: (body.name as string) ?? "New Gateway",
          provider: (body.provider as string) ?? "anthropic",
          endpoint: (body.endpoint as string) ?? "",
          api_key_set: false,
          is_primary: false,
          status: "down",
          latency_ms: null,
          last_probe_at: null,
          models: (body.models as string[]) ?? [],
          created_at: new Date().toISOString(),
        };
        addGateway(newGateway);
        return newGateway;
      }
      return { gateways: mockGateways() };
    },
  },

  // ── Workspaces ────────────────────────────────────────────────────────────────
  {
    pattern: /^\/workspaces$/,
    handler: (_path, options) => {
      const defaultWorkspaces = [
        {
          id: "ws-osa-dev",
          name: "OSA Development",
          description: "Main development workspace",
          directory: "~/.canopy/default",
          agent_count: 6,
          project_count: 2,
          skill_count: 4,
          status: "active" as const,
          created_at: "2026-01-01T00:00:00Z",
          updated_at: new Date().toISOString(),
        },
      ];
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body =
            typeof options.body === "string"
              ? JSON.parse(options.body)
              : (options.body ?? {});
        } catch {
          /* ignore */
        }
        const name = (body.name as string) ?? "New Workspace";
        return {
          id: `ws-${Date.now()}`,
          name,
          description: "",
          directory:
            (body.directory as string) ??
            `~/.canopy/${name.toLowerCase().replace(/\s+/g, "-")}`,
          agent_count: 0,
          project_count: 0,
          skill_count: 0,
          status: "active" as const,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { workspaces: defaultWorkspaces };
    },
  },

  // ── Workspace activate ────────────────────────────────────────────────────────
  {
    pattern: /^\/workspaces\/[^/]+\/activate$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return {
        workspace: {
          id,
          name: "Workspace",
          description: "",
          directory: `~/.canopy/${id}`,
          agent_count: 0,
          project_count: 0,
          skill_count: 0,
          status: "active" as const,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        },
      };
    },
  },

  // ── Settings ──────────────────────────────────────────────────────────────────
  {
    pattern: /^\/settings$/,
    handler: (_path, options) => {
      const base = {
        theme: "dark" as const,
        font_size: 15,
        sidebar_default_collapsed: false,
        notifications_enabled: true,
        auto_approve_budget_under_cents: 100,
        default_adapter: "osa" as const,
        default_model: "claude-sonnet-4-6",
        working_directory: "~",
      };
      if ((options.method ?? "GET").toUpperCase() === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          );
          return { ...base, ...body };
        } catch {
          return base;
        }
      }
      return base;
    },
  },

  // ── Audit ─────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/audit/,
    handler: () => ({ entries: mockAudit() }),
  },

  // ── Logs ──────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/logs/,
    handler: () => ({ entries: mockLogs() }),
  },

  // ── Memory ────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/memory\/search$/,
    handler: (_path, _options, rawPath) => {
      const q = new URLSearchParams(rawPath.split("?")[1] ?? "").get("q") ?? "";
      return {
        entries: searchMockMemory(q),
        count: searchMockMemory(q).length,
      };
    },
  },
  {
    pattern: /^\/memory\/namespaces$/,
    handler: () => ({ namespaces: getMockMemoryNamespaces() }),
  },
  {
    pattern: /^\/memory\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteMockEntry(id);
        return undefined;
      }
      if (method === "PUT" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          );
          return { entry: updateMockEntry(id, body) };
        } catch {
          return { entry: getMockMemoryById(id) };
        }
      }
      return { entry: getMockMemoryById(id) };
    },
  },
  {
    pattern: /^\/memory$/,
    handler: (_path, options) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          );
          return { entry: createMockEntry(body) };
        } catch {
          return { entry: null };
        }
      }
      return {
        entries: getMutableEntries(),
        count: getMutableEntries().length,
      };
    },
  },

  // ── Signals ───────────────────────────────────────────────────────────────────
  {
    pattern: /^\/signals\/feed$/,
    handler: () => ({ signals: mockSignals() }),
  },
  {
    pattern: /^\/signals/,
    handler: () => ({ signals: mockSignals() }),
  },

  // ── Spawn ─────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/spawn\/active$/,
    handler: () => {
      const instances = getSpawnInstances().filter(
        (i) => i.status === "running",
      );
      return { instances, count: instances.length };
    },
  },
  {
    // DELETE /spawn/:id
    pattern: /^\/spawn\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteSpawn(id);
        return { ok: true };
      }
      return (
        getSpawnInstances().find((s) => s.id === id) ?? getSpawnInstances()[0]
      );
    },
  },
  {
    pattern: /^\/spawn$/,
    handler: (_path, options) => {
      if (options.method?.toUpperCase() === "POST") {
        let body: Partial<{
          agent_id: string;
          agent_name: string;
          task: string;
          model: string;
        }> = {};
        if (options.body) {
          try {
            body =
              typeof options.body === "string"
                ? JSON.parse(options.body)
                : (options.body as typeof body);
          } catch {
            // use empty body
          }
        }
        return { instance: createSpawnInstance(body) };
      }
      const instances = getSpawnInstances();
      return { instances, count: instances.length };
    },
  },

  // ── Templates ─────────────────────────────────────────────────────────────────
  {
    pattern: /^\/templates\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        return undefined;
      }
      if (method === "PATCH" && options.body) {
        const existing =
          mockTemplates().find((t) => t.id === id) ?? mockTemplates()[0];
        let updates: Record<string, unknown> = {};
        try {
          updates = JSON.parse(
            typeof options.body === "string" ? options.body : "{}",
          ) as Record<string, unknown>;
        } catch {
          /* ignore */
        }
        return { ...existing, ...updates, id };
      }
      return mockTemplates().find((t) => t.id === id) ?? mockTemplates()[0];
    },
  },
  {
    pattern: /^\/templates$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(
            typeof options.body === "string" ? options.body : "{}",
          ) as Record<string, unknown>;
        } catch {
          /* ignore */
        }
        return {
          id: `tpl-${Date.now()}`,
          name: (body.name as string) ?? "New Template",
          description: (body.description as string) ?? "",
          adapter: (body.adapter as string) ?? "claude_code",
          model: (body.model as string) ?? "claude-sonnet-4-20250514",
          system_prompt: (body.system_prompt as string) ?? "",
          skills: (body.skills as string[]) ?? [],
          config: (body.config as Record<string, unknown>) ?? {},
          category: (body.category as string) ?? "starter",
          downloads: 0,
          created_at: new Date().toISOString(),
        };
      }
      return { templates: mockTemplates() };
    },
  },

  // ── Config ────────────────────────────────────────────────────────────────────
  { pattern: /^\/config/, handler: () => ({ config: mockConfig() }) },

  // ── Users ─────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/users\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return mockUsers().find((u) => u.id === id) ?? mockUsers()[0];
    },
  },
  { pattern: /^\/users$/, handler: () => ({ users: mockUsers() }) },

  // ── Secrets ──────────────────────────────────────────────────────────────────
  {
    pattern: /^\/secrets\/([^/]+)\/rotate$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const secret = mockSecrets().find((s) => s.id === id) ?? mockSecrets()[0];
      return { ...secret, last_rotated_at: new Date().toISOString() };
    },
  },
  {
    pattern: /^\/secrets\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return undefined;
      return mockSecrets().find((s) => s.id === id) ?? mockSecrets()[0];
    },
  },
  {
    pattern: /^\/secrets$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `secret-new-${Date.now()}`,
          name: "new-secret",
          type: "api_key",
          description: null,
          last_rotated_at: null,
          expires_at: null,
          created_by: "user-admin",
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { secrets: mockSecrets() };
    },
  },

  // ── Approvals ──────────────────────────────────────────────────────────────────
  {
    pattern: /^\/approvals\/([^/]+)\/(approve|reject)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const action = path.split("/")[3];
      const base =
        mockApprovals().find((a) => a.id === id) ?? mockApprovals()[0];
      return {
        ...base,
        status: action === "approve" ? "approved" : "rejected",
        reviewed_by: "user-admin",
        reviewer_name: "Admin User",
        reviewed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
    },
  },
  {
    pattern: /^\/approvals\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return mockApprovals().find((a) => a.id === id) ?? mockApprovals()[0];
    },
  },
  {
    pattern: /^\/approvals$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `approval-new-${Date.now()}`,
          title: "New approval request",
          description: null,
          status: "pending",
          requester_id: "user-admin",
          requester_name: "Admin User",
          reviewer_id: null,
          reviewer_name: null,
          entity_type: null,
          entity_id: null,
          comment: null,
          expires_at: null,
          reviewed_at: null,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { approvals: mockApprovals() };
    },
  },

  // ── Organizations ──────────────────────────────────────────────────────────────
  {
    pattern: /^\/organizations\/([^/]+)\/members$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return { members: mockOrgMembers(id) };
    },
  },
  {
    pattern: /^\/organizations\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return undefined;
      return (
        mockOrganizations().find((o) => o.id === id) ?? mockOrganizations()[0]
      );
    },
  },
  {
    pattern: /^\/organizations$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `org-new-${Date.now()}`,
          name: "New Org",
          slug: "new-org",
          description: null,
          avatar_url: null,
          plan: "free",
          member_count: 1,
          agent_count: 0,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { organizations: mockOrganizations() };
    },
  },

  // ── Labels ─────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/labels\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return undefined;
      return mockLabels().find((l) => l.id === id) ?? mockLabels()[0];
    },
  },
  {
    pattern: /^\/labels$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `label-new-${Date.now()}`,
          name: "new-label",
          color: "#3b82f6",
          description: null,
          project_id: null,
          issue_count: 0,
          created_at: new Date().toISOString(),
        };
      }
      return { labels: mockLabels() };
    },
  },

  // ── Plugins ────────────────────────────────────────────────────────────────────
  {
    pattern: /^\/plugins\/([^/]+)\/logs$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return { logs: mockPluginLogs(id) };
    },
  },
  {
    pattern: /^\/plugins\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return undefined;
      return mockPlugins().find((p) => p.id === id) ?? mockPlugins()[0];
    },
  },
  {
    pattern: /^\/plugins$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `plugin-new-${Date.now()}`,
          name: "New Plugin",
          description: "",
          version: "1.0.0",
          author: "MIOSA",
          status: "inactive",
          enabled: false,
          config: {},
          capabilities: [],
          installed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { plugins: mockPlugins() };
    },
  },

  // ── Access / Role Assignments ──────────────────────────────────────────────────
  {
    pattern: /^\/access\/([^/]+)$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return undefined;
      return {
        id: "ra-1",
        user_id: "user-admin",
        role: "admin",
        scope: "global",
      };
    },
  },
  {
    pattern: /^\/access(\/assign)?$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `ra-new-${Date.now()}`,
          user_id: "user-admin",
          role: "admin",
          scope: "global",
          created_at: new Date().toISOString(),
        };
      }
      return {
        assignments: [
          {
            id: "ra-1",
            user_id: "user-admin",
            user_name: "Admin User",
            role: "admin",
            scope: "global",
            resource_type: null,
            resource_id: null,
            created_at: "2026-01-01T00:00:00Z",
          },
          {
            id: "ra-2",
            user_id: "user-dev",
            user_name: "Dev User",
            role: "member",
            scope: "workspace",
            resource_type: "workspace",
            resource_id: "ws-osa-dev",
            created_at: "2026-01-15T00:00:00Z",
          },
        ],
      };
    },
  },

  // ── Hierarchy / Org Structure ──────────────────────────────────────────────────
  {
    pattern: /^\/divisions\/([^/]+)\/departments$/,
    handler: () => ({ departments: [] }),
  },
  {
    pattern: /^\/divisions\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "PATCH" && options.body) {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id,
          name: "Division",
          slug: "division",
          departments: [],
          ...body,
        };
      }
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return { ok: true };
      return { id, name: "Division", slug: "division", departments: [] };
    },
  },
  {
    // POST /divisions — create a new division
    pattern: /^\/divisions$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id: `div-${Date.now()}`,
          name: (body.name as string) ?? "New Division",
          slug: ((body.name as string) ?? "division")
            .toLowerCase()
            .replace(/\s+/g, "-"),
          workspace_id: (body.workspace_id as string) ?? null,
          head_agent_id: (body.head_agent_id as string) ?? null,
          budget_cents: 0,
          departments: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { divisions: [] };
    },
  },
  {
    pattern: /^\/departments\/([^/]+)\/teams$/,
    handler: () => ({ teams: [] }),
  },
  {
    pattern: /^\/departments\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "PATCH" && options.body) {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id,
          name: "Department",
          slug: "department",
          teams: [],
          ...body,
        };
      }
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return { ok: true };
      return { id, name: "Department", slug: "department", teams: [] };
    },
  },
  {
    // POST /departments — create a new department
    pattern: /^\/departments$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id: `dept-${Date.now()}`,
          name: (body.name as string) ?? "New Department",
          slug: ((body.name as string) ?? "department")
            .toLowerCase()
            .replace(/\s+/g, "-"),
          division_id: (body.division_id as string) ?? null,
          workspace_id: (body.workspace_id as string) ?? null,
          head_agent_id: (body.head_agent_id as string) ?? null,
          budget_cents: 0,
          teams: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { departments: [] };
    },
  },
  {
    pattern: /^\/teams\/([^/]+)\/(agents|members)$/,
    handler: (path, options) => {
      const teamId = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id: `tm-${Date.now()}`,
          team_id: teamId,
          agent_id: (body.agent_id as string) ?? null,
          role: (body.role as string) ?? "member",
          joined_at: new Date().toISOString(),
        };
      }
      return { agents: [], members: [] };
    },
  },
  {
    pattern: /^\/teams\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      if ((options.method ?? "GET").toUpperCase() === "PATCH" && options.body) {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return { id, name: "Team", slug: "team", agents: [], ...body };
      }
      if ((options.method ?? "GET").toUpperCase() === "DELETE")
        return { ok: true };
      return { id, name: "Team", slug: "team", agents: [] };
    },
  },
  {
    // POST /teams — create a new team
    pattern: /^\/teams$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        const body = JSON.parse(
          typeof options.body === "string" ? options.body : "{}",
        ) as Record<string, unknown>;
        return {
          id: `team-${Date.now()}`,
          name: (body.name as string) ?? "New Team",
          slug: ((body.name as string) ?? "team")
            .toLowerCase()
            .replace(/\s+/g, "-"),
          department_id: (body.department_id as string) ?? null,
          workspace_id: (body.workspace_id as string) ?? null,
          manager_agent_id: (body.manager_agent_id as string) ?? null,
          budget_cents: 0,
          agents: [],
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
      }
      return { teams: [] };
    },
  },
  // ── Skills sub-routes ──────────────────────────────────────────────────────────
  {
    pattern: /^\/skills\/categories$/,
    handler: () => ({
      categories: [
        "automation",
        "analysis",
        "communication",
        "development",
        "research",
      ],
    }),
  },
  {
    pattern: /^\/skills\/(bulk-enable|bulk-disable|import)$/,
    handler: () => ({ ok: true }),
  },
  {
    pattern: /^\/skills\/([^/]+)\/(toggle|inject)$/,
    handler: () => ({ ok: true }),
  },
  {
    pattern: /^\/skills\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return { id, name: "Skill", enabled: true };
    },
  },
  // ── Webhooks sub-routes ────────────────────────────────────────────────────────
  {
    pattern: /^\/webhooks\/([^/]+)\/test$/,
    handler: () => ({ success: true, status_code: 200, response_time_ms: 150 }),
  },
  {
    pattern: /^\/webhooks\/([^/]+)\/deliveries$/,
    handler: () => ({ deliveries: [] }),
  },
  // ── Budgets sub-routes ─────────────────────────────────────────────────────────
  {
    pattern:
      /^\/budgets\/(agent|team|department|division|organization|workspace)\/([^/]+)$/,
    handler: () => ({ ok: true }),
  },
  {
    pattern: /^\/budgets\/incidents\/([^/]+)\/resolve$/,
    handler: () => ({ ok: true }),
  },
  // ── Projects sub-routes ────────────────────────────────────────────────────────
  {
    pattern: /^\/projects\/([^/]+)\/workspaces$/,
    handler: () => ({ workspaces: [] }),
  },
  // ── Workspaces sub-routes ──────────────────────────────────────────────────────
  {
    pattern: /^\/workspaces\/([^/]+)\/(agents|skills|config)$/,
    handler: (path) => {
      const sub = path.split("/")[3];
      if (sub === "agents") return { agents: [] };
      if (sub === "skills") return { skills: [] };
      return { config: {} };
    },
  },
  {
    pattern: /^\/workspaces\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return { id, name: "Workspace", path: "/workspace", agents: [] };
    },
  },
  // ── Integrations sub-routes ────────────────────────────────────────────────────
  {
    pattern: /^\/integrations\/([^/]+)\/(connect|disconnect|status)$/,
    handler: (path) => {
      const action = path.split("/")[3];
      if (action === "status") return { connected: false, last_sync: null };
      return { ok: true };
    },
  },
  {
    pattern: /^\/integrations\/pull-all$/,
    handler: () => ({ ok: true, synced: 0 }),
  },
  // ── Schedules sub-routes ───────────────────────────────────────────────────────
  {
    pattern: /^\/schedules\/(wake-all|pause-all)$/,
    handler: () => ({ ok: true }),
  },
  // ── Alerts sub-routes ──────────────────────────────────────────────────────────
  {
    pattern: /^\/alerts\/evaluate$/,
    handler: () => ({ ok: true, triggered: 0 }),
  },
  // ── Invitations ────────────────────────────────────────────────────────────────
  {
    pattern: /^\/invitations\/([^/]+)\/accept$/,
    handler: () => ({ ok: true }),
  },
  // ── Config Revisions ───────────────────────────────────────────────────────────
  {
    pattern: /^\/config\/revisions\/([^/]+)\/restore$/,
    handler: () => ({ ok: true }),
  },
  // ── Datasets sub-routes ────────────────────────────────────────────────────────
  {
    pattern: /^\/datasets\/([^/]+)\/(preview|refresh|grant|revoke)$/,
    handler: (path) => {
      const action = path.split("/")[3];
      if (action === "preview") return { rows: [], columns: [] };
      return { ok: true };
    },
  },
  {
    pattern: /^\/datasets\/([^/]+)$/,
    handler: (path) => {
      const id = path.split("/")[2];
      return {
        id,
        name: "Dataset",
        source_type: "upload",
        format: "csv",
        row_count: 0,
        size_bytes: 0,
        status: "active",
      };
    },
  },
  // ── Notifications sub-routes ───────────────────────────────────────────────────
  {
    pattern: /^\/notifications\/mark-all-read$/,
    handler: () => ({ ok: true }),
  },
  {
    pattern: /^\/notifications\/([^/]+)\/(read|dismiss)$/,
    handler: () => ({ ok: true }),
  },

  // ── Sidebar Badges ─────────────────────────────────────────────────────────────
  {
    pattern: /^\/sidebar-badges$/,
    handler: () => ({
      inbox_unread: 3,
      approvals_pending: 1,
      issues_open: 2,
      agents_error: 0,
      budget_warnings: 0,
    }),
  },

  // ── Environment ────────────────────────────────────────────────────────────────
  {
    pattern: /^\/environment\/apps\/([^/]+)\/(grant|revoke)$/,
    handler: (path, options) => {
      const parts = path.split("/");
      const appId = parts[3];
      const action = parts[4];
      let body: Record<string, unknown> = {};
      try {
        body = JSON.parse(
          typeof options.body === "string"
            ? options.body
            : JSON.stringify(options.body ?? {}),
        );
      } catch {
        /* ignore */
      }
      const agentId = (body.agent_id as string) ?? "agent-1";
      if (action === "grant") {
        return { app: grantEnvironmentAccess(appId, agentId) };
      }
      return { app: revokeEnvironmentAccess(appId, agentId) };
    },
  },
  {
    pattern: /^\/environment\/apps$/,
    handler: () => ({ apps: mockEnvironmentApps() }),
  },
  {
    pattern: /^\/environment\/agent-apps$/,
    handler: () => ({ agent_apps: mockEnvironmentAgentApps() }),
  },
  {
    pattern: /^\/environment\/resources$/,
    handler: () => ({ resources: mockEnvironmentResources() }),
  },
  {
    pattern: /^\/environment\/capabilities$/,
    handler: () => ({ capabilities: mockEnvironmentCapabilities() }),
  },

  // ── Session Chain ──────────────────────────────────────────────────────────────
  {
    // GET /sessions/:id/chain
    pattern: /^\/sessions\/([^/]+)\/chain$/,
    handler: (path) => {
      const sessionId = path.split("/")[2];
      const now = new Date();
      const ms = (n: number) =>
        new Date(now.getTime() - n * 60_000).toISOString();
      return {
        sessions: [
          {
            id: `${sessionId}-1`,
            sequence_number: 1,
            context_summary:
              "Analyzed the codebase structure. Identified 14 modules across 3 layers. Key findings: auth middleware missing rate-limit headers, database connection pool configured too low for production load.",
            handoff_notes:
              "Continue with middleware audit. Focus on /api/v1/agents endpoint. Pool size should be raised to at least 20.",
            compaction_reason: "token_limit",
            total_tokens: 42_500,
            status: "completed",
            started_at: ms(120),
            ended_at: ms(60),
          },
          {
            id: `${sessionId}-2`,
            sequence_number: 2,
            context_summary:
              "Completed middleware audit. Rate-limit headers now present on all endpoints. Drafted connection pool config change.",
            handoff_notes:
              "Run integration tests against the updated pool config before merging.",
            compaction_reason: "manual",
            total_tokens: 31_200,
            status: "completed",
            started_at: ms(60),
            ended_at: ms(10),
          },
          {
            id: sessionId,
            sequence_number: 3,
            context_summary: null,
            handoff_notes: null,
            compaction_reason: null,
            total_tokens: 8_900,
            status: "active",
            started_at: ms(10),
            ended_at: null,
          },
        ],
        total_tokens: 82_600,
        total_cost_cents: 412,
      };
    },
  },
  {
    // POST /sessions/:id/compact
    pattern: /^\/sessions\/([^/]+)\/compact$/,
    handler: () => undefined,
  },

  // ── Dispatch ───────────────────────────────────────────────────────────────────
  {
    // POST /dispatch/preview
    pattern: /^\/dispatch\/preview$/,
    handler: (_path, options) => {
      let description = "";
      try {
        const body = JSON.parse(options.body as string) as {
          description?: string;
        };
        description = body.description ?? "";
      } catch {
        /* ignore */
      }
      const lower = description.toLowerCase();
      let recommended = "osa";
      let reason = "General-purpose tasks default to the OSA adapter.";
      const alternatives: { adapter: string; reason: string }[] = [];
      let confidence = 0.72;

      if (
        lower.includes("code") ||
        lower.includes("file") ||
        lower.includes("build") ||
        lower.includes("test")
      ) {
        recommended = "claude_code";
        reason =
          "Task involves code generation or file manipulation — Claude Code is optimised for this.";
        confidence = 0.91;
        alternatives.push({
          adapter: "osa",
          reason: "OSA can handle code tasks at lower speed.",
        });
        alternatives.push({
          adapter: "codex",
          reason: "Codex specialises in code completion workflows.",
        });
      } else if (
        lower.includes("search") ||
        lower.includes("research") ||
        lower.includes("web") ||
        lower.includes("browse")
      ) {
        recommended = "hermes";
        reason =
          "Task requires web search or research capabilities handled by the Hermes adapter.";
        confidence = 0.85;
        alternatives.push({
          adapter: "osa",
          reason: "OSA can perform basic web queries.",
        });
      } else if (
        lower.includes("bash") ||
        lower.includes("shell") ||
        lower.includes("command") ||
        lower.includes("script")
      ) {
        recommended = "bash";
        reason =
          "Task involves direct shell execution — the Bash adapter provides lowest-latency execution.";
        confidence = 0.94;
        alternatives.push({
          adapter: "claude_code",
          reason: "Claude Code can also run shell commands via tools.",
        });
      } else {
        alternatives.push({
          adapter: "claude_code",
          reason: "Claude Code handles a wide range of tasks.",
        });
        alternatives.push({
          adapter: "hermes",
          reason: "Hermes is a good fallback for research-adjacent tasks.",
        });
      }

      return {
        recommended_adapter: recommended,
        reason,
        confidence,
        alternatives,
      };
    },
  },
  {
    // GET /dispatch/routes
    pattern: /^\/dispatch\/routes$/,
    handler: () => ({
      routes: [
        {
          task_type: "code_generation",
          adapter: "claude_code",
          description: "Any task that generates, edits, or reviews code files.",
        },
        {
          task_type: "shell_execution",
          adapter: "bash",
          description:
            "Direct shell commands, scripts, and system-level operations.",
        },
        {
          task_type: "web_research",
          adapter: "hermes",
          description:
            "Tasks that require browsing or searching the web for information.",
        },
        {
          task_type: "code_completion",
          adapter: "codex",
          description: "Inline code completion and suggestion workflows.",
        },
        {
          task_type: "general",
          adapter: "osa",
          description:
            "Default adapter for planning, reasoning, and general-purpose tasks.",
        },
        {
          task_type: "http_webhook",
          adapter: "http",
          description: "Tasks that call external HTTP endpoints or webhooks.",
        },
        {
          task_type: "ide_integration",
          adapter: "cursor",
          description: "Tasks tightly coupled to the Cursor IDE workflow.",
        },
      ],
    }),
  },

  // ── Delegations ────────────────────────────────────────────────────────────────
  {
    // GET/POST /delegations
    pattern: /^\/delegations$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        return {
          id: `task-del-${Date.now()}`,
          parent_task_id: (body.parent_task_id as string) ?? null,
          description: (body.description as string) ?? "Delegated subtask",
          adapter: (body.adapter as string) ?? "osa",
          agent_id: (body.agent_id as string) ?? null,
          status: "pending",
          created_at: now,
        };
      }
      return { delegations: [] };
    },
  },

  // ── Session message send ───────────────────────────────────────────────────────
  {
    pattern: /^\/sessions\/([^/]+)\/message$/,
    handler: (path) => {
      const sessionId = path.split("/")[2];
      return {
        stream_id: `stream-${Date.now()}`,
        session_id: sessionId,
      };
    },
  },

  // ── Datasets — sub-routes before collection ────────────────────────────────────
  {
    // POST /datasets/:id/refresh
    pattern: /^\/datasets\/([^/]+)\/refresh$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const updated = updateMockDataset(id, {
        status: "processing",
        last_refreshed_at: new Date().toISOString(),
      });
      return updated
        ? { dataset: updated, message: "Refresh triggered" }
        : { error: "not_found" };
    },
  },
  {
    // POST /datasets/:id/grant
    pattern: /^\/datasets\/([^/]+)\/grant$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      let agentId = "";
      try {
        const body = JSON.parse(
          typeof options.body === "string"
            ? options.body
            : JSON.stringify(options.body ?? {}),
        ) as { agent_id?: string };
        agentId = body.agent_id ?? "";
      } catch {
        /* ignore */
      }
      const ds = mockDatasetById(id);
      if (!ds) return { error: "not_found" };
      const existing = ds.access_agents ?? [];
      const updated = updateMockDataset(id, {
        access_agents: existing.includes(agentId)
          ? existing
          : [agentId, ...existing],
      });
      return { dataset: updated };
    },
  },
  {
    // POST /datasets/:id/revoke
    pattern: /^\/datasets\/([^/]+)\/revoke$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      let agentId = "";
      try {
        const body = JSON.parse(
          typeof options.body === "string"
            ? options.body
            : JSON.stringify(options.body ?? {}),
        ) as { agent_id?: string };
        agentId = body.agent_id ?? "";
      } catch {
        /* ignore */
      }
      const ds = mockDatasetById(id);
      if (!ds) return { error: "not_found" };
      const updated = updateMockDataset(id, {
        access_agents: (ds.access_agents ?? []).filter((a) => a !== agentId),
      });
      return { dataset: updated };
    },
  },
  {
    // GET /datasets/:id/preview
    pattern: /^\/datasets\/([^/]+)\/preview$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const ds = mockDatasetById(id);
      if (!ds) return { error: "not_found" };
      const rows = mockDatasetPreview(id, 50);
      return { rows, total: ds.row_count, preview_limit: 50 };
    },
  },
  {
    // GET/PATCH/DELETE /datasets/:id
    pattern: /^\/datasets\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteMockDataset(id);
        return { ok: true };
      }
      if (method === "PATCH" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<Dataset>;
          return { dataset: updateMockDataset(id, body) };
        } catch {
          return { dataset: mockDatasetById(id) };
        }
      }
      const ds = mockDatasetById(id);
      return ds ? { dataset: ds } : { error: "not_found" };
    },
  },
  {
    // GET /datasets  |  POST /datasets
    pattern: /^\/datasets$/,
    handler: (_path, options, rawPath) => {
      const qs = (rawPath ?? "").split("?")[1] ?? "";
      const params = new URLSearchParams(qs);
      const wsId = params.get("workspace_id") ?? undefined;
      const sourceType = params.get("source_type") ?? undefined;
      const method = (options.method ?? "GET").toUpperCase();

      if (method === "POST" && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body ?? {}),
          ) as Partial<Dataset>;
          const newDs: Dataset = {
            id: `ds-new-${Date.now()}`,
            workspace_id: body.workspace_id ?? wsId ?? null,
            created_by_agent_id: null,
            name: body.name ?? "Untitled Dataset",
            slug: body.slug ?? `dataset-${Date.now()}`,
            description: body.description ?? null,
            source_type: body.source_type ?? "upload",
            format: body.format ?? "csv",
            schema_definition: body.schema_definition ?? null,
            row_count: body.row_count ?? 0,
            size_bytes: body.size_bytes ?? 0,
            status: body.status ?? "active",
            refresh_schedule: body.refresh_schedule ?? null,
            last_refreshed_at: null,
            tags: body.tags ?? [],
            access_agents: body.access_agents ?? [],
            inserted_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          };
          addMockDataset(newDs);
          return { dataset: newDs };
        } catch {
          return { error: "invalid_body" };
        }
      }

      const datasets = mockDatasets(wsId, sourceType);
      return { datasets, count: datasets.length };
    },
  },

  // ── Reports ───────────────────────────────────────────────────────────────────
  {
    // POST /reports/:id/generate
    pattern: /^\/reports\/([^/]+)\/generate$/,
    handler: (path) => {
      const id = path.split("/")[2];
      const report = generateMockReport(id);
      if (!report) return { error: "not_found" };
      return { report, generated: true };
    },
  },
  {
    // GET /reports/:id/export
    pattern: /^\/reports\/([^/]+)\/export$/,
    handler: (path, _options, rawPath) => {
      const id = path.split("/")[2];
      const report = mockReportById(id);
      if (!report) return { error: "not_found" };
      const format =
        new URL("http://x" + rawPath).searchParams.get("format") ?? "csv";
      const result = report.cached_result;
      if (format === "csv" && result) {
        const header = result.columns.join(",");
        const body = result.rows
          .map((row) =>
            row
              .map((v) => String(v))
              .map((v) =>
                v.includes(",") || v.includes('"')
                  ? `"${v.replace(/"/g, '""')}"`
                  : v,
              )
              .join(","),
          )
          .join("\n");
        return `${header}\n${body}\n`;
      }
      return { report, data: result, format };
    },
  },
  {
    // GET/PATCH/DELETE /reports/:id
    pattern: /^\/reports\/([^/]+)$/,
    handler: (path, options) => {
      const id = path.split("/")[2];
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "DELETE") {
        deleteMockReport(id);
        return undefined;
      }
      if ((method === "PATCH" || method === "PUT") && options.body) {
        try {
          const body = JSON.parse(
            typeof options.body === "string"
              ? options.body
              : JSON.stringify(options.body),
          ) as Partial<import("../types").Report>;
          const updated = updateMockReport(id, body);
          return updated ? { report: updated } : { error: "not_found" };
        } catch {
          const r = mockReportById(id);
          return r ? { report: r } : { error: "not_found" };
        }
      }
      const r = mockReportById(id);
      return r ? { report: r } : { error: "not_found" };
    },
  },
  {
    // GET /reports  |  POST /reports
    pattern: /^\/reports$/,
    handler: (_path, options, rawPath) => {
      const method = (options.method ?? "GET").toUpperCase();
      if (method === "POST") {
        let body: Record<string, unknown> = {};
        try {
          body = JSON.parse(options.body as string);
        } catch {
          /* ignore */
        }
        const now = new Date().toISOString();
        const newReport: import("../types").Report = {
          id: `rpt-${Date.now()}`,
          name: (body.name as string) ?? "New Report",
          description: (body.description as string) ?? null,
          report_type:
            (body.report_type as import("../types").ReportType) ??
            "agent_performance",
          config: (body.config as Record<string, unknown>) ?? {},
          schedule: (body.schedule as string) ?? null,
          last_generated_at: null,
          format: (body.format as import("../types").ReportFormat) ?? "table",
          status: "active",
          cached_result: null,
          tags: (body.tags as string[]) ?? [],
          workspace_id: null,
          created_by_id: null,
          inserted_at: now,
          updated_at: now,
        };
        addMockReport(newReport);
        return { report: newReport };
      }
      // GET with optional report_type filter
      const reportType = new URL("http://x" + rawPath).searchParams.get(
        "report_type",
      );
      const all = mockReports();
      const filtered = reportType
        ? all.filter((r) => r.report_type === reportType)
        : all;
      return { reports: filtered, count: filtered.length };
    },
  },

  // ── Analytics costs ───────────────────────────────────────────────────────────
  {
    pattern: /^\/analytics\/costs$/,
    handler: () => ({ daily: [], total_cents: 0 }),
  },

  // ── Config revisions CRUD ─────────────────────────────────────────────────────
  {
    pattern: /^\/config\/revisions$/,
    handler: (_path, options) => {
      if ((options.method ?? "GET").toUpperCase() === "POST") {
        return {
          id: `rev-${Date.now()}`,
          created_at: new Date().toISOString(),
        };
      }
      return { revisions: [] };
    },
  },
];

// ── Re-export workspace agent helpers for use by deploy service ────────────────
export {
  setMockWorkspaceAgents,
  getMockWorkspaceAgents,
  clearMockWorkspaceAgents,
  clearAllMockWorkspaceAgents,
};

// ── Mock-enabled guard ─────────────────────────────────────────────────────────
// handleRequest must only be called when useMock === true in client.ts.
// This flag mirrors that state so the mock module can reject accidental calls
// that slip through when the real backend is reachable.

let _mockAllowed = true;

/** Called by client.ts whenever it enables mock mode. */
export function notifyMockEnabled(): void {
  _mockAllowed = true;
}

/** Called by client.ts whenever it disables mock mode (backend is reachable). */
export function notifyMockDisabled(): void {
  _mockAllowed = false;
  // Purge all mock localStorage keys and flush the in-memory agent map so that
  // no stale mock data can rehydrate into live workspace views on the next
  // module load or page reload.
  clearAllMockData();
}

// ── Mock data purge ────────────────────────────────────────────────────────────
// All localStorage keys written exclusively by the mock layer. This list must
// stay in sync with any new keys added to mock sub-modules.
const MOCK_STORAGE_KEYS = [
  "canopy-workspace-agents", // mock/agents.ts — deployed template agents
  "canopy-active-workspace", // mock/index.ts — fresh-workspace detection
] as const;

/**
 * Remove every localStorage key that the mock layer writes and flush the
 * in-memory workspace-agents map.
 * Call this when transitioning from mock → real backend so that stale
 * in-browser mock data cannot bleed into live requests.
 */
export function clearAllMockData(): void {
  try {
    for (const key of MOCK_STORAGE_KEYS) {
      localStorage.removeItem(key);
    }
  } catch {
    // localStorage unavailable (SSR, sandboxed env) — nothing to do
  }
  // Flush the in-memory map so the cleared state takes effect immediately
  // without waiting for a module reload.
  clearAllMockWorkspaceAgents();
}

// ── Fresh workspace detection ─────────────────────────────────────────────────
// When a user-created workspace is active, operational endpoints return empty
// data instead of the default OSA demo data. This keeps new workspaces clean.

/** Returns the active workspace ID from localStorage, or null if none. */
function getActiveWorkspaceId(): string | null {
  try {
    return localStorage.getItem("canopy-active-workspace");
  } catch {
    return null;
  }
}

/** Returns true if a user-created workspace is active (not the initial empty state). */
function isFreshWorkspace(): boolean {
  return getActiveWorkspaceId() !== null;
}

/**
 * Empty responses for operational endpoints when a fresh workspace is active.
 * Routes NOT listed here (health, config, settings, workspaces, library,
 * templates, adapters, users, organizations) pass through to their normal
 * handlers since they are workspace-independent.
 */
const FRESH_WORKSPACE_OVERRIDES: Record<string, unknown> = {
  "/dashboard": {
    kpis: {
      active_agents: 0,
      total_agents: 0,
      live_runs: 0,
      open_issues: 0,
      budget_remaining_pct: 100,
    },
    live_runs: [],
    recent_activity: [],
    finance_summary: {
      today_cents: 0,
      week_cents: 0,
      month_cents: 0,
      daily_limit_cents: 2000,
      daily_used_cents: 0,
      cache_hit_rate: 0,
    },
    system_health: {
      status: "operational",
      uptime_seconds: 0,
      checks: [],
    },
  },
  "/activity": { events: [], total: 0 },
  "/issues": { issues: [] },
  "/inbox": { items: [], count: 0 },
  "/sessions": { sessions: [], count: 0 },
  "/schedules": { schedules: [] },
  "/costs/summary": {
    total_cents: 0,
    today_cents: 0,
    week_cents: 0,
    month_cents: 0,
    trend: [],
  },
  "/costs/by-agent": { agents: [] },
  "/costs/by-model": { models: [] },
  "/costs/daily": { points: [] },
  "/budgets": { policies: [] },
  "/budgets/incidents": { incidents: [] },
  "/sidebar-badges": {
    inbox_unread: 0,
    approvals_pending: 0,
    issues_open: 0,
    agents_error: 0,
    budget_warnings: 0,
  },
  "/goals": { goals: [], count: 0 },
  "/goals/tree": { tree: [] },
  "/projects": { projects: [], count: 0 },
  "/documents": { documents: [], count: 0 },
  "/documents/tree": { tree: [] },
  "/skills": { skills: [] },
  "/webhooks": { webhooks: [] },
  "/alerts/rules": { rules: [] },
  "/alerts": { rules: [] },
  "/signals/feed": { signals: [] },
  "/signals": { signals: [] },
  "/approvals": { approvals: [] },
  "/secrets": { secrets: [] },
  "/labels": { labels: [] },
  "/plugins": { plugins: [] },
  "/memory": { entries: [], count: 0 },
  "/memory/namespaces": { namespaces: [] },
  "/audit": { entries: [] },
  "/logs": { entries: [] },
  "/spawn/active": { instances: [], count: 0 },
  "/spawn": { instances: [], count: 0 },
  "/analytics/summary": {
    period: "30d",
    agent_metrics: [],
    team_metrics: [],
    totals: {
      total_sessions: 0,
      total_cost_cents: 0,
      avg_success_rate: 0,
      total_tasks: 0,
      active_agents: 0,
    },
    trends: { sessions_by_day: [], costs_by_day: [] },
  },
  "/analytics/agents": { agents: [] },
  "/analytics/teams": { teams: [] },
  "/work-products": { products: [], count: 0 },
  "/conversations": { conversations: [], total: 0 },
  "/hierarchy": {
    organization: {
      id: "org-1",
      name: "Default Organization",
      divisions: [],
    },
  },
  "/divisions": { divisions: [] },
  "/departments": { departments: [] },
  "/teams": { teams: [] },
  "/invitations": { invitations: [] },
  "/config/revisions": { revisions: [] },
  "/execution-workspaces": { workspaces: [] },
  "/costs/events": { events: [], total: 0 },
  "/document-revisions": { revisions: [] },
  "/spawn/history": { runs: [] },
  "/schedules/queue": { queue: [] },
  "/alerts/history": { events: [] },
  "/adapters": [
    {
      id: "osa",
      name: "OSA",
      description: "Optimal System Agent",
      status: "available",
    },
    {
      id: "claude_code",
      name: "Claude Code",
      description: "Anthropic Claude Code CLI",
      status: "available",
    },
    {
      id: "claude-code",
      name: "Claude Code (Hyphenated)",
      description: "Alias for claude_code",
      status: "available",
    },
    {
      id: "codex",
      name: "Codex",
      description: "OpenAI Codex agent",
      status: "available",
    },
    {
      id: "openclaw",
      name: "OpenClaw",
      description: "OpenClaw agent framework",
      status: "available",
    },
    {
      id: "jidoclaw",
      name: "JidoClaw",
      description: "JidoClaw agent framework",
      status: "available",
    },
    {
      id: "hermes",
      name: "Hermes",
      description: "Hermes messaging agent",
      status: "available",
    },
    {
      id: "bash",
      name: "Bash",
      description: "Shell script agent",
      status: "available",
    },
    {
      id: "http",
      name: "HTTP",
      description: "HTTP API agent",
      status: "available",
    },
    {
      id: "cursor",
      name: "Cursor",
      description: "Cursor IDE agent",
      status: "available",
    },
    {
      id: "gemini",
      name: "Gemini",
      description: "Google Gemini agent",
      status: "available",
    },
    {
      id: "custom",
      name: "Custom",
      description: "Custom adapter",
      status: "available",
    },
  ],
  "/notifications": { notifications: [], total: 0 },
  "/notifications/badges": { unread: 0, by_category: {}, by_severity: {} },
  "/datasets": { datasets: [], total: 0 },
};

// ── Request handler ────────────────────────────────────────────────────────────

export async function handleRequest<T>(
  path: string,
  _options: RequestInit,
): Promise<T> {
  // Defence-in-depth: refuse to serve mock data when the backend is reachable.
  // client.ts controls _mockAllowed via notifyMockEnabled/notifyMockDisabled.
  if (!_mockAllowed) {
    throw new Error(
      `[mock] handleRequest invoked while mock mode is disabled (path: ${path}). ` +
        "This is a bug — useMock must be true before calling handleRequest.",
    );
  }

  await delay();

  // Strip query params for matching
  const cleanPath = path.split("?")[0];

  // Fresh workspace override: return empty data for operational GET endpoints.
  // Write methods (POST/PATCH/PUT/DELETE) always fall through to route handlers
  // so that create/update/delete operations work in fresh workspaces.
  const method = (_options.method ?? "GET").toUpperCase();
  if (isFreshWorkspace() && method === "GET") {
    const override = FRESH_WORKSPACE_OVERRIDES[cleanPath];
    if (override !== undefined) {
      return override as T;
    }
  }

  for (const route of routes) {
    if (route.pattern.test(cleanPath)) {
      return route.handler(cleanPath, _options, path) as T;
    }
  }

  // Default: return empty object
  console.warn(`[mock] No handler for ${path}, returning empty`);
  return {} as T;
}
