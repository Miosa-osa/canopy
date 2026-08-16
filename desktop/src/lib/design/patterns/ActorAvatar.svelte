<script lang="ts">
/**
 * ActorAvatar — unified avatar for humans (initials) and agents (Bot icon).
 * UI-only unification, no data model polymorphism.
 * Per Roberto's "no human adapter" rule — humans and agents stay separate in data.
 * LOC target: ≤ 80.
 */
import { Bot } from 'lucide-svelte';
import Avatar from '$lib/design/foundation/avatar/Avatar.svelte';

interface HumanActor {
  type: 'human';
  id: string;
  name: string;
  avatar?: string;
}

interface AgentActor {
  type: 'agent';
  id: string;
  name: string;
  emoji?: string;
  avatar?: string;
}

type Actor = HumanActor | AgentActor;

interface Props {
  actor: Actor;
  size?: 'sm' | 'md' | 'lg';
  class?: string;
}

let { actor, size = 'md', class: className = '' }: Props = $props();

const sizeMap: Record<'sm' | 'md' | 'lg', 'sm' | 'default' | 'lg'> = {
  sm: 'sm',
  md: 'default',
  lg: 'lg',
};

const iconSize: Record<'sm' | 'md' | 'lg', number> = {
  sm: 12,
  md: 16,
  lg: 20,
};

/** Build initials from name for human actors. */
function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
</script>

{#if actor.type === 'human'}
  <Avatar
    src={actor.avatar}
    fallback={initials(actor.name)}
    alt={actor.name}
    size={sizeMap[size]}
    shape="circle"
    class={className}
  />
{:else}
  <!-- Agent actor: tinted bot icon -->
  <span
    class="cnp-agent-avatar cnp-agent-avatar--{size} {className}"
    role="img"
    aria-label={actor.name}
    title={actor.name}
  >
    {#if actor.emoji}
      <span class="cnp-agent-avatar__emoji">{actor.emoji}</span>
    {:else}
      <Bot size={iconSize[size]} aria-hidden="true" />
    {/if}
  </span>
{/if}

<style>
  .cnp-agent-avatar {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    border-radius: 9999px;
    background: color-mix(in oklch, var(--signal-thinking) 15%, var(--bg-elevated) 85%);
    border: 1px solid color-mix(in oklch, var(--signal-thinking) 30%, transparent 70%);
    color: var(--signal-thinking);
    flex-shrink: 0;
    font-size: 14px;
    line-height: 1;
  }

  .cnp-agent-avatar--sm {
    width: 28px;
    height: 28px;
  }

  .cnp-agent-avatar--md {
    width: 36px;
    height: 36px;
  }

  .cnp-agent-avatar--lg {
    width: 44px;
    height: 44px;
    font-size: 18px;
  }

  .cnp-agent-avatar__emoji {
    line-height: 1;
    user-select: none;
  }
</style>
