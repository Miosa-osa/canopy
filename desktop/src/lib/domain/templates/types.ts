/**
 * Templates domain types — match Elixir backend structs at /api/v1/templates/*.
 * Keys arrive camelCased via the client conversion layer.
 */

export type TemplateKind = 'workspace' | 'persona' | 'workflow';

export type TemplateSource = 'local' | 'git' | 'imported' | 'user';

export type InstantiationStatus = 'pending' | 'success' | 'partial' | 'failed';

export interface Template {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  kind: TemplateKind;
  body: Record<string, unknown>;
  parameters: Record<string, TemplateParameter>;
  version: string;
  parentTemplateId: string | null;
  forkedFromSlug: string | null;
  verified: boolean;
  verifiedBy: string | null;
  verifiedAt: string | null;
  published: boolean;
  source: TemplateSource;
  sourceUrl: string | null;
  tags: string[];
  icon: string | null;
  popularityCount: number;
  createdByAgentId: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface TemplateParameter {
  type?: 'string' | 'integer' | 'boolean' | 'list';
  required?: boolean;
  default?: unknown;
  description?: string;
  enum?: unknown[];
}

export interface TemplateCreate {
  slug: string;
  name: string;
  kind: TemplateKind;
  description?: string;
  body?: Record<string, unknown>;
  parameters?: Record<string, TemplateParameter>;
  version?: string;
  tags?: string[];
  icon?: string;
  source?: TemplateSource;
  sourceUrl?: string;
}

export interface PreviewRequest {
  params?: Record<string, unknown>;
}

export interface PreviewResponse {
  slug: string;
  kind: TemplateKind;
  version: string;
  body: Record<string, unknown>;
  resolvedParams: Record<string, unknown>;
  parameterSchema: Record<string, TemplateParameter>;
}

export interface InstantiateRequest {
  targetWorkspaceSlug?: string;
  targetPath?: string;
  params?: Record<string, unknown>;
  instantiatedBy?: string;
  instantiatedByAgentId?: string;
}

export interface Instantiation {
  id: string;
  templateId: string | null;
  templateSlug: string;
  templateVersion: string;
  targetWorkspaceSlug: string | null;
  targetPath: string | null;
  params: Record<string, unknown>;
  filesWritten: number;
  agentsCreated: number;
  skillsInstalled: number;
  status: InstantiationStatus;
  error: string | null;
  instantiatedByAgentId: string | null;
  instantiatedBy: string | null;
  insertedAt: string;
  updatedAt: string;
}

export interface PublishRequest {
  version?: string;
  changelog?: string;
  authoredBy?: string;
}

export interface TemplateVersion {
  id: string;
  templateId: string;
  version: string;
  diff: Record<string, unknown>;
  bodySnapshot: Record<string, unknown>;
  parametersSnapshot: Record<string, unknown>;
  changelog: string | null;
  sha256: string | null;
  authoredBy: string | null;
  insertedAt: string;
}

export interface PublishResponse {
  template: Template;
  version: TemplateVersion;
}

export interface ForkRequest {
  newSlug: string;
  newName: string;
}

export interface MissingParamsError {
  error: 'missing_parameters';
  missing: string[];
}
