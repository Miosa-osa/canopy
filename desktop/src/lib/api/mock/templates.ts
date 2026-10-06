// src/lib/api/mock/templates.ts
// Mock AgentTemplate records served by the /templates endpoint.
//
// IMPORTANT: each `id` here MUST match a bundled module at:
//   src/lib/api/mock/library/templates/{id}.ts
//
// The deploy service calls loadBundledTemplate(id) — if the id does not match
// a file, the deploy silently creates an empty workspace. Keep this list in
// sync with the files in the templates/ directory.

import type { AgentTemplate } from "../types";

const MOCK_TEMPLATES: AgentTemplate[] = [
  {
    id: "micro",
    name: "Micro Agent",
    description:
      "Single-purpose agent for focused tasks. Minimal footprint, maximum precision.",
    adapter: "claude_code",
    model: "claude-sonnet-4-20250514",
    system_prompt: "",
    skills: [],
    config: {},
    category: "starter",
    downloads: 0,
    created_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "small",
    name: "Small Team",
    description:
      "Focused team of 3 agents with specialized roles: team lead, specialist, and executor.",
    adapter: "claude_code",
    model: "claude-sonnet-4-20250514",
    system_prompt: "",
    skills: ["analysis", "research", "execution"],
    config: {},
    category: "team",
    downloads: 0,
    created_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "full",
    name: "Full Operation",
    description:
      "Complete department with 6 agents: director, operations manager, analyst, researcher, writer, and reviewer.",
    adapter: "claude_code",
    model: "claude-sonnet-4-20250514",
    system_prompt: "",
    skills: ["planning", "analysis", "research", "writing", "review"],
    config: {},
    category: "department",
    downloads: 0,
    created_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "enterprise",
    name: "Enterprise",
    description:
      "Multi-team organisation with 15 agents across C-suite, engineering, product, marketing, and compliance.",
    adapter: "osa",
    model: "claude-opus-4-20250514",
    system_prompt: "",
    skills: [
      "strategy",
      "governance",
      "code-generation",
      "analysis",
      "marketing",
      "compliance",
    ],
    config: {},
    category: "enterprise",
    downloads: 0,
    created_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "growth-os",
    name: "Growth OS",
    description:
      "Creator business growth operating system — 36 agents across 6 modes covering research, content, outreach, sales, and analytics.",
    adapter: "osa",
    model: "claude-opus-4-20250514",
    system_prompt: "",
    skills: ["research", "content", "outreach", "sales", "analytics", "seo"],
    config: {},
    category: "growth",
    downloads: 0,
    created_at: "2026-03-01T00:00:00Z",
  },
  {
    id: "growth-operator-agency",
    name: "Growth Operator Agency",
    description:
      "Full creator-business growth workspace with 41 agents, 39 skills, company context, workflows, reference packs, and runtime shims.",
    adapter: "osa",
    model: "claude-opus-4-20250514",
    system_prompt: "",
    skills: [
      "research",
      "build-icp",
      "design-offer",
      "build-vsl",
      "build-funnel",
      "plan-launch",
      "revenue-report",
    ],
    config: {
      source: "templates/growth-operator-agency",
      agents: 41,
      skills: 39,
      workspace_pack: true,
    },
    category: "growth",
    downloads: 0,
    created_at: "2026-05-01T00:00:00Z",
  },
];

export function mockTemplates(): AgentTemplate[] {
  return MOCK_TEMPLATES;
}
