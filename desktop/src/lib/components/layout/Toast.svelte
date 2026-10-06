<!-- src/lib/components/layout/Toast.svelte -->
<script lang="ts">
  import { fly } from 'svelte/transition';
  import { toastStore } from '$lib/stores/toasts.svelte';
  import type { Toast } from '$lib/stores/toasts.svelte';

  interface Props {
    toast: Toast;
  }

  let { toast }: Props = $props();

  const COLOR_MAP = {
    info:    { border: '#3b82f6', icon: '#3b82f6', bg: 'rgba(59,130,246,0.08)' },
    success: { border: 'rgba(34,197,94,0.5)', icon: 'rgba(34,197,94,0.7)', bg: 'rgba(34,197,94,0.06)' },
    warning: { border: '#f59e0b', icon: '#f59e0b', bg: 'rgba(245,158,11,0.08)' },
    error:   { border: '#ef4444', icon: '#ef4444', bg: 'rgba(239,68,68,0.08)'  },
  } as const;

  const ICON_PATH = {
    info:    'M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z',
    success: 'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    warning: 'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z',
    error:   'M9.75 9.75l4.5 4.5m0-4.5l-4.5 4.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
  } as const;

  let colors = $derived(COLOR_MAP[toast.type]);
  let iconPath = $derived(ICON_PATH[toast.type]);
</script>

<div
  class="tn-card"
  style="border-color: {colors.border}; background: {colors.bg};"
  role="alert"
  aria-live="polite"
  transition:fly={{ x: 64, duration: 220 }}
>
  <div class="tn-icon-col" style="color: {colors.icon};">
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d={iconPath} />
    </svg>
  </div>

  <div class="tn-body">
    <p class="tn-title">{toast.title}</p>
    {#if toast.message}
      <p class="tn-message">{toast.message}</p>
    {/if}
  </div>

  <button
    class="tn-dismiss"
    onclick={() => toastStore.dismiss(toast.id)}
    aria-label="Dismiss notification"
  >
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M6 18L18 6M6 6l12 12" />
    </svg>
  </button>
</div>

<style>
  .tn-card {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    width: 320px;
    padding: 12px 14px;
    border-radius: 0;
    border: 1px solid;
    background: var(--dbg);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.5), 0 1px 0 rgba(255, 255, 255, 0.03) inset;
    pointer-events: all;
  }

  .tn-icon-col {
    flex-shrink: 0;
    padding-top: 1px;
  }

  .tn-body {
    flex: 1;
    min-width: 0;
  }

  .tn-title {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--dt);
    line-height: 1.4;
  }

  .tn-message {
    margin: 3px 0 0;
    font-size: 12px;
    color: var(--dt2);
    line-height: 1.5;
  }

  .tn-dismiss {
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    padding: 0;
    border: none;
    background: transparent;
    color: var(--dt3);
    cursor: pointer;
    border-radius: 0;
    transition: color 120ms ease, background 120ms ease;
  }

  .tn-dismiss:hover {
    color: var(--dt);
    background: var(--dbg2);
  }
</style>
