/**
 * Tests for keyboard shortcut handler.
 * Verifies ⌘⇧D toggles theme and ⌘⇧L toggles sidebar.
 * Uses plain event-shaped objects since Vitest runs in Node (no KeyboardEvent global).
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';

// Mock the ui store before importing the module under test
const mockUi = {
  toggleTheme: vi.fn(),
  toggleSidebar: vi.fn(),
};

vi.mock('$lib/stores/ui.svelte.js', () => ({ ui: mockUi }));

const { handleGlobalShortcut } = await import('./keyboard.js');

function makeKeyEvent(key: string, metaKey = false, shiftKey = false): KeyboardEvent {
  const preventDefault = vi.fn();
  // Plain object shaped like KeyboardEvent — Node env has no KeyboardEvent global
  return { key, metaKey, shiftKey, preventDefault } as unknown as KeyboardEvent;
}

describe('handleGlobalShortcut()', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('calls ui.toggleTheme on ⌘⇧D', () => {
    const e = makeKeyEvent('D', true, true);
    handleGlobalShortcut(e);
    expect(mockUi.toggleTheme).toHaveBeenCalledOnce();
    expect(e.preventDefault).toHaveBeenCalled();
  });

  it('calls ui.toggleSidebar on ⌘⇧L', () => {
    const e = makeKeyEvent('L', true, true);
    handleGlobalShortcut(e);
    expect(mockUi.toggleSidebar).toHaveBeenCalledOnce();
    expect(e.preventDefault).toHaveBeenCalled();
  });

  it('does nothing when metaKey is false', () => {
    const e = makeKeyEvent('D', false, true);
    handleGlobalShortcut(e);
    expect(mockUi.toggleTheme).not.toHaveBeenCalled();
  });

  it('does nothing when shiftKey is false', () => {
    const e = makeKeyEvent('D', true, false);
    handleGlobalShortcut(e);
    expect(mockUi.toggleTheme).not.toHaveBeenCalled();
  });

  it('does nothing for unrecognized ⌘⇧ key', () => {
    const e = makeKeyEvent('Z', true, true);
    handleGlobalShortcut(e);
    expect(mockUi.toggleTheme).not.toHaveBeenCalled();
    expect(mockUi.toggleSidebar).not.toHaveBeenCalled();
  });
});
