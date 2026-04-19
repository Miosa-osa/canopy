/**
 * Sidebar config store — Svelte 5 runes, localStorage-persisted.
 * Key: canopy.sidebar.config
 * Shape: { groups: [{ label, items: [{ path, label, icon, badge?, badgeStyle?, comingSoon?, hidden }] }] }
 * LOC target: ≤ 120.
 */

export interface SidebarItemConfig {
  path: string;
  label: string;
  icon: string; // lucide icon name — looked up in Sidebar.svelte's local map
  badge?: number;
  badgeStyle?: "count" | "warn";
  comingSoon?: boolean;
  hidden: boolean;
}

export interface SidebarGroupConfig {
  label: string;
  items: SidebarItemConfig[];
}

export interface SidebarConfig {
  groups: SidebarGroupConfig[];
}

const LS_KEY = "canopy.sidebar.config";

// Verbatim copy of the 3-group layout from Sidebar.svelte — single source of truth.
export const defaultConfig: SidebarConfig = {
  groups: [
    {
      label: "COCKPIT",
      items: [
        {
          path: "/runtimes",
          label: "Runtimes",
          icon: "Monitor",
          hidden: false,
        },
        {
          path: "/sessions",
          label: "Sessions",
          icon: "History",
          hidden: false,
        },
        { path: "/agents", label: "Agents", icon: "Bot", hidden: false },
        {
          path: "/workspaces",
          label: "Workspaces",
          icon: "Briefcase",
          hidden: false,
        },
        { path: "/sandboxes", label: "Sandboxes", icon: "Box", hidden: false },
        {
          path: "/dashboard",
          label: "Command Center",
          icon: "Terminal",
          hidden: false,
        },
      ],
    },
    {
      label: "WORKSPACE",
      items: [
        {
          path: "/coming-soon",
          label: "Inbox",
          icon: "Inbox",
          badge: 7,
          comingSoon: true,
          hidden: false,
        },
        {
          path: "/coming-soon",
          label: "Schedule",
          icon: "Calendar",
          comingSoon: true,
          hidden: false,
        },
        { path: "/chat", label: "Chat", icon: "MessageCircle", hidden: false },
        { path: "/channels", label: "Channels", icon: "Hash", hidden: false },
        { path: "/files", label: "Files", icon: "FolderOpen", hidden: false },
        { path: "/docs", label: "Docs", icon: "FileText", hidden: false },
        { path: "/tasks", label: "Tasks", icon: "CheckSquare", hidden: false },
      ],
    },
    {
      label: "SYSTEM",
      items: [
        {
          path: "/coming-soon",
          label: "Skills",
          icon: "Zap",
          comingSoon: true,
          hidden: false,
        },
        {
          path: "/coming-soon",
          label: "Templates",
          icon: "LayoutTemplate",
          comingSoon: true,
          hidden: false,
        },
        {
          path: "/coming-soon",
          label: "Analytics",
          icon: "BarChart2",
          comingSoon: true,
          hidden: false,
        },
        {
          path: "/coming-soon",
          label: "Governance",
          icon: "ShieldCheck",
          badge: 1,
          badgeStyle: "warn",
          comingSoon: true,
          hidden: false,
        },
      ],
    },
  ],
};

// ── Merge helpers ─────────────────────────────────────────────────────────────

/** Build a set of "groupLabel:path:label" keys present in defaultConfig. */
function defaultKeys(cfg: SidebarConfig): Set<string> {
  const keys = new Set<string>();
  for (const g of cfg.groups) {
    for (const item of g.items) {
      keys.add(`${g.label}:${item.path}:${item.label}`);
    }
  }
  return keys;
}

/**
 * Merge saved config with defaultConfig:
 * - Drop saved items whose key is no longer in defaultConfig (stale modules).
 * - Append new defaultConfig items that aren't in the saved config.
 * - Preserve saved order and hidden flags for surviving items.
 */
function mergeWithDefault(saved: SidebarConfig): SidebarConfig {
  const valid = defaultKeys(defaultConfig);

  return {
    groups: defaultConfig.groups.map((defaultGroup) => {
      const savedGroup = saved.groups.find(
        (g) => g.label === defaultGroup.label,
      );

      // Items from saved that still exist in defaultConfig (preserves order + hidden).
      const survivingItems: SidebarItemConfig[] = savedGroup
        ? savedGroup.items.filter((i) =>
            valid.has(`${defaultGroup.label}:${i.path}:${i.label}`),
          )
        : [];

      // Keys already represented in surviving items.
      const survivingKeys = new Set(
        survivingItems.map((i) => `${i.path}:${i.label}`),
      );

      // New items from defaultConfig not present in the saved group.
      const newItems = defaultGroup.items.filter(
        (i) => !survivingKeys.has(`${i.path}:${i.label}`),
      );

      return {
        label: defaultGroup.label,
        items: [...survivingItems, ...newItems],
      };
    }),
  };
}

// ── Store ─────────────────────────────────────────────────────────────────────

class SidebarConfigStore {
  config = $state<SidebarConfig>(structuredClone(defaultConfig));

  constructor() {
    if (typeof localStorage !== "undefined") {
      this.config = loadConfig();
    }
  }

  save(): void {
    saveConfig(this.config);
  }

  reset(): void {
    this.config = structuredClone(defaultConfig);
    saveConfig(this.config);
  }

  moveItemUp(groupLabel: string, itemPath: string, itemLabel: string): void {
    const group = this.config.groups.find((g) => g.label === groupLabel);
    if (!group) return;
    const idx = group.items.findIndex(
      (i) => i.path === itemPath && i.label === itemLabel,
    );
    if (idx <= 0) return;
    const items = [...group.items];
    [items[idx - 1], items[idx]] = [items[idx], items[idx - 1]];
    group.items = items;
    this.save();
  }

  moveItemDown(groupLabel: string, itemPath: string, itemLabel: string): void {
    const group = this.config.groups.find((g) => g.label === groupLabel);
    if (!group) return;
    const idx = group.items.findIndex(
      (i) => i.path === itemPath && i.label === itemLabel,
    );
    if (idx < 0 || idx >= group.items.length - 1) return;
    const items = [...group.items];
    [items[idx], items[idx + 1]] = [items[idx + 1], items[idx]];
    group.items = items;
    this.save();
  }

  toggleHidden(groupLabel: string, itemPath: string, itemLabel: string): void {
    const group = this.config.groups.find((g) => g.label === groupLabel);
    if (!group) return;
    const item = group.items.find(
      (i) => i.path === itemPath && i.label === itemLabel,
    );
    if (!item) return;
    item.hidden = !item.hidden;
    this.save();
  }
}

// ── Pure helpers (exported for tests) ────────────────────────────────────────

export function loadConfig(): SidebarConfig {
  try {
    const raw = localStorage.getItem(LS_KEY);
    if (!raw) return structuredClone(defaultConfig);
    const parsed = JSON.parse(raw) as SidebarConfig;
    return mergeWithDefault(parsed);
  } catch {
    return structuredClone(defaultConfig);
  }
}

export function saveConfig(cfg: SidebarConfig): void {
  try {
    localStorage.setItem(LS_KEY, JSON.stringify(cfg));
  } catch {
    // Quota exceeded or private-browsing — silently ignore.
  }
}

export function resetConfig(): void {
  try {
    localStorage.removeItem(LS_KEY);
  } catch {
    // ignore
  }
}

export const sidebarConfig = new SidebarConfigStore();
