import type { Project } from "../types";

let mockProjects: Project[] = [
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
  return mockProjects;
}

export function getProjectById(id: string): Project | undefined {
  return mockProjects.find((p) => p.id === id);
}

export function addProject(project: Project): void {
  mockProjects = [project, ...mockProjects];
}

export function updateProject(
  id: string,
  data: Partial<Project>,
): Project | undefined {
  const idx = mockProjects.findIndex((p) => p.id === id);
  if (idx === -1) return undefined;
  mockProjects[idx] = {
    ...mockProjects[idx],
    ...data,
    updated_at: new Date().toISOString(),
  };
  return mockProjects[idx];
}

export function deleteProject(id: string): boolean {
  const len = mockProjects.length;
  mockProjects = mockProjects.filter((p) => p.id !== id);
  return mockProjects.length < len;
}
