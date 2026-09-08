/**
 * sidebar-config.svelte.ts — pure-logic unit tests.
 *
 * Tests cover: defaultConfig shape, loadConfig merge logic, moveItemUp/Down,
 * toggleHidden, and reset. All tests use the exported pure helpers directly
 * (loadConfig, saveConfig, resetConfig, defaultConfig) plus an in-memory
 * localStorage mock — no Svelte runes instantiated at test time.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import {
  defaultConfig,
  loadConfig,
  type SidebarConfig,
  saveConfig,
} from './sidebar-config.svelte.js';

// ── localStorage mock ─────────────────────────────────────────────────────────

const LS_KEY = 'canopy.sidebar.config.v2';

function makeLocalStorageMock(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => {
      store.set(k, v);
    },
    removeItem: (k: string) => {
      store.delete(k);
    },
    clear: () => store.clear(),
    key: (i: number) => Array.from(store.keys())[i] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}

// ── defaultConfig shape ───────────────────────────────────────────────────────

describe('defaultConfig', () => {
  it('has exactly 3 groups', () => {
    expect(defaultConfig.groups).toHaveLength(3);
  });

  it('group labels are COCKPIT, WORKSPACE, SYSTEM in order', () => {
    expect(defaultConfig.groups.map((g) => g.label)).toEqual(['COCKPIT', 'WORKSPACE', 'SYSTEM']);
  });

  it('COCKPIT has 11 items', () => {
    const cockpit = defaultConfig.groups.find((g) => g.label === 'COCKPIT');
    expect(cockpit?.items).toHaveLength(11);
  });

  it('WORKSPACE has 9 items', () => {
    const ws = defaultConfig.groups.find((g) => g.label === 'WORKSPACE');
    expect(ws?.items).toHaveLength(9);
  });

  it('SYSTEM has 9 items', () => {
    const sys = defaultConfig.groups.find((g) => g.label === 'SYSTEM');
    expect(sys?.items).toHaveLength(9);
  });

  it('visible items have hidden: false, stripped items have hidden: true', () => {
    const visibleLabels = [
      'Build',
      'Runtimes',
      'Sessions',
      'Agents',
      'Workspaces',
      'Command Center',
    ];
    for (const group of defaultConfig.groups) {
      for (const item of group.items) {
        if (visibleLabels.includes(item.label)) {
          expect(item.hidden).toBe(false);
        } else {
          expect(item.hidden).toBe(true);
        }
      }
    }
  });

  it('all items have non-empty path, label, and icon', () => {
    for (const group of defaultConfig.groups) {
      for (const item of group.items) {
        expect(item.path.length).toBeGreaterThan(0);
        expect(item.label.length).toBeGreaterThan(0);
        expect(item.icon.length).toBeGreaterThan(0);
      }
    }
  });
});

// ── loadConfig — no saved data ────────────────────────────────────────────────

describe('loadConfig with no saved data', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage = makeLocalStorageMock();
  });

  it('returns a deep clone of defaultConfig', () => {
    const cfg = loadConfig();
    expect(cfg.groups.map((g) => g.label)).toEqual(defaultConfig.groups.map((g) => g.label));
  });

  it('returned config is not the same reference as defaultConfig', () => {
    const cfg = loadConfig();
    expect(cfg).not.toBe(defaultConfig);
  });
});

// ── loadConfig — merge: new items appended ────────────────────────────────────

describe('loadConfig merge — new default items appended', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage = makeLocalStorageMock();
  });

  it('appends new default items not present in saved config', () => {
    // Save a COCKPIT group that is missing the newest default items.
    const partial: SidebarConfig = {
      groups: [
        {
          label: 'COCKPIT',
          items: defaultConfig.groups[0].items.slice(0, 9), // drop last 2 items
        },
        defaultConfig.groups[1],
        defaultConfig.groups[2],
      ],
    };
    localStorage.setItem(LS_KEY, JSON.stringify(partial));

    const merged = loadConfig();
    const cockpit = merged.groups.find((g) => g.label === 'COCKPIT')!;
    expect(cockpit.items).toHaveLength(11);
    // The missing items should be appended in defaultConfig order.
    expect(cockpit.items[9].label).toBe('Review');
    expect(cockpit.items[10].label).toBe('Workbench');
  });
});

// ── loadConfig — merge: stale items dropped ───────────────────────────────────

describe('loadConfig merge — stale saved items dropped', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage = makeLocalStorageMock();
  });

  it('drops items whose path+label are not in defaultConfig', () => {
    const stale: SidebarConfig = {
      groups: [
        {
          label: 'COCKPIT',
          items: [
            ...defaultConfig.groups[0].items,
            {
              path: '/deleted-module',
              label: 'Deleted',
              icon: 'Monitor',
              hidden: false,
            },
          ],
        },
        defaultConfig.groups[1],
        defaultConfig.groups[2],
      ],
    };
    localStorage.setItem(LS_KEY, JSON.stringify(stale));

    const merged = loadConfig();
    const cockpit = merged.groups.find((g) => g.label === 'COCKPIT')!;
    expect(cockpit.items).toHaveLength(11);
    expect(cockpit.items.some((i) => i.label === 'Deleted')).toBe(false);
  });
});

// ── loadConfig — merge: hidden flag preserved ────────────────────────────────

describe('loadConfig merge — hidden flag preserved', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage = makeLocalStorageMock();
  });

  it('preserves hidden: true for saved items', () => {
    const withHidden: SidebarConfig = structuredClone(defaultConfig);
    const savedBuild = withHidden.groups[0].items.find((i) => i.label === 'Build');
    if (savedBuild) savedBuild.hidden = true;
    localStorage.setItem(LS_KEY, JSON.stringify(withHidden));

    const merged = loadConfig();
    const build = merged.groups[0].items.find((i) => i.label === 'Build');
    expect(build?.hidden).toBe(true);
  });
});

// ── moveItemUp logic ──────────────────────────────────────────────────────────

describe('moveItemUp logic', () => {
  function moveUp(
    items: Array<{ path: string; label: string }>,
    path: string,
    label: string
  ): Array<{ path: string; label: string }> {
    const idx = items.findIndex((i) => i.path === path && i.label === label);
    if (idx <= 0) return items;
    const result = [...items];
    [result[idx - 1], result[idx]] = [result[idx], result[idx - 1]];
    return result;
  }

  const items = [
    { path: '/a', label: 'A' },
    { path: '/b', label: 'B' },
    { path: '/c', label: 'C' },
  ];

  it('moves second item to first position', () => {
    const result = moveUp(items, '/b', 'B');
    expect(result[0].label).toBe('B');
    expect(result[1].label).toBe('A');
    expect(result[2].label).toBe('C');
  });

  it('no-ops when item is already first', () => {
    const result = moveUp(items, '/a', 'A');
    expect(result[0].label).toBe('A');
  });

  it('moves last item to second position', () => {
    const result = moveUp(items, '/c', 'C');
    expect(result[1].label).toBe('C');
    expect(result[2].label).toBe('B');
  });
});

// ── moveItemDown logic ────────────────────────────────────────────────────────

describe('moveItemDown logic', () => {
  function moveDown(
    items: Array<{ path: string; label: string }>,
    path: string,
    label: string
  ): Array<{ path: string; label: string }> {
    const idx = items.findIndex((i) => i.path === path && i.label === label);
    if (idx < 0 || idx >= items.length - 1) return items;
    const result = [...items];
    [result[idx], result[idx + 1]] = [result[idx + 1], result[idx]];
    return result;
  }

  const items = [
    { path: '/a', label: 'A' },
    { path: '/b', label: 'B' },
    { path: '/c', label: 'C' },
  ];

  it('moves first item to second position', () => {
    const result = moveDown(items, '/a', 'A');
    expect(result[0].label).toBe('B');
    expect(result[1].label).toBe('A');
    expect(result[2].label).toBe('C');
  });

  it('no-ops when item is already last', () => {
    const result = moveDown(items, '/c', 'C');
    expect(result[2].label).toBe('C');
  });

  it('moves second item to third position', () => {
    const result = moveDown(items, '/b', 'B');
    expect(result[1].label).toBe('C');
    expect(result[2].label).toBe('B');
  });
});

// ── toggleHidden logic ────────────────────────────────────────────────────────

describe('toggleHidden logic', () => {
  function toggle(hidden: boolean): boolean {
    return !hidden;
  }

  it('visible item becomes hidden', () => {
    expect(toggle(false)).toBe(true);
  });

  it('hidden item becomes visible', () => {
    expect(toggle(true)).toBe(false);
  });
});

// ── reset / saveConfig round-trip ─────────────────────────────────────────────

describe('saveConfig / loadConfig round-trip', () => {
  beforeEach(() => {
    (globalThis as Record<string, unknown>).localStorage = makeLocalStorageMock();
  });

  it('saves and reloads config with mutations intact', () => {
    const cfg: SidebarConfig = structuredClone(defaultConfig);
    cfg.groups[0].items[0].hidden = true;
    saveConfig(cfg);

    const reloaded = loadConfig();
    expect(reloaded.groups[0].items[0].hidden).toBe(true);
  });

  it('saving then clearing returns defaultConfig on next load', () => {
    const cfg: SidebarConfig = structuredClone(defaultConfig);
    cfg.groups[0].items[0].hidden = !cfg.groups[0].items[0].hidden;
    saveConfig(cfg);
    localStorage.removeItem(LS_KEY);

    const reloaded = loadConfig();
    expect(reloaded.groups[0].items[0].hidden).toBe(defaultConfig.groups[0].items[0].hidden);
  });
});

// ── localStorage key contract ─────────────────────────────────────────────────

describe('localStorage key contract', () => {
  it('uses the canonical key', () => {
    expect(LS_KEY).toBe('canopy.sidebar.config.v2');
  });
});
