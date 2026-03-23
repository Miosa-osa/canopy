import type { Goal, GoalTreeNode } from "../types";

let mockGoals: Goal[] = [
  {
    id: "goal-q1-milestone",
    title: "Q1 Milestone",
    description:
      "Complete the first quarter milestone with core features shipped and tested.",
    parent_id: null,
    project_id: "proj-alpha",
    status: "active",
    priority: "high",
    progress: 40,
    assignee_id: null,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "goal-integration",
    title: "Integration Layer",
    description:
      "Build the pluggable integration layer supporting all target adapters.",
    parent_id: "goal-q1-milestone",
    project_id: "proj-alpha",
    status: "active",
    priority: "high",
    progress: 20,
    assignee_id: null,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "goal-infra",
    title: "Infrastructure Setup",
    description: "Automated build, test, and deployment pipeline.",
    parent_id: null,
    project_id: "proj-beta",
    status: "active",
    priority: "medium",
    progress: 10,
    assignee_id: null,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "goal-security",
    title: "Security Hardening",
    description:
      "OWASP Top 10 review, authentication hardening, and isolation validation.",
    parent_id: null,
    project_id: "proj-beta",
    status: "active",
    priority: "high",
    progress: 5,
    assignee_id: null,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: "2026-03-01T00:00:00Z",
  },
];

const ISSUE_COUNTS: Record<string, number> = {
  "goal-q1-milestone": 4,
  "goal-integration": 2,
  "goal-infra": 1,
  "goal-security": 1,
};

function buildTree(goals: Goal[], parentId: string | null): GoalTreeNode[] {
  return goals
    .filter((g) => g.parent_id === parentId)
    .map((g) => ({
      ...g,
      children: buildTree(goals, g.id),
      issue_count: ISSUE_COUNTS[g.id] ?? 0,
    }));
}

export function getGoals(): Goal[] {
  return mockGoals;
}

export function getGoalsByProject(projectId: string): Goal[] {
  return mockGoals.filter((g) => g.project_id === projectId);
}

export function getGoalTree(projectId?: string): GoalTreeNode[] {
  const goals = projectId ? getGoalsByProject(projectId) : mockGoals;
  return buildTree(goals, null);
}

export function getGoalById(id: string): GoalTreeNode | undefined {
  const goal = mockGoals.find((g) => g.id === id);
  if (!goal) return undefined;
  return {
    ...goal,
    children: buildTree(mockGoals, goal.id),
    issue_count: ISSUE_COUNTS[goal.id] ?? 0,
  };
}

export function addGoal(goal: Goal): void {
  mockGoals = [goal, ...mockGoals];
}

export function updateGoal(id: string, data: Partial<Goal>): Goal | undefined {
  const idx = mockGoals.findIndex((g) => g.id === id);
  if (idx === -1) return undefined;
  mockGoals[idx] = {
    ...mockGoals[idx],
    ...data,
    updated_at: new Date().toISOString(),
  };
  return mockGoals[idx];
}

export function deleteGoal(id: string): boolean {
  const len = mockGoals.length;
  mockGoals = mockGoals.filter((g) => g.id !== id);
  return mockGoals.length < len;
}
