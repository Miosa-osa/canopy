/**
 * Smoke tests for the shortcut registry shape.
 * Verifies structural contracts consumed by the keyboard settings page
 * and any future CommandPalette hint integrations.
 */
import { describe, expect, it } from 'vitest';
import { SHORTCUTS, type ShortcutEntry, type ShortcutSection } from './shortcuts.js';

describe('SHORTCUTS registry', () => {
  it('exports a non-empty array', () => {
    expect(Array.isArray(SHORTCUTS)).toBe(true);
    expect(SHORTCUTS.length).toBeGreaterThan(0);
  });

  it('every section has a non-empty label', () => {
    for (const section of SHORTCUTS) {
      expect(typeof section.label).toBe('string');
      expect(section.label.length).toBeGreaterThan(0);
    }
  });

  it('every section has a non-empty entries array', () => {
    for (const section of SHORTCUTS) {
      expect(Array.isArray(section.entries)).toBe(true);
      expect(section.entries.length).toBeGreaterThan(0);
    }
  });

  it('every entry has a keys array with at least one key', () => {
    for (const section of SHORTCUTS) {
      for (const entry of section.entries) {
        expect(Array.isArray(entry.keys)).toBe(true);
        expect(entry.keys.length).toBeGreaterThan(0);
        for (const key of entry.keys) {
          expect(typeof key).toBe('string');
          expect(key.length).toBeGreaterThan(0);
        }
      }
    }
  });

  it('every entry has a non-empty description string', () => {
    for (const section of SHORTCUTS) {
      for (const entry of section.entries) {
        expect(typeof entry.description).toBe('string');
        expect(entry.description.length).toBeGreaterThan(0);
      }
    }
  });

  it('contains expected sections: Global, Navigation, Editor', () => {
    const labels = SHORTCUTS.map((s) => s.label);
    expect(labels).toContain('Global');
    expect(labels).toContain('Navigation');
    expect(labels).toContain('Editor');
  });

  it('Global section contains ⌘K command palette shortcut', () => {
    const globalSection = SHORTCUTS.find((s) => s.label === 'Global');
    expect(globalSection).toBeDefined();
    const kEntry = globalSection!.entries.find((e) => e.keys.includes('K'));
    expect(kEntry).toBeDefined();
  });

  it('ShortcutSection type is satisfied (structural)', () => {
    // Type-level: if compilation passes, the shape is correct.
    const first: ShortcutSection = SHORTCUTS[0];
    const firstEntry: ShortcutEntry = first.entries[0];
    expect(Array.isArray(firstEntry.keys)).toBe(true);
    expect(typeof firstEntry.description).toBe('string');
  });
});
