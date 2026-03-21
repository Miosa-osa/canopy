import type { Goal, GoalTreeNode } from "../types";

const MOCK_GOALS: Goal[] = [
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
  return MOCK_GOALS;
}

export function getGoalTree(): GoalTreeNode[] {
  return buildTree(MOCK_GOALS, null);
}

export function getGoalById(id: string): GoalTreeNode | undefined {
  const goal = MOCK_GOALS.find((g) => g.id === id);
  if (!goal) return undefined;
  return {
    ...goal,
    children: buildTree(MOCK_GOALS, goal.id),
    issue_count: ISSUE_COUNTS[goal.id] ?? 0,
  };
}
