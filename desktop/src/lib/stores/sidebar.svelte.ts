import { browser } from "$app/environment";

export type SidebarModuleId =
  | "dashboard"
  | "inbox"
  | "office"
  | "workbench"
  | "execution"
  | "terminal"
  | "chat"
  | "sessions"
  | "rhythm"
  | "signals"
  | "nodes"
  | "library"
  | "templates"
  | "skills"
  | "projects"
  | "team"
  | "agents"
  | "automation"
  | "schedules"
  | "integrations"
  | "activity"
  | "system";

export interface SidebarModuleOption {
  id: SidebarModuleId;
  label: string;
  group: "Core" | "Execution" | "Reference" | "People" | "Automation" | "System";
}

const STORAGE_KEY = "canopy-sidebar-modules-v1";

export const SIDEBAR_MODULE_OPTIONS: SidebarModuleOption[] = [
  { id: "dashboard", label: "Dashboard", group: "Core" },
  { id: "inbox", label: "Inbox", group: "Core" },
  { id: "office", label: "Office", group: "Core" },
  { id: "workbench", label: "Workbench", group: "Execution" },
  { id: "execution", label: "Execution Section", group: "Execution" },
  { id: "terminal", label: "Terminal", group: "Execution" },
  { id: "chat", label: "Chat", group: "Execution" },
  { id: "sessions", label: "Sessions", group: "Execution" },
  { id: "rhythm", label: "Rhythm", group: "Reference" },
  { id: "signals", label: "Signals", group: "Reference" },
  { id: "nodes", label: "Nodes", group: "Reference" },
  { id: "library", label: "Library Section", group: "Reference" },
  { id: "templates", label: "Templates", group: "Reference" },
  { id: "skills", label: "Skills", group: "Reference" },
  { id: "projects", label: "Projects", group: "Reference" },
  { id: "team", label: "Team", group: "People" },
  { id: "agents", label: "AI Agents", group: "People" },
  { id: "automation", label: "Automation Section", group: "Automation" },
  { id: "schedules", label: "Schedules", group: "Automation" },
  { id: "integrations", label: "Integrations", group: "Automation" },
  { id: "activity", label: "Activity", group: "Automation" },
  { id: "system", label: "System", group: "System" },
];

const DEFAULT_VISIBLE = new Set<SidebarModuleId>(
  SIDEBAR_MODULE_OPTIONS.map((option) => option.id),
);

function normalizeVisible(value: unknown): SidebarModuleId[] {
  if (!Array.isArray(value)) return Array.from(DEFAULT_VISIBLE);
  const valid = new Set(SIDEBAR_MODULE_OPTIONS.map((option) => option.id));
  const normalized = value.filter((entry): entry is SidebarModuleId => {
    return typeof entry === "string" && valid.has(entry as SidebarModuleId);
  });
  return normalized.length > 0 ? normalized : Array.from(DEFAULT_VISIBLE);
}

class SidebarStore {
  visibleModuleIds = $state<SidebarModuleId[]>(Array.from(DEFAULT_VISIBLE));
  loaded = $state(false);

  load(): void {
    if (!browser || this.loaded) return;
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      this.visibleModuleIds = raw ? normalizeVisible(JSON.parse(raw)) : Array.from(DEFAULT_VISIBLE);
    } catch {
      this.visibleModuleIds = Array.from(DEFAULT_VISIBLE);
    } finally {
      this.loaded = true;
    }
  }

  save(): void {
    if (!browser) return;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.visibleModuleIds));
  }

  isVisible(id: SidebarModuleId): boolean {
    if (!this.loaded) this.load();
    return this.visibleModuleIds.includes(id);
  }

  setVisible(id: SidebarModuleId, visible: boolean): void {
    const current = new Set(this.visibleModuleIds);
    if (visible) {
      current.add(id);
    } else {
      current.delete(id);
    }
    this.visibleModuleIds = SIDEBAR_MODULE_OPTIONS
      .map((option) => option.id)
      .filter((optionId) => current.has(optionId));
    this.save();
  }

  reset(): void {
    this.visibleModuleIds = Array.from(DEFAULT_VISIBLE);
    this.save();
  }
}

export const sidebarStore = new SidebarStore();

