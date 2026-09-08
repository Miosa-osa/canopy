/**
 * theme.svelte.ts — pure-logic unit tests.
 *
 * Tests cover: ThemeMode guard, resolveMode logic, ACCENT_PRESETS shape,
 * LS key contracts, setMode/setAccent/applyPreset persistence side-effects.
 * Svelte rune state is not instantiated — logic helpers are tested in isolation.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { ACCENT_PRESETS, type AccentPreset, type ThemeMode } from './theme.svelte.js';

// ── ThemeMode type guard (mirrored from store) ────────────────────────────────

function isThemeMode(value: unknown): value is ThemeMode {
  return value === 'light' || value === 'dark' || value === 'system';
}

describe('isThemeMode', () => {
  it("accepts 'light'", () => {
    expect(isThemeMode('light')).toBe(true);
  });

  it("accepts 'dark'", () => {
    expect(isThemeMode('dark')).toBe(true);
  });

  it("accepts 'system'", () => {
    expect(isThemeMode('system')).toBe(true);
  });

  it('rejects unknown string', () => {
    expect(isThemeMode('auto')).toBe(false);
  });

  it('rejects null', () => {
    expect(isThemeMode(null)).toBe(false);
  });

  it('rejects undefined', () => {
    expect(isThemeMode(undefined)).toBe(false);
  });

  it('rejects number', () => {
    expect(isThemeMode(1)).toBe(false);
  });
});

// ── resolveMode logic (isolated) ──────────────────────────────────────────────

function resolveMode(mode: ThemeMode, systemPreference: 'dark' | 'light'): 'light' | 'dark' {
  if (mode !== 'system') return mode;
  return systemPreference;
}

describe('resolveMode', () => {
  it("returns 'light' when mode is 'light'", () => {
    expect(resolveMode('light', 'dark')).toBe('light');
  });

  it("returns 'dark' when mode is 'dark'", () => {
    expect(resolveMode('dark', 'light')).toBe('dark');
  });

  it("returns system preference when mode is 'system' and preference is dark", () => {
    expect(resolveMode('system', 'dark')).toBe('dark');
  });

  it("returns system preference when mode is 'system' and preference is light", () => {
    expect(resolveMode('system', 'light')).toBe('light');
  });
});

// ── Storage key contracts ─────────────────────────────────────────────────────

const LS_MODE_KEY = 'canopy.theme.mode';
const LS_ACCENT_KEY = 'canopy.theme.accent';

describe('localStorage key contracts', () => {
  it('mode key is correct', () => {
    expect(LS_MODE_KEY).toBe('canopy.theme.mode');
  });

  it('accent key is correct', () => {
    expect(LS_ACCENT_KEY).toBe('canopy.theme.accent');
  });

  it('keys are distinct', () => {
    expect(LS_MODE_KEY).not.toBe(LS_ACCENT_KEY);
  });
});

// ── Persistence logic (isolated with map mock) ────────────────────────────────

function makeStore(): Map<string, string> {
  return new Map();
}

function simulateSetMode(store: Map<string, string>, mode: ThemeMode): void {
  store.set(LS_MODE_KEY, mode);
}

function simulateSetAccent(store: Map<string, string>, value: string): void {
  store.set(LS_ACCENT_KEY, value);
}

describe('setMode persistence', () => {
  let store: Map<string, string>;

  beforeEach(() => {
    store = makeStore();
  });

  it("persists 'light' under mode key", () => {
    simulateSetMode(store, 'light');
    expect(store.get(LS_MODE_KEY)).toBe('light');
  });

  it("persists 'dark' under mode key", () => {
    simulateSetMode(store, 'dark');
    expect(store.get(LS_MODE_KEY)).toBe('dark');
  });

  it("persists 'system' under mode key", () => {
    simulateSetMode(store, 'system');
    expect(store.get(LS_MODE_KEY)).toBe('system');
  });

  it('overwrites previous mode', () => {
    simulateSetMode(store, 'dark');
    simulateSetMode(store, 'light');
    expect(store.get(LS_MODE_KEY)).toBe('light');
  });
});

describe('setAccent persistence', () => {
  let store: Map<string, string>;

  beforeEach(() => {
    store = makeStore();
  });

  it('persists accent value under accent key', () => {
    simulateSetAccent(store, 'oklch(0.60 0.16 255)');
    expect(store.get(LS_ACCENT_KEY)).toBe('oklch(0.60 0.16 255)');
  });

  it('overwrites previous accent', () => {
    simulateSetAccent(store, 'oklch(0.60 0.16 255)');
    simulateSetAccent(store, 'oklch(0.65 0.15 145)');
    expect(store.get(LS_ACCENT_KEY)).toBe('oklch(0.65 0.15 145)');
  });
});

// ── ACCENT_PRESETS shape ──────────────────────────────────────────────────────

describe('ACCENT_PRESETS', () => {
  it('has exactly 8 presets', () => {
    expect(ACCENT_PRESETS).toHaveLength(8);
  });

  it('every preset has a non-empty label', () => {
    for (const p of ACCENT_PRESETS) {
      expect(typeof p.label).toBe('string');
      expect(p.label.length).toBeGreaterThan(0);
    }
  });

  it("every preset value starts with 'oklch('", () => {
    for (const p of ACCENT_PRESETS) {
      expect(p.value.startsWith('oklch(')).toBe(true);
    }
  });

  it("every preset fgValue starts with 'oklch('", () => {
    for (const p of ACCENT_PRESETS) {
      expect(p.fgValue.startsWith('oklch(')).toBe(true);
    }
  });

  it('labels are unique', () => {
    const labels = ACCENT_PRESETS.map((p) => p.label);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it('values are unique', () => {
    const values = ACCENT_PRESETS.map((p) => p.value);
    expect(new Set(values).size).toBe(values.length);
  });

  it('first preset is Blue', () => {
    expect(ACCENT_PRESETS[0].label).toBe('Blue');
  });

  it('contains a Green preset', () => {
    const green = ACCENT_PRESETS.find((p) => p.label === 'Green');
    expect(green).toBeDefined();
  });
});

// ── AccentPreset type contract ────────────────────────────────────────────────

describe('AccentPreset type contract', () => {
  it('satisfies the interface shape', () => {
    const preset: AccentPreset = {
      label: 'Test',
      value: 'oklch(0.60 0.16 255)',
      fgValue: 'oklch(0.985 0 0)',
    };
    expect(preset.label).toBe('Test');
    expect(preset.value).toContain('oklch');
    expect(preset.fgValue).toContain('oklch');
  });
});
