/**
 * TanStack Query factories for the /projects resource.
 * Each factory returns a query/mutation options object — pass directly to
 * createQuery() / createMutation() in component scripts.
 */

import { apiDelete, apiGet, apiPatch, apiPost } from "$lib/api/client.js";
import type {
  CreateProjectBody,
  Project,
  ProjectFilters,
  ProjectSummary,
  UpdateProjectBody,
} from "$lib/domain/projects/types.js";

// ── Raw API calls ────────────────────────────────────────────────────────────

export function listProjects(filters?: ProjectFilters): Promise<Project[]> {
  const params = new URLSearchParams();
  if (filters?.workspaceSlug)
    params.set("workspace_slug", filters.workspaceSlug);
  if (filters?.status) params.set("status", filters.status);
  if (filters?.limit) params.set("limit", String(filters.limit));
  const qs = params.toString();
  return apiGet<Project[]>(`/projects${qs ? `?${qs}` : ""}`);
}

export function getProject(slug: string): Promise<Project> {
  return apiGet<Project>(`/projects/${slug}`);
}

export function getProjectSummary(slug: string): Promise<ProjectSummary> {
  return apiGet<ProjectSummary>(`/projects/${slug}/summary`);
}

export function createProject(body: CreateProjectBody): Promise<Project> {
  return apiPost<Project>("/projects", body);
}

export function updateProject(
  slug: string,
  body: UpdateProjectBody,
): Promise<Project> {
  return apiPatch<Project>(`/projects/${slug}`, body);
}

export function archiveProject(slug: string): Promise<Project> {
  return apiPost<Project>(`/projects/${slug}/archive`, {});
}

export function unarchiveProject(slug: string): Promise<Project> {
  return apiPost<Project>(`/projects/${slug}/unarchive`, {});
}

export function deleteProject(slug: string): Promise<void> {
  return apiDelete<void>(`/projects/${slug}`);
}

// ── TanStack Query option factories ─────────────────────────────────────────

export function projectsQuery(filters?: ProjectFilters) {
  return {
    queryKey: ["projects", filters ?? {}] as const,
    queryFn: () => listProjects(filters),
    staleTime: 15_000,
    retry: false,
  };
}

export function projectQuery(slug: string) {
  return {
    queryKey: ["projects", slug] as const,
    queryFn: () => getProject(slug),
    staleTime: 10_000,
    enabled: Boolean(slug),
    retry: false,
  };
}

export function projectSummaryQuery(slug: string) {
  return {
    queryKey: ["projects", slug, "summary"] as const,
    queryFn: () => getProjectSummary(slug),
    staleTime: 30_000,
    enabled: Boolean(slug),
    retry: false,
  };
}

export function createProjectMutation() {
  return {
    mutationKey: ["projects", "create"] as const,
    mutationFn: (body: CreateProjectBody) => createProject(body),
  };
}

export function updateProjectMutation() {
  return {
    mutationKey: ["projects", "update"] as const,
    mutationFn: ({ slug, body }: { slug: string; body: UpdateProjectBody }) =>
      updateProject(slug, body),
  };
}

export function archiveProjectMutation() {
  return {
    mutationKey: ["projects", "archive"] as const,
    mutationFn: (slug: string) => archiveProject(slug),
  };
}

export function deleteProjectMutation() {
  return {
    mutationKey: ["projects", "delete"] as const,
    mutationFn: (slug: string) => deleteProject(slug),
  };
}
