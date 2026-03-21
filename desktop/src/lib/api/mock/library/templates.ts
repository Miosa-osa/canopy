// Template data (teams) — 4 templates

import type { LibraryTemplate } from "./types";
import type { RawTemplate } from "./enrichment";
import { enrichTemplate } from "./enrichment";

const RAW_TEMPLATES: RawTemplate[] = [
  {
    id: "growth-os",
    name: "Growth OS",
    emoji: "🚀",
    description:
      "Creator business growth operating system — 36 agents across 6 modes covering research, content, outreach, sales, and analytics.",
    size: "enterprise",
    agent_count: 36,
  },
  {
    id: "micro",
    name: "Micro Agent",
    emoji: "⚡",
    description: "Single-purpose agent for focused tasks",
    size: "micro",
    agent_count: 1,
  },
  {
    id: "small",
    name: "Small Team",
    emoji: "👥",
    description: "Focused team with specialized roles",
    size: "small",
    agent_count: 3,
  },
  {
    id: "full",
    name: "Full Operation",
    emoji: "🏢",
    description: "Complete department with workflows and governance",
    size: "full",
    agent_count: 6,
  },
  {
    id: "enterprise",
    name: "Enterprise",
    emoji: "🌐",
    description: "Multi-team organization with compliance and budgets",
    size: "enterprise",
    agent_count: 15,
  },
];

export const TEMPLATES: LibraryTemplate[] = RAW_TEMPLATES.map(enrichTemplate);
