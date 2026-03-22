<!-- src/lib/components/office/AgentAvatar.svelte -->
<!-- SVG avatar component for a single agent in the 2D office view -->
<script lang="ts">
  import type { CanopyAgent, AgentStatus } from '$api/types';

  interface Props {
    agent: CanopyAgent;
    x: number;
    y: number;
    selected?: boolean;
    onclick?: (agent: CanopyAgent) => void;
  }

  let { agent, x, y, selected = false, onclick }: Props = $props();

  // Deterministic color from agent id using djb2 hash
  function djb2(str: string): number {
    let hash = 5381;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash + str.charCodeAt(i)) >>> 0;
    }
    return hash;
  }

  const AVATAR_COLORS = [
    '#6366f1', '#8b5cf6', '#ec4899', '#f43f5e',
    '#f97316', '#eab308', '#22c55e', '#14b8a6',
    '#06b6d4', '#3b82f6', '#a855f7', '#d946ef',
  ];

  const avatarColor = $derived(AVATAR_COLORS[djb2(agent.id) % AVATAR_COLORS.length]);

  // Status ring color and animation
  const STATUS_COLORS: Record<AgentStatus, string> = {
    running:    'rgba(34, 197, 94, 0.7)',
    active:     'rgba(34, 197, 94, 0.7)',
    working:    'rgba(34, 197, 94, 0.7)',
    idle:       '#6366f1',
    sleeping:   '#64748b',
    paused:     '#f59e0b',
    error:      '#ef4444',
    terminated: '#ef4444',
  };

  const statusColor = $derived(STATUS_COLORS[agent.status] ?? '#64748b');

  const shouldPulse = $derived(
    agent.status === 'running' || agent.status === 'paused'
  );

  // Avatar label: emoji or first letter
  const avatarLabel = $derived(
    agent.avatar_emoji?.trim() ||
    (agent.display_name?.[0] ?? agent.name?.[0] ?? '?').toUpperCase()
  );

  const isEmoji = $derived(
    !!agent.avatar_emoji?.trim() && agent.avatar_emoji.trim().length <= 4
  );

  // Truncate task text for speech bubble
  const taskText = $derived(
    agent.current_task
      ? (agent.current_task.length > 28
          ? agent.current_task.slice(0, 25) + '…'
          : agent.current_task)
      : null
  );

  const showSpeechBubble = $derived(
    (agent.status === 'running' || agent.status === 'idle') && !!taskText
  );

  const displayName = $derived(
    agent.display_name?.length > 12
      ? agent.display_name.slice(0, 11) + '…'
      : (agent.display_name || agent.name)
  );

  function handleClick() {
    onclick?.(agent);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      handleClick();
    }
  }
</script>

<g
  class="oa-avatar"
  class:oa-avatar--selected={selected}
  transform="translate({x}, {y})"
  role="button"
  aria-label="Agent {agent.display_name}, status: {agent.status}"
  tabindex="0"
  onclick={handleClick}
  onkeydown={handleKeydown}
  style="cursor: pointer;"
>
  <!-- Desk surface -->
  <rect
    x="-20"
    y="4"
    width="40"
    height="26"
    rx="3"
    ry="3"
    fill="#2d2a4a"
    stroke="#3d3a5a"
    stroke-width="1"
  />
  <!-- Desk edge highlight -->
  <rect
    x="-20"
    y="4"
    width="40"
    height="4"
    rx="3"
    ry="0"
    fill="#3d3a5a"
  />
  <!-- Monitor bezel -->
  <rect x="-8" y="-3" width="16" height="10" rx="2" fill="#1a1830" stroke="#333050" stroke-width="0.5" />
  <!-- Monitor screen glow for active agents -->
  {#if agent.status === 'running'}
    <rect x="-7" y="-2" width="14" height="8" rx="1.5" fill={statusColor} opacity="0.2" />
  {/if}

  <!-- Chair arc -->
  <path
    d="M -12 30 Q 0 38 12 30"
    stroke="#24223a"
    stroke-width="6"
    fill="none"
    stroke-linecap="round"
  />
  <!-- Chair back -->
  <path
    d="M -12 30 Q 0 28 12 30"
    stroke="#2d2a4a"
    stroke-width="3"
    fill="none"
    stroke-linecap="round"
  />

  <!-- Pulse ring (behind avatar) -->
  {#if shouldPulse}
    <circle
      cx="0"
      cy="-14"
      r="18"
      fill="none"
      stroke={statusColor}
      stroke-width="1.5"
      opacity="0.5"
      class="oa-pulse"
    />
  {/if}

  <!-- Selected glow ring -->
  {#if selected}
    <circle
      cx="0"
      cy="-14"
      r="20"
      fill="none"
      stroke="#93c5fd"
      stroke-width="2"
      opacity="0.8"
    />
    <circle
      cx="0"
      cy="-14"
      r="22"
      fill="none"
      stroke="#93c5fd"
      stroke-width="1"
      opacity="0.3"
    />
  {/if}

  <!-- Status ring around avatar -->
  <circle
    cx="0"
    cy="-14"
    r="17"
    fill="none"
    stroke={statusColor}
    stroke-width="1.5"
    opacity={selected ? 1 : 0.7}
  />

  <!-- Avatar circle background -->
  <circle cx="0" cy="-14" r="15" fill={avatarColor} />
  <!-- Inner shadow overlay -->
  <circle cx="0" cy="-14" r="15" fill="url(#oa-avatar-inner)" opacity="0.3" />

  <!-- Avatar label: emoji or letter -->
  {#if isEmoji}
    <text
      x="0"
      y="-9"
      text-anchor="middle"
      dominant-baseline="middle"
      font-size="13"
    >{avatarLabel}</text>
  {:else}
    <text
      x="0"
      y="-14"
      text-anchor="middle"
      dominant-baseline="middle"
      font-size="11"
      font-weight="700"
      fill="white"
      font-family="system-ui, sans-serif"
    >{avatarLabel}</text>
  {/if}

  <!-- Status indicator dot -->
  <circle cx="11" cy="-25" r="4" fill={statusColor} stroke="#13121f" stroke-width="1.5" />

  <!-- Name label -->
  <text
    x="0"
    y="46"
    text-anchor="middle"
    font-size="9"
    fill="#94a3b8"
    font-family="system-ui, sans-serif"
    font-weight="500"
    letter-spacing="0.2"
  >{displayName}</text>

  <!-- Speech bubble for current task -->
  {#if showSpeechBubble}
    <!-- Bubble background -->
    <rect
      x="-46"
      y="-60"
      width="92"
      height="22"
      rx="5"
      fill="#1e2035"
      stroke="#3d3a5a"
      stroke-width="0.8"
      opacity="0.95"
    />
    <!-- Bubble tail -->
    <polygon
      points="0,-38 -4,-34 4,-34"
      fill="#1e2035"
      stroke="#3d3a5a"
      stroke-width="0.8"
    />
    <!-- Task text -->
    <text
      x="0"
      y="-45"
      text-anchor="middle"
      dominant-baseline="middle"
      font-size="8"
      fill="#cbd5e1"
      font-family="system-ui, sans-serif"
    >{taskText}</text>
  {/if}
</g>

<style>
  .oa-avatar {
    transition: transform 200ms ease;
    outline: none;
  }

  .oa-avatar:hover {
    transform: translate(var(--tx, 0px), var(--ty, 0px)) scale(1.08);
    /* Use CSS custom properties for translate — SVG transform handles the actual position */
  }

  .oa-avatar--selected {
    filter: drop-shadow(0 0 8px rgba(147, 197, 253, 0.5));
  }

  /* Pulse animation for running/paused agents */
  .oa-pulse {
    animation: oa-ring-pulse 2s ease-out infinite;
    transform-box: fill-box;
    transform-origin: center;
  }

  @keyframes oa-ring-pulse {
    0%   { transform: scale(0.9); opacity: 0.6; }
    50%  { transform: scale(1.3); opacity: 0; }
    100% { transform: scale(0.9); opacity: 0; }
  }

  @media (prefers-reduced-motion: reduce) {
    .oa-pulse { animation: none; }
  }
</style>
