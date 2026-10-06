// src/lib/stores/schedules-fs.svelte.ts
// Filesystem-backed schedules store — reads CanopyScheduleDef[] from workspaceStore.lastScan
// or re-triggers a scan when needed.

import type { CanopyScheduleDef } from "$lib/types/canopy";

// ── Next-run calculator ────────────────────────────────────────────────────────
// Handles the subset of cron expressions used in .canopy/schedules/:
//   "0 H * * *"         — daily at hour H
//   "0 H * * DOW"       — weekly on day-of-week DOW (0=Sun, 5=Fri, 1=Mon …)
//   "0 H L * DOW"       — monthly: last occurrence of DOW in month (non-standard)
//   "0 H 1 * *"         — monthly on the 1st
// Returns ISO string of the next occurrence in local time.

export function nextRunFromCron(cron: string): Date | null {
  const parts = cron.trim().split(/\s+/);
  if (parts.length !== 5) return null;

  const [minute, hour, dom, , dow] = parts;
  const min = parseInt(minute, 10);
  const hr = parseInt(hour, 10);

  if (isNaN(min) || isNaN(hr)) return null;

  const now = new Date();
  const candidate = new Date(now);
  candidate.setSeconds(0, 0);
  candidate.setMinutes(min);
  candidate.setHours(hr);

  // Weekly: "0 H * * DOW"
  if (dom === "*" && dow !== "*") {
    const targetDow = parseInt(dow, 10);
    if (isNaN(targetDow)) return null;
    // Advance to the correct day-of-week
    let daysAhead = (targetDow - now.getDay() + 7) % 7;
    if (daysAhead === 0 && candidate <= now) daysAhead = 7;
    candidate.setDate(now.getDate() + daysAhead);
    return candidate;
  }

  // Monthly last-DOW: "0 H L * DOW" (non-standard — approximated as ~28-31 days out)
  if (dom === "L" && dow !== "*") {
    const targetDow = parseInt(dow, 10);
    if (isNaN(targetDow)) return null;
    // Find the last occurrence of targetDow in the current month
    const year = now.getFullYear();
    const month = now.getMonth();
    const lastDay = new Date(year, month + 1, 0).getDate();
    let d = new Date(year, month, lastDay);
    while (d.getDay() !== targetDow) {
      d.setDate(d.getDate() - 1);
    }
    d.setHours(hr);
    d.setMinutes(min);
    d.setSeconds(0, 0);
    if (d <= now) {
      // Try next month
      const nm = new Date(year, month + 2, 0);
      nm.setDate(new Date(year, month + 2, 0).getDate());
      while (nm.getDay() !== targetDow) {
        nm.setDate(nm.getDate() - 1);
      }
      nm.setHours(hr);
      nm.setMinutes(min);
      nm.setSeconds(0, 0);
      return nm;
    }
    return d;
  }

  // Monthly on day N: "0 H N * *"
  if (dom !== "*" && dow === "*") {
    const targetDom = parseInt(dom, 10);
    if (isNaN(targetDom)) return null;
    candidate.setDate(targetDom);
    if (candidate <= now) {
      // Next month
      candidate.setMonth(candidate.getMonth() + 1);
      candidate.setDate(targetDom);
    }
    return candidate;
  }

  // Daily: "0 H * * *"
  if (candidate <= now) {
    candidate.setDate(candidate.getDate() + 1);
  }
  return candidate;
}

/** Format a Date as "Mon, 3:00 PM" or "Today, 3:00 PM" */
export function formatNextRun(d: Date): string {
  const now = new Date();
  const isToday =
    d.getDate() === now.getDate() &&
    d.getMonth() === now.getMonth() &&
    d.getFullYear() === now.getFullYear();

  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  const isTomorrow =
    d.getDate() === tomorrow.getDate() &&
    d.getMonth() === tomorrow.getMonth() &&
    d.getFullYear() === tomorrow.getFullYear();

  const time = d.toLocaleTimeString(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  });

  if (isToday) return `Today, ${time}`;
  if (isTomorrow) return `Tomorrow, ${time}`;

  const day = d.toLocaleDateString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
  return `${day}, ${time}`;
}

/** Human-readable cron description for the patterns we use */
export function cronLabel(cron: string): string {
  const parts = cron.trim().split(/\s+/);
  if (parts.length !== 5) return cron;
  const [minute, hour, dom, , dow] = parts;
  const hr = parseInt(hour, 10);
  const min = parseInt(minute, 10);
  if (isNaN(hr)) return cron;

  const timePart =
    min === 0
      ? `${hr === 0 ? "12" : hr > 12 ? hr - 12 : hr}:00 ${hr < 12 ? "AM" : "PM"}`
      : `${hr}:${String(min).padStart(2, "0")}`;

  const DOW_NAMES = [
    "Sunday",
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
  ];

  if (dom === "L" && dow !== "*") {
    const d = parseInt(dow, 10);
    return `Last ${DOW_NAMES[d] ?? dow} of month at ${timePart}`;
  }
  if (dom !== "*" && dow === "*") {
    return `Monthly on day ${dom} at ${timePart}`;
  }
  if (dom === "*" && dow !== "*") {
    const d = parseInt(dow, 10);
    return `Weekly on ${DOW_NAMES[d] ?? dow} at ${timePart}`;
  }
  return `Daily at ${timePart}`;
}

// ── Store ─────────────────────────────────────────────────────────────────────

let schedules = $state<CanopyScheduleDef[]>([]);
let loading = $state(false);
let error = $state<string | null>(null);
let initialized = $state(false);

/** Load filesystem schedules from a workspace scan result */
function loadFromScan(defs: CanopyScheduleDef[]): void {
  schedules = defs;
  initialized = true;
}

/** Scan workspace path and extract schedules */
async function load(workspacePath: string): Promise<void> {
  loading = true;
  error = null;
  try {
    const { workspaceStore } = await import("./workspace.svelte");
    const scan = await workspaceStore.scanWorkspace(workspacePath);
    if (scan) {
      schedules = scan.schedules ?? [];
    } else {
      schedules = [];
    }
    initialized = true;
  } catch (e) {
    error = e instanceof Error ? e.message : String(e);
    schedules = [];
  } finally {
    loading = false;
  }
}

function reset(): void {
  schedules = [];
  loading = false;
  error = null;
  initialized = false;
}

export const schedulesFsStore = {
  get schedules() {
    return schedules;
  },
  get loading() {
    return loading;
  },
  get error() {
    return error;
  },
  get initialized() {
    return initialized;
  },
  load,
  loadFromScan,
  reset,
};
