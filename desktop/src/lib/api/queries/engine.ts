import { apiGet, apiPost } from "$lib/api/client.js";
import type {
  WorkspaceEngineCommandsResponse,
  WorkspaceEngineHealth,
  WorkspaceEngineRunBody,
  WorkspaceEngineRunResult,
} from "$lib/domain/engine/types.js";

export function getWorkspaceEngineHealth(
  slug: string,
): Promise<WorkspaceEngineHealth> {
  return apiGet<WorkspaceEngineHealth>(`/workspaces/${slug}/engine/health`);
}

export function listWorkspaceEngineCommands(
  slug: string,
): Promise<WorkspaceEngineCommandsResponse> {
  return apiGet<WorkspaceEngineCommandsResponse>(
    `/workspaces/${slug}/engine/commands`,
  );
}

export function runWorkspaceEngineCommand(
  slug: string,
  body: WorkspaceEngineRunBody,
): Promise<WorkspaceEngineRunResult> {
  return apiPost<WorkspaceEngineRunResult>(
    `/workspaces/${slug}/engine/run`,
    body,
  );
}

export function workspaceEngineHealthQuery(slug: string) {
  return {
    queryKey: ["workspaces", slug, "engine", "health"] as const,
    queryFn: () => getWorkspaceEngineHealth(slug),
    staleTime: 10_000,
    enabled: Boolean(slug),
  };
}

export function workspaceEngineCommandsQuery(slug: string) {
  return {
    queryKey: ["workspaces", slug, "engine", "commands"] as const,
    queryFn: () => listWorkspaceEngineCommands(slug),
    staleTime: 10_000,
    enabled: Boolean(slug),
    retry: false,
  };
}

export function runWorkspaceEngineCommandMutation(slug: string) {
  return {
    mutationKey: ["workspaces", slug, "engine", "run"] as const,
    mutationFn: (body: WorkspaceEngineRunBody) =>
      runWorkspaceEngineCommand(slug, body),
  };
}
