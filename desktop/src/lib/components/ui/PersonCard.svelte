<script lang="ts">
  import { Mail, MessageSquare, Phone, GitBranch } from 'lucide-svelte';
  import GenreBadge from './GenreBadge.svelte';
  interface Props {
    member: { slug: string; name: string; role: string; channels: string[]; genreCompetence?: string[]; constraint?: string; };
    onclick?: () => void;
  }
  let { member, onclick }: Props = $props();
  const channelIcons: Record<string, any> = { email: Mail, slack: MessageSquare, voice: Phone, github: GitBranch };
</script>
<button class="pc" onclick={onclick} type="button">
  <div class="pc-header">
    <div class="pc-avatar">{member.name.charAt(0).toUpperCase()}</div>
    <div class="pc-info">
      <span class="pc-name">{member.name}</span>
      <span class="pc-role">{member.role}</span>
    </div>
    <div class="pc-channels">
      {#each member.channels as ch}
        {#if channelIcons[ch]}
          {@const Icon = channelIcons[ch]}
          <Icon size={14} />
        {/if}
      {/each}
    </div>
  </div>
  {#if member.constraint}
    <div class="pc-constraint">{member.constraint}</div>
  {/if}
  {#if member.genreCompetence?.length}
    <div class="pc-genres">{#each member.genreCompetence.slice(0, 3) as g}<GenreBadge genre={g} />{/each}</div>
  {/if}
</button>
<style>
  .pc { all: unset; display: block; width: 100%; padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); cursor: pointer; transition: background 150ms; text-align: left; }
  .pc:hover { background: rgba(255,255,255,0.04); }
  .pc-header { display: flex; align-items: center; gap: 10px; }
  .pc-avatar { width: 32px; height: 32px; border-radius: 50%; background: rgba(255,255,255,0.1); display: flex; align-items: center; justify-content: center; font-weight: 600; font-size: 13px; flex-shrink: 0; color: var(--text-primary, #e2e8f0); }
  .pc-info { flex: 1; min-width: 0; }
  .pc-name { display: block; font-weight: 500; font-size: 13px; color: var(--text-primary, #e2e8f0); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pc-role { display: block; font-size: 11px; color: rgba(255,255,255,0.4); }
  .pc-channels { display: flex; gap: 4px; color: rgba(255,255,255,0.4); }
  .pc-constraint { margin-top: 8px; font-size: 10px; font-weight: 600; letter-spacing: 0.5px; text-transform: uppercase; color: #f59e0b; background: rgba(245,158,11,0.1); padding: 2px 6px; border-radius: 3px; }
  .pc-genres { display: flex; gap: 4px; flex-wrap: wrap; margin-top: 8px; }
</style>
