/**
 * Runtime detection boot sync.
 *
 * On Tauri app boot, invoke the Rust `runtime_detect` command which scans
 * $PATH for all 9 canonical runtime binaries, then POST the result to the
 * Phoenix backend's `/api/v1/runtimes/detect` endpoint. The backend upserts
 * `installed`, `version`, `binary_path`, `last_detected_at` fields without
 * touching user-configured `enabled` or `config`.
 *
 * Runs once per session boot. Subsequent manual re-sync (e.g. from a
 * "Re-scan" button on /runtimes) calls `syncRuntimes()` directly.
 *
 * In browser dev mode (no Tauri), silently skips with a debug log.
 */

import { apiPost } from '$lib/api/client.js';
import { isTauri } from '$lib/tauri/index.js';

/** Shape returned by the Rust `runtime_detect` command. */
export interface DetectedRuntime {
  slug: string;
  binary: string;
  installed: boolean;
  path: string | null;
  version: string | null;
}

interface SyncResult {
  ok: boolean;
  detectedCount: number;
  installedCount: number;
  error?: string;
}

/**
 * Invoke Rust `runtime_detect` + POST result to `/api/v1/runtimes/detect`.
 *
 * @returns SyncResult with counts and optional error. Never throws —
 *          failure paths log and return an error result so boot isn't blocked.
 */
export async function syncRuntimes(): Promise<SyncResult> {
  if (!isTauri()) {
    // Browser dev mode — no Tauri, no detection.
    return {
      ok: false,
      detectedCount: 0,
      installedCount: 0,
      error: 'not_in_tauri',
    };
  }

  let detected: DetectedRuntime[];
  try {
    const { invoke } = await import('@tauri-apps/api/core');
    detected = (await invoke('runtime_detect')) as DetectedRuntime[];
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[runtime-sync] detect failed:', message);
    return { ok: false, detectedCount: 0, installedCount: 0, error: message };
  }

  const installedCount = detected.filter((r) => r.installed).length;

  try {
    await apiPost('/runtimes/detect', { detected });
    return { ok: true, detectedCount: detected.length, installedCount };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[runtime-sync] backend upsert failed:', message);
    return {
      ok: false,
      detectedCount: detected.length,
      installedCount,
      error: message,
    };
  }
}

/**
 * Idempotent boot sync — safe to call multiple times; subsequent calls
 * within `minIntervalMs` are no-ops.
 */
let lastSyncAt = 0;

export async function syncRuntimesIfStale(
  minIntervalMs: number = 60_000
): Promise<SyncResult | null> {
  const now = Date.now();
  if (now - lastSyncAt < minIntervalMs) {
    return null;
  }
  lastSyncAt = now;
  return syncRuntimes();
}
