<script lang="ts">
/**
 * OAuthDeviceFlow — modal for device code OAuth.
 * Shows user_code prominently, opens verification_url in browser,
 * polls until active/expired, calls onSuccess or onExpired.
 * CSS prefix: odf-
 */
import { onDestroy } from 'svelte';
import type { AuthPollResponse, AuthStartResponse } from '$lib/queries/runtime-auth.js';
import { createAuthPoller, probeAuthModule } from '$lib/queries/runtime-auth.js';

interface Props {
  runtimeId: string;
  flowData: AuthStartResponse;
  onSuccess: () => void;
  onExpired: () => void;
  onClose: () => void;
}

let { runtimeId, flowData, onSuccess, onExpired, onClose }: Props = $props();

let pollStatus = $state<'pending' | 'active' | 'expired'>('pending');
let copied = $state(false);
let errorMsg = $state<string | null>(null);

const userCode = $derived(flowData.user_code ?? '');
const verificationUrl = $derived(flowData.verification_url ?? '');
const intervalMs = $derived((flowData.interval ?? 5) * 1000);

// Start polling immediately
let poller = createAuthPoller(
  runtimeId,
  flowData.device_code ?? '',
  intervalMs,
  (result: AuthPollResponse) => {
    pollStatus = result.status;
  },
  (result: AuthPollResponse) => {
    pollStatus = result.status;
    if (result.status === 'active') onSuccess();
    else onExpired();
  },
  (err: unknown) => {
    errorMsg = err instanceof Error ? err.message : String(err);
  }
);

onDestroy(() => poller.stop());

async function openBrowser() {
  if (verificationUrl) {
    // Tauri shell open, with window.open fallback
    try {
      const mod = await import('@tauri-apps/plugin-shell').catch(() => null);
      if (mod?.open) {
        await mod.open(verificationUrl);
        return;
      }
    } catch {
      // fallback
    }
    window.open(verificationUrl, '_blank', 'noopener');
  }
}

async function copyCode() {
  if (!userCode) return;
  try {
    await navigator.clipboard.writeText(userCode);
    copied = true;
    setTimeout(() => {
      copied = false;
    }, 2000);
  } catch {
    // clipboard not available
  }
}
</script>

<div class="odf-backdrop" role="dialog" aria-modal="true" aria-label="Authenticate with OAuth device code">
  <div class="odf-modal">
    <header class="odf-header">
      <span class="odf-title">Connect account</span>
      <button class="odf-close" onclick={onClose} aria-label="Close">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
        </svg>
      </button>
    </header>

    <div class="odf-body">
      {#if pollStatus === 'active'}
        <p class="odf-success">Connected successfully.</p>
      {:else if pollStatus === 'expired'}
        <p class="odf-error">The code expired. Close and try again.</p>
      {:else}
        <p class="odf-instruction">
          Open the verification URL and enter this code:
        </p>

        <!-- Code display -->
        <div class="odf-code-row">
          <code class="odf-code">{userCode}</code>
          <button class="odf-copy-btn" onclick={copyCode} aria-label="Copy code">
            {copied ? 'Copied' : 'Copy'}
          </button>
        </div>

        <!-- Open browser -->
        {#if verificationUrl}
          <button class="odf-open-btn" onclick={openBrowser}>
            Open {verificationUrl}
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
              <polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/>
            </svg>
          </button>
        {/if}

        <!-- Polling indicator -->
        <div class="odf-polling">
          <span class="odf-spinner" aria-hidden="true"></span>
          <span class="odf-polling-label">Waiting for authorization…</span>
        </div>

        {#if errorMsg}
          <p class="odf-error">{errorMsg}</p>
        {/if}
      {/if}
    </div>
  </div>
</div>

<style>
  .odf-backdrop {
    position: fixed;
    inset: 0;
    background: oklch(0% 0 0 / 50%);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }

  .odf-modal {
    background: var(--bg-elevated);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    width: 360px;
    max-width: calc(100vw - var(--space-8));
    box-shadow: 0 16px 48px oklch(0% 0 0 / 24%);
    display: flex;
    flex-direction: column;
  }

  .odf-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: var(--space-4);
    border-bottom: 1px solid var(--border);
  }

  .odf-title {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    font-weight: 600;
    color: var(--fg);
  }

  .odf-close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    border-radius: var(--radius-sm);
    border: none;
    background: transparent;
    color: var(--fg-subtle);
    cursor: pointer;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .odf-close:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .odf-close:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  .odf-body {
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }

  .odf-instruction {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: var(--fg-muted);
    margin: 0;
  }

  /* ── Code row ── */

  .odf-code-row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    background: var(--bg-inset);
    border: 1px solid var(--border);
    border-radius: var(--radius-md);
    padding: var(--space-2) var(--space-3);
  }

  .odf-code {
    flex: 1;
    font-family: var(--font-mono);
    font-size: var(--text-lg);
    font-weight: 700;
    color: var(--fg);
    letter-spacing: 0.15em;
    user-select: all;
  }

  .odf-copy-btn {
    flex-shrink: 0;
    padding: var(--space-1) var(--space-2);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--fg-muted);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    transition:
      background var(--dur-instant) var(--ease-out),
      color var(--dur-instant) var(--ease-out);
  }

  .odf-copy-btn:hover {
    background: color-mix(in oklch, var(--fg) 8%, transparent 92%);
    color: var(--fg);
  }

  .odf-copy-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Open browser ── */

  .odf-open-btn {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    padding: var(--space-2) var(--space-3);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border);
    background: transparent;
    color: var(--cnp-accent);
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    font-weight: 500;
    cursor: pointer;
    text-align: left;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 100%;
    transition: background var(--dur-instant) var(--ease-out);
  }

  .odf-open-btn:hover {
    background: color-mix(in oklch, var(--cnp-accent) 8%, transparent 92%);
  }

  .odf-open-btn:focus-visible {
    outline: 2px solid var(--cnp-accent);
    outline-offset: 1px;
  }

  /* ── Polling indicator ── */

  .odf-polling {
    display: flex;
    align-items: center;
    gap: var(--space-2);
  }

  .odf-spinner {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    border: 2px solid color-mix(in oklch, var(--fg) 20%, transparent 80%);
    border-top-color: var(--cnp-accent);
    animation: odf-spin 0.8s linear infinite;
    flex-shrink: 0;
  }

  @keyframes odf-spin {
    to { transform: rotate(360deg); }
  }

  .odf-polling-label {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: var(--fg-subtle);
  }

  /* ── Status messages ── */

  .odf-success {
    font-family: var(--font-sans);
    font-size: var(--text-sm);
    color: oklch(50% 0.15 145);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(70% 0.15 145) 12%, transparent 88%);
    border-radius: var(--radius-sm);
  }

  .odf-error {
    font-family: var(--font-sans);
    font-size: var(--text-xs);
    color: oklch(50% 0.2 25);
    margin: 0;
    padding: var(--space-2) var(--space-3);
    background: color-mix(in oklch, oklch(60% 0.2 25) 10%, transparent 90%);
    border-radius: var(--radius-sm);
  }
</style>
