// src/lib/api/mock/library/template-registry.ts
// Registry mapping template IDs to filesystem paths and metadata.
// Add new templates here as they are created.

export interface TemplateManifest {
  /** Unique identifier, matches the directory name under templates/ */
  id: string;
  name: string;
  emoji: string;
  description: string;
  category: string;
  /** Path relative to the canopy-main repository root */
  basePath: string;
  agentCount: number;
  skillCount: number;
}

export const TEMPLATE_REGISTRY: TemplateManifest[] = [
  {
    id: "growth-os",
    name: "Growth OS",
    emoji: "🚀",
    description:
      "Creator business growth operating system — 36 agents across 6 modes.",
    category: "growth",
    basePath: "templates/growth-os",
    agentCount: 36,
    skillCount: 42,
  },
  {
    id: "growth-operator-agency",
    name: "Growth Operator Agency",
    emoji: "📈",
    description:
      "Full creator-business growth workspace with 41 agents, 39 skills, company context, workflows, reference packs, and runtime shims.",
    category: "growth",
    basePath: "templates/growth-operator-agency",
    agentCount: 41,
    skillCount: 39,
  },
];

/** Look up a template manifest by ID. Returns undefined if not found. */
export function getTemplateManifest(id: string): TemplateManifest | undefined {
  return TEMPLATE_REGISTRY.find((t) => t.id === id);
}
