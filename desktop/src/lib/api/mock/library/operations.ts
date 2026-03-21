// Operation data (companies) — 4 operations

import type { LibraryOperation } from "./types";
import type { RawOperation } from "./enrichment";
import { enrichOperation } from "./enrichment";

const RAW_OPERATIONS: RawOperation[] = [
  {
    id: "growth-os",
    name: "Growth OS",
    emoji: "🚀",
    description:
      "Creator business growth operating system — 36 agents across 6 modes covering research, content, outreach, sales, and analytics.",
    agent_count: 36,
    skill_count: 42,
    category: "growth",
  },
  {
    id: "sales-engine",
    name: "Sales Engine",
    emoji: "💼",
    description:
      "B2B SaaS sales operation — full-cycle pipeline from prospect to closed-won.",
    agent_count: 5,
    skill_count: 5,
    category: "sales",
  },
  {
    id: "dev-shop",
    name: "Dev Shop",
    emoji: "🏗",
    description:
      "Software development operation — spec to production with quality-first engineering.",
    agent_count: 6,
    skill_count: 6,
    category: "engineering",
  },
  {
    id: "content-factory",
    name: "Content Factory",
    emoji: "✍️",
    description:
      "Content production operation — ideation to published, optimized, multi-platform content.",
    agent_count: 5,
    skill_count: 5,
    category: "marketing",
  },
  {
    id: "cognitive-os",
    name: "Cognitive OS",
    emoji: "🧠",
    description:
      "Personal knowledge management system — capture, organize, retrieve, and synthesize information.",
    agent_count: 4,
    skill_count: 14,
    category: "productivity",
  },
];

export const OPERATIONS: LibraryOperation[] =
  RAW_OPERATIONS.map(enrichOperation);
