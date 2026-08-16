export interface WorkspaceEngineHealth {
  workspaceSlug: string;
  rootPath: string;
  enginePath: string;
  engineExists: boolean;
  mixProject: boolean;
  manifestPath: string;
  manifestExists: boolean;
  commandsCount: number;
  available: boolean;
}

export interface WorkspaceEngineCommand {
  name: string;
  task: string;
  description: string | null;
  args: string[];
}

export interface WorkspaceEngineCommandsResponse {
  commands: WorkspaceEngineCommand[];
  count: number;
}

export interface WorkspaceEngineRunBody {
  command: string;
  args?: string[];
  timeoutMs?: number;
}

export interface WorkspaceEngineRunResult {
  workspaceSlug: string;
  command: string;
  task: string;
  args: string[];
  cwd: string;
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}
