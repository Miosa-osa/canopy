<script lang="ts">
  import { Bot } from 'lucide-svelte';
  interface Props {
    agent: { id: string; name: string; role: string; adapter: string; status: string; skills: string[]; model?: string; };
    onrun?: () => void;
  }
  let { agent, onrun }: Props = $props();
  let statusColor = $derived(agent.status === 'working' ? '#3b82f6' : agent.status === 'error' ? '#ef4444' : '#6b7280');
  let statusLabel = $derived(agent.status === 'working' ? 'WORKING' : agent.status === 'error' ? 'ERROR' : 'IDLE');
</script>
<div class="ac">
  <div class="ac-header">
    <div class="ac-icon"><Bot size={16} /></div>
    <div class="ac-info">
      <span class="ac-name">{agent.name}</span>
      <span class="ac-role">{agent.role}</span>
    </div>
    <div class="ac-status" style="--sc: {statusColor}">
      <span class="ac-dot" class:pulse={agent.status === 'working'}></span>
      <span>{statusLabel}</span>
    </div>
  </div>
  <div class="ac-meta">
    <span class="ac-tag">{agent.adapter}</span>
    {#if agent.model}<span class="ac-tag">{agent.model}</span>{/if}
    <span class="ac-tag">{agent.skills.length} skills</span>
  </div>
  {#if onrun}
    <button class="ac-run" onclick={onrun} type="button">Run</button>
  {/if}
</div>
<style>
  .ac { padding: 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.08); }
  .ac-header { display: flex; align-items: center; gap: 8px; }
  .ac-icon { color: rgba(255,255,255,0.4); }
  .ac-info { flex: 1; min-width: 0; }
  .ac-name { display: block; font-weight: 500; font-size: 13px; color: var(--text-primary, #e2e8f0); }
  .ac-role { display: block; font-size: 11px; color: rgba(255,255,255,0.4); }
  .ac-status { display: flex; align-items: center; gap: 4px; font-size: 10px; font-weight: 600; letter-spacing: 0.5px; color: var(--sc); }
  .ac-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--sc); }
  .ac-dot.pulse { animation: ac-pulse 1.5s ease-in-out infinite; }
  @keyframes ac-pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
  .ac-meta { display: flex; gap: 6px; margin-top: 8px; flex-wrap: wrap; }
  .ac-tag { font-size: 10px; padding: 2px 6px; border-radius: 3px; background: rgba(255,255,255,0.06); color: rgba(255,255,255,0.6); }
  .ac-run { margin-top: 8px; padding: 4px 12px; border-radius: 4px; background: #3b82f6; color: white; border: none; font-size: 12px; font-weight: 500; cursor: pointer; }
  .ac-run:hover { background: #2563eb; }
</style>
