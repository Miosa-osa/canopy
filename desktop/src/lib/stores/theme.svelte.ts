/**
 * Theme store — mode + accent color.
 *
 * mode:   'light' | 'dark' | 'system'
 * accent: OKLCh CSS string (e.g. "oklch(0.65 0.16 255)") or hex.
 *
 * Applies:
 *   - data-theme="light|dark" + .dark class on documentElement
 *   - --user-accent + --user-accent-fg on documentElement
 *
 * Persists to: localStorage keys canopy.theme.mode + canopy.theme.accent
 *
 * SSR-safe: all document/window/localStorage access is guarded.
 */

export type ThemeMode = 'light' | 'dark' | 'system';

// ── Preset accent palette (curated hues + Canopy green) ──────────────────────

export interface AccentPreset {
  label: string;
  value: string /** OKLCh value for --user-accent */;
  fgValue: string /** OKLCh value for --user-accent-fg */;
}

export const ACCENT_PRESETS: AccentPreset[] = [
  { label: 'Blue', value: 'oklch(0.60 0.16 255)', fgValue: 'oklch(0.985 0 0)' },
  {
    label: 'Violet',
    value: 'oklch(0.58 0.20 280)',
    fgValue: 'oklch(0.985 0 0)',
  },
  {
    label: 'Purple',
    value: 'oklch(0.56 0.20 305)',
    fgValue: 'oklch(0.985 0 0)',
  },
  { label: 'Rose', value: 'oklch(0.60 0.22 10)', fgValue: 'oklch(0.985 0 0)' },
  {
    label: 'Orange',
    value: 'oklch(0.70 0.18 50)',
    fgValue: 'oklch(0.141 0.005 285.823)',
  },
  {
    label: 'Yellow',
    value: 'oklch(0.78 0.16 85)',
    fgValue: 'oklch(0.141 0.005 285.823)',
  },
  {
    label: 'Green',
    value: 'oklch(0.65 0.15 145)',
    fgValue: 'oklch(0.141 0.005 285.823)',
  },
  { label: 'Teal', value: 'oklch(0.60 0.15 195)', fgValue: 'oklch(0.985 0 0)' },
];

const DEFAULT_ACCENT = ACCENT_PRESETS[0];

// ── Storage keys ──────────────────────────────────────────────────────────────

const LS_MODE_KEY = 'canopy.theme.mode';
const LS_ACCENT_KEY = 'canopy.theme.accent';

// ── Helpers ───────────────────────────────────────────────────────────────────

function isThemeMode(value: unknown): value is ThemeMode {
  return value === 'light' || value === 'dark' || value === 'system';
}

function resolveMode(mode: ThemeMode): 'light' | 'dark' {
  if (mode !== 'system') return mode;
  if (typeof window === 'undefined') return 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function applyModeToDOM(resolved: 'light' | 'dark'): void {
  if (typeof document === 'undefined') return;
  document.documentElement.setAttribute('data-theme', resolved);
  document.documentElement.classList.toggle('dark', resolved === 'dark');
}

function applyAccentToDOM(value: string, fgValue: string): void {
  if (typeof document === 'undefined') return;
  document.documentElement.style.setProperty('--user-accent', value);
  document.documentElement.style.setProperty('--user-accent-fg', fgValue);
}

function readLS(key: string): string | null {
  if (typeof localStorage === 'undefined') return null;
  return localStorage.getItem(key);
}

function writeLS(key: string, value: string): void {
  if (typeof localStorage === 'undefined') return;
  localStorage.setItem(key, value);
}

// ── Store ─────────────────────────────────────────────────────────────────────

class ThemeStore {
  mode = $state<ThemeMode>('system');
  accent = $state<string>(DEFAULT_ACCENT.value);
  accentFg = $state<string>(DEFAULT_ACCENT.fgValue);

  constructor() {
    if (typeof localStorage === 'undefined') return;

    // Rehydrate mode
    const savedMode = readLS(LS_MODE_KEY);
    if (isThemeMode(savedMode)) {
      this.mode = savedMode;
    }

    // Rehydrate accent
    const savedAccent = readLS(LS_ACCENT_KEY);
    if (savedAccent) {
      // Find matching preset for fg; fall back to white
      const preset = ACCENT_PRESETS.find((p) => p.value === savedAccent);
      this.accent = savedAccent;
      this.accentFg = preset ? preset.fgValue : 'oklch(0.985 0 0)';
    }

    // Apply to DOM on first construction (client-side boot)
    const resolved = resolveMode(this.mode);
    applyModeToDOM(resolved);
    applyAccentToDOM(this.accent, this.accentFg);

    // Respond to system preference changes when mode === 'system'
    if (typeof window !== 'undefined') {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (this.mode === 'system') {
          applyModeToDOM(resolveMode('system'));
        }
      });
    }
  }

  /** Change mode. Immediately applies to DOM and persists. */
  setMode(next: ThemeMode): void {
    this.mode = next;
    writeLS(LS_MODE_KEY, next);
    applyModeToDOM(resolveMode(next));
  }

  /** Set a custom accent from an OKLCh/CSS value. Persists.
   *  fgValue defaults to white — caller should pass the correct contrast fg. */
  setAccent(value: string, fgValue = 'oklch(0.985 0 0)'): void {
    this.accent = value;
    this.accentFg = fgValue;
    writeLS(LS_ACCENT_KEY, value);
    applyAccentToDOM(value, fgValue);
  }

  /** Convenience: apply a preset by index. */
  applyPreset(preset: AccentPreset): void {
    this.setAccent(preset.value, preset.fgValue);
  }

  /** Resolved effective mode (system → light or dark). */
  get resolved(): 'light' | 'dark' {
    return resolveMode(this.mode);
  }
}

export const theme = new ThemeStore();
