// src/lib/stores/rhythm.svelte.ts
// Filesystem-backed rhythm store — reads rhythm/ directory via Tauri IPC
import { browser } from "$app/environment";
import { isTauri } from "$lib/utils/platform";
import type { RhythmData, RhythmMode } from "$lib/types/filesystem";

const MODE_KEY = "canopy-rhythm-mode";

function loadPersistedMode(): RhythmMode {
  if (!browser) return "BUILD";
  return (localStorage.getItem(MODE_KEY) as RhythmMode) || "BUILD";
}

let rhythmData = $state<RhythmData | null>(null);
let loading = $state(false);
let error = $state<string | null>(null);
let mode = $state<RhythmMode>(loadPersistedMode());

const today = $derived(rhythmData?.today ?? null);
const weekPlan = $derived(rhythmData?.weekPlan ?? null);
const energy = $derived(rhythmData?.energy ?? null);
const files = $derived(rhythmData?.files ?? []);

async function load(workspacePath: string): Promise<void> {
  if (!isTauri()) return;
  loading = true;
  error = null;
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const result = await invoke<RhythmData>("scan_rhythm_dir", {
      workspacePath,
    });
    rhythmData = result;
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    rhythmData = null;
  }
  loading = false;
}

function setMode(m: RhythmMode): void {
  mode = m;
  if (browser) localStorage.setItem(MODE_KEY, m);
}

function reset(): void {
  rhythmData = null;
  loading = false;
  error = null;
}

export const rhythmStore = {
  get data() {
    return rhythmData;
  },
  get today() {
    return today;
  },
  get weekPlan() {
    return weekPlan;
  },
  get energy() {
    return energy;
  },
  get files() {
    return files;
  },
  get mode() {
    return mode;
  },
  get loading() {
    return loading;
  },
  get error() {
    return error;
  },
  load,
  setMode,
  reset,
};
