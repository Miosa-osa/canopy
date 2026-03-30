// src/lib/stores/signals-fs.svelte.ts
// Filesystem-backed signals store — reads signal files across all nodes via Tauri IPC
import { browser } from "$app/environment";
import { isTauri } from "$lib/utils/platform";
import type { SignalMeta } from "$lib/types/filesystem";

const READ_SET_KEY = "canopy-signals-read";

function loadReadSet(): Set<string> {
  if (!browser) return new Set();
  try {
    const raw = localStorage.getItem(READ_SET_KEY);
    return raw ? new Set(JSON.parse(raw) as string[]) : new Set();
  } catch {
    return new Set();
  }
}

function persistReadSet(set: Set<string>): void {
  if (!browser) return;
  localStorage.setItem(READ_SET_KEY, JSON.stringify([...set]));
}

let signals = $state<SignalMeta[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
let readSet = $state<Set<string>>(loadReadSet());

const sortedSignals = $derived(
  [...signals].sort((a, b) => b.date.localeCompare(a.date)),
);
const unreadCount = $derived(
  signals.filter((s) => !readSet.has(s.path)).length,
);

async function load(workspacePath: string): Promise<void> {
  if (!isTauri()) return;
  loading = true;
  error = null;
  try {
    const { invoke } = await import("@tauri-apps/api/core");
    const result = await invoke<SignalMeta[]>("list_signal_files", {
      nodesPath: workspacePath + "/nodes",
    });
    signals = Array.isArray(result) ? result : [];
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    signals = [];
  }
  loading = false;
}

function markRead(signalPath: string): void {
  readSet = new Set([...readSet, signalPath]);
  persistReadSet(readSet);
}

function markAllRead(): void {
  readSet = new Set(signals.map((s) => s.path));
  persistReadSet(readSet);
}

function reset(): void {
  signals = [];
  loading = false;
  error = null;
}

export const signalsFsStore = {
  get signals() {
    return signals;
  },
  get sortedSignals() {
    return sortedSignals;
  },
  get unreadCount() {
    return unreadCount;
  },
  get loading() {
    return loading;
  },
  get error() {
    return error;
  },
  load,
  markRead,
  markAllRead,
  reset,
};
