/**
 * command-registry.svelte.ts — global command registry for CommandPalette sections.
 *
 * Modules register commands via `commandRegistry.register()`.
 * CommandPalette reads `commandRegistry.commands` reactively.
 *
 * Sections map: Navigate | Actions | Recent | Runtimes
 */

export interface RegistryCommand {
  id: string;
  label: string;
  /** Section label shown in palette */
  section: 'Navigate' | 'Actions' | 'Recent' | 'Runtimes' | string;
  shortcut?: string;
  action: () => void;
}

class CommandRegistry {
  commands = $state<RegistryCommand[]>([]);

  register(cmd: RegistryCommand): () => void {
    if (!this.commands.find((c) => c.id === cmd.id)) {
      this.commands = [...this.commands, cmd];
    }
    return () => this.unregister(cmd.id);
  }

  unregister(id: string): void {
    this.commands = this.commands.filter((c) => c.id !== id);
  }

  /** Replace all commands with a given section (idempotent bulk registration). */
  registerSection(section: string, cmds: Omit<RegistryCommand, 'section'>[]): () => void {
    const tagged = cmds.map((c) => ({ ...c, section }));
    const ids = tagged.map((c) => c.id);
    // Remove any existing commands for these ids
    this.commands = [...this.commands.filter((c) => !ids.includes(c.id)), ...tagged];
    return () => {
      this.commands = this.commands.filter((c) => !ids.includes(c.id));
    };
  }
}

export const commandRegistry = new CommandRegistry();
