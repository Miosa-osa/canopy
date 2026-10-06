// src/lib/stores/palette.svelte.ts

export interface PaletteItem {
  id: string;
  name: string;
  description?: string;
  icon?: string;
  shortcut?: string;
  action: () => void;
}

export interface SearchSource {
  type: string;
  icon: string;
  items: () => Array<{
    id: string | number;
    name: string;
    description?: string;
  }>;
  action: (item: { id: string | number; name: string }) => void;
}

class PaletteStore {
  isOpen = $state(false);
  query = $state("");
  commands: PaletteItem[] = $state([]);
  searchSources: SearchSource[] = $state([]);

  toggle(): void {
    this.isOpen = !this.isOpen;
    if (!this.isOpen) this.query = "";
  }

  open(): void {
    this.isOpen = true;
    this.query = "";
  }

  close(): void {
    this.isOpen = false;
    this.query = "";
  }

  registerBuiltins(
    goto: (url: string) => Promise<void>,
    actions: Record<string, () => void>,
  ): void {
    this.commands = [
      {
        id: "goto-dashboard",
        name: "Go to Dashboard",
        shortcut: "⌘1",
        action: () => void goto("/app"),
      },
      {
        id: "goto-inbox",
        name: "Go to Inbox",
        shortcut: "⌘2",
        action: () => void goto("/app/inbox"),
      },
      {
        id: "goto-office",
        name: "Go to Office",
        shortcut: "⌘3",
        action: () => void goto("/app/office"),
      },
      {
        id: "goto-workbench",
        name: "Go to Workbench",
        shortcut: "⌘4",
        action: () => void goto("/app/workbench"),
      },
      {
        id: "goto-chat",
        name: "Go to Chat",
        action: () => void goto("/app/chat"),
      },
      {
        id: "goto-sessions",
        name: "Go to Sessions",
        action: () => void goto("/app/sessions"),
      },
      {
        id: "goto-activity",
        name: "Go to Activity",
        action: () => void goto("/app/activity"),
      },
      {
        id: "goto-agents",
        name: "Go to Agents",
        action: () => void goto("/app/agents"),
      },
      {
        id: "goto-schedules",
        name: "Go to Schedules",
        action: () => void goto("/app/schedules"),
      },
      {
        id: "goto-skills",
        name: "Go to Skills",
        action: () => void goto("/app/skills"),
      },
      {
        id: "goto-templates",
        name: "Go to Templates",
        action: () => void goto("/app/templates"),
      },
      {
        id: "goto-integrations",
        name: "Go to Integrations",
        action: () => void goto("/app/integrations"),
      },
      {
        id: "goto-settings",
        name: "Go to Settings",
        shortcut: "⌘,",
        action: () => void goto("/app/settings"),
      },
      {
        id: "goto-terminal",
        name: "Go to Terminal",
        shortcut: "⌘T",
        action: () => void goto("/app/terminal"),
      },
      {
        id: "restart-backend",
        name: "Restart Backend",
        action: actions["restartBackend"] ?? (() => {}),
      },
    ];
  }

  registerSearchSources(sources: SearchSource[]): void {
    this.searchSources = sources;
  }

  get filteredCommands(): PaletteItem[] {
    if (!this.query) return this.commands;
    const q = this.query.toLowerCase();
    return this.commands.filter((c) => c.name.toLowerCase().includes(q));
  }
}

export const paletteStore = new PaletteStore();
