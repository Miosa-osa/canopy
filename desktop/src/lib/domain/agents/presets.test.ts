/**
 * Tests for AGENT_PRESETS — verifies each preset has the required shape
 * and that prompts are substantive enough to be useful.
 */
import { describe, expect, it } from "vitest";
import { AGENT_PRESETS, type AgentPreset } from "./presets.js";

describe("AGENT_PRESETS", () => {
  it("exports exactly 7 presets", () => {
    expect(AGENT_PRESETS).toHaveLength(7);
  });

  it("every preset has a non-empty label", () => {
    for (const preset of AGENT_PRESETS) {
      expect(preset.label.trim().length, `preset label empty`).toBeGreaterThan(
        0,
      );
    }
  });

  it("every preset has a valid AgentCategory", () => {
    const validCategories = new Set([
      "academic",
      "creative-content",
      "design",
      "engineering",
      "executive",
      "game-development",
      "growth",
      "marketing",
      "operations",
      "paid-media",
      "product",
      "project-management",
      "revenue",
      "sales",
      "spatial-computing",
      "specialized",
      "support",
      "technology",
      "testing",
    ]);

    for (const preset of AGENT_PRESETS) {
      expect(
        validCategories.has(preset.category),
        `"${preset.label}" has invalid category "${preset.category}"`,
      ).toBe(true);
    }
  });

  it("every preset has a systemPrompt of at least 80 characters", () => {
    for (const preset of AGENT_PRESETS) {
      expect(
        preset.systemPrompt.trim().length,
        `preset "${preset.label}" systemPrompt too short`,
      ).toBeGreaterThanOrEqual(80);
    }
  });

  it("all preset labels are unique", () => {
    const labels = AGENT_PRESETS.map((p) => p.label);
    const unique = new Set(labels);
    expect(unique.size).toBe(labels.length);
  });

  it("has a Support Agent preset pointing to the support category", () => {
    const found = AGENT_PRESETS.find((p) => p.label === "Support Agent");
    expect(found).toBeDefined();
    expect((found as AgentPreset).category).toBe("support");
  });

  it("has a Product Manager preset pointing to the product category", () => {
    const found = AGENT_PRESETS.find((p) => p.label === "Product Manager");
    expect(found).toBeDefined();
    expect((found as AgentPreset).category).toBe("product");
  });
});
