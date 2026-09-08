/**
 * Canopy keyboard shortcut registry.
 * Single source of truth for all shortcuts — consumed by:
 *   - /settings/keyboard (cheatsheet viewer)
 *   - CommandPalette keyboard hints (⌘K panel)
 *   - Future ⌘/ modal (Wave C)
 *
 * Shape: array of ShortcutSection, each with an array of ShortcutEntry.
 */

export interface ShortcutEntry {
  /** Keys to display — each element is one key token, e.g. ["⌘", "K"] */
  keys: string[];
  /** Human-readable action description */
  description: string;
}

export interface ShortcutSection {
  /** Section header label */
  label: string;
  entries: ShortcutEntry[];
}

/** Full shortcut registry. */
export const SHORTCUTS: ShortcutSection[] = [
  {
    label: 'Global',
    entries: [
      { keys: ['⌘', 'K'], description: 'Open command palette' },
      { keys: ['⌘', ','], description: 'Open settings' },
      { keys: ['⌘', '⇧', 'D'], description: 'Toggle dark / light mode' },
      { keys: ['⌘', '⇧', 'L'], description: 'Toggle sidebar' },
      { keys: ['Esc'], description: 'Close modal or dismiss overlay' },
    ],
  },
  {
    label: 'Navigation',
    entries: [
      { keys: ['⌘', '1'], description: 'Go to Dashboard' },
      { keys: ['⌘', '2'], description: 'Go to Runtimes' },
      { keys: ['⌘', '3'], description: 'Go to Sessions' },
      { keys: ['⌘', '4'], description: 'Go to Agents' },
      { keys: ['⌘', '5'], description: 'Go to Workspaces' },
    ],
  },
  {
    label: 'Lists',
    entries: [
      { keys: ['↑', '↓'], description: 'Move focus between rows' },
      { keys: ['Enter'], description: 'Open selected item' },
      { keys: ['⌘', 'Enter'], description: 'Open in new panel' },
    ],
  },
  {
    label: 'Editor',
    entries: [
      { keys: ['⌘', 'S'], description: 'Save changes' },
      { keys: ['⌘', 'Z'], description: 'Undo' },
      { keys: ['⌘', '⇧', 'Z'], description: 'Redo' },
      { keys: ['⌘', '/'], description: 'Toggle comment' },
    ],
  },
  {
    label: 'Sessions',
    entries: [
      { keys: ['⌘', 'N'], description: 'New session' },
      { keys: ['⌘', 'W'], description: 'Close active session' },
      { keys: ['⌘', '⇧', 'W'], description: 'Open workspace switcher' },
    ],
  },
  {
    label: 'Chat / Channels',
    entries: [
      { keys: ['Enter'], description: 'Send message' },
      { keys: ['⇧', 'Enter'], description: 'New line in message' },
      { keys: ['↑'], description: 'Edit last message' },
    ],
  },
  {
    label: 'Dashboard',
    entries: [
      { keys: ['R'], description: 'Refresh data' },
      { keys: ['F'], description: 'Toggle filter panel' },
    ],
  },
];
