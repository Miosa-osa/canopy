import type { Project } from "../types";

const MOCK_PROJECTS: Project[] = [
  {
    id: "proj-alpha",
    name: "Alpha Project",
    description:
      "Primary project workspace. Manage agents, goals, and issues from here.",
    status: "active",
    workspace_path: "~/.canopy/projects/alpha",
    goal_count: 5,
    issue_count: 8,
    agent_count: 7,
    created_at: "2026-01-15T00:00:00Z",
    updated_at: "2026-03-21T08:00:00Z",
  },
  {
    id: "proj-beta",
    name: "Beta Project",
    description: "Secondary project workspace for parallel workstreams.",
    status: "active",
    workspace_path: "~/.canopy/projects/beta",
    goal_count: 4,
    issue_count: 6,
    agent_count: 4,
    created_at: "2026-03-01T00:00:00Z",
    updated_at: "2026-03-21T07:30:00Z",
  },
];

export function getProjects(): Project[] {
  return MOCK_PROJECTS;
}

export function getProjectById(id: string): Project | undefined {
  return MOCK_PROJECTS.find((p) => p.id === id);
}
